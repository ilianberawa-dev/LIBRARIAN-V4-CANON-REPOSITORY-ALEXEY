# Tool Architecture v1.1 (Final) — Bali Realty Parser / Normalizer / Validator / Evaluator

**Статус:** v1.1 Final. Изменения от v1.0: добавлен `listing_subtype` field в Normalizer output (9 значений включая commercial). Каскадная логика в Evaluator routing (16 скиллов вместо 14). См. v1.0→v1.1 diff в конце документа.
**Автор контракта:** Илья; ожидается approval Алексея по каноничности.

> **Цель:** превратить объявления с Rumah123 (и других сайтов в Phase 2) в structured advisory отчёты через 4 независимых инструмента с контрактом через статусные поля.

---

## Pipeline (4 инструмента, контракт через статусы)

```
sources  ──►  SCRAPER     ──►  raw_listings
                                    │ .status='pending'
                                    ▼
                               NORMALIZER ──►  properties
                                                   │ .normalization_status
                                                   ▼
                                              VALIDATOR   ──►  properties
                                                                 │ .validation_status
                                                                 ▼
                                                            EVALUATOR  ──►  properties
                                                                             .evaluation_status
                                                                             .narrative_*
```

Каждый инструмент cron-независим, идемпотентен. Отставание одного не блокирует остальных.

---

## 1. SCRAPER

| | |
|---|---|
| **Вход** | `sources` WHERE `is_active=true AND type != 'lookup'` |
| **Делает** | загружает HTML с маркетплейса (Rumah123), парсит карточки списка + опционально детальные страницы в сырые строки |
| **Выход** | `raw_listings (source_name, source_url, raw_text, raw_html, status='pending')`; `UPDATE sources SET last_parsed_at, total_parsed`; UPSERT по `source_url` |
| **НЕ делает** | типизация, извлечение значений, проверка разумности, оценка |
| **Критерий готов** | ≥80% карточек со страницы → `raw_listings` при warm-session; graceful stop при CF challenge |
| **Failure mode** | 403/CF → stop loop, `sources.last_error` записывается, pipeline продолжает; уже записанные rows не повреждаются |

---

## 2. NORMALIZER

| | |
|---|---|
| **Вход** | `raw_listings` WHERE `status='pending'` |
| **Делает** | regex-pass (цена/размер/контакт/tenure) → LLM-pass для свободного текста (red_flags, condition_class, specific_area, **listing_subtype**) → запись в `properties` с FK к `raw_listings` |
| **Выход** | `properties.normalization_status ∈ {complete, partial, failed}`; **`properties.listing_subtype ∈ {land, villa, rumah, apartment, commercial_office, commercial_warehouse, commercial_industrial, commercial_shop, ambiguous}`**; `raw_listings.status='processed'` |
| **НЕ делает** | проверка разумности правил (Validator), сравнение с рынком (Evaluator), исправление значений |
| **Критерий готов** | ≥92% → complete, ≤8% → partial/failed на выборке 50 свежих raw; все failed имеют `normalization_errors[]` |
| **Failure mode** | LLM invalid JSON ×2 retry → Claude Haiku fallback → `partial` с logged errors; никогда не дроп, raw_listings сохраняется |

### 2.1 listing_subtype extraction (keyword rules в Normalizer)

| Keywords (ID/EN) | → subtype |
|---|---|
| `villa`, `private pool`, `tropical design`, `Balinese architecture` | `villa` |
| `rumah`, `keluarga`, `kampung`, `family house` | `rumah` |
| `apartemen`, `condo`, `unit`, `studio` | `apartment` |
| `tanah`, `kavling`, `lot`, `land` | `land` |
| `kantor`, `office space`, `coworking` | `commercial_office` |
| `gudang`, `warehouse`, `storage`, `depo` | `commercial_warehouse` |
| `pabrik`, `factory`, `workshop`, `produksi` | `commercial_industrial` |
| `ruko`, `shop`, `toko`, `retail space` | `commercial_shop` |
| смешанные villa+rumah hints OR отсутствующие | `ambiguous` |

Evaluator orchestrator (EVL-ORC-016) использует `listing_subtype` для routing к соответствующему `find_comps_*` скиллу.

---

## 3. VALIDATOR

| | |
|---|---|
| **Вход** | `properties` WHERE `normalization_status IN (complete, partial) AND validation_status IS NULL`<br>+ `sources._lookup_area_defaults` (read-only)<br>+ `sources._lookup_red_flags_vocabulary` (read-only) |
| **Делает** | детерминированные правила разумности: price-coherence, size-range, tenure-zone consistency, tenure-listing-type match, red_flags severity aggregation. Флагит в `red_flags`, НЕ исправляет |
| **Выход** | `properties.validation_status ∈ {ok, warn, fail}`; дополнения в `red_flags` JSONB |
| **НЕ делает** | LLM-вызовы, сравнение с рынком, изменение данных полей |
| **Критерий готов** | ≥70% ok, ≤30% warn, ≤5% fail на выборке 50; каждый fail имеет rule_id в red_flags |
| **Failure mode** | внутренняя ошибка правила → row помечен `fail` с `validation_errors[]`, продолжает следующие правила |

---

## 4. EVALUATOR

| | |
|---|---|
| **Вход** | `properties` WHERE `validation_status IN (ok, warn) AND evaluation_status IS NULL`<br>+ `market_snapshots` (read-only)<br>+ `sources._lookup_area_defaults` (read-only)<br>+ `sources._lookup_fx_rates` (read-only)<br>+ `sources._lookup_red_flags_vocabulary` (read-only)<br>+ `sources._lookup_evaluation_constants` (read-only) |
| **Делает** | оркестрирует **16 скиллов** (15 workers + 1 orchestrator) — см. `sales-comparison-logic.md v1.1 §5`. Routing по `listing_subtype`: land → find_comps_land, villa → find_comps_villa, rumah → find_comps_rumah, apartment → find_comps_apartment, commercial_* → find_comps_commercial, ambiguous → dual-pool villa+rumah. Применяет scenario-модель, генерирует narrative S1+S4+S6+S7 (+условная S_ZONE_CONFIRMATION, S_SUBTYPE_CONFIRMATION, S_COMMERCIAL_DISCLAIMER). |
| **Выход** | `properties.evaluation_status ∈ {ok, uncalibrated, failed}`, `narrative_s1_verdict`, `narrative_s4_z_score`, `narrative_s4_z_calibrated`, `narrative_s7_recommendation`, `narrative_s7_walk_away_price_idr`, `narrative_full_text` |
| **НЕ делает** | парсинг, нормализация, валидация, запись сырых данных |
| **Критерий готов** | ≥80% ok с calibrated z-score + narrative; остальные uncalibrated (sample < 10 в сегменте) |
| **Failure mode** | segment-sample < 10 → `uncalibrated`; market_health_gap stale (>90 дней) → z_calibrated=false; commercial_industrial → forced uncalibrated (ADR-018) |

**Детализация скиллов Evaluator:** `sales-comparison-logic.md v1.1 §5`, `skills/EVL-*/SKILL.md` files.

---

## Статусы — канон контракта

| Поле (в `properties`) | Значения | Владелец (пишет) | Читатель следующий |
|---|---|---|---|
| `normalization_status` | `complete / partial / failed` | Normalizer | Validator (IN complete, partial) |
| `validation_status` | `ok / warn / fail / NULL` | Validator | Evaluator (IN ok, warn) |
| `evaluation_status` | `ok / uncalibrated / failed / NULL` | Evaluator | Search / UI |

Каждый инструмент пишет **только свой статус**. Читает статус **только предыдущего**. `NULL` = ещё не обработано.

---

## Индексы (для cron-выборок)

- `(normalization_status)` WHERE complete/partial AND `validation_status IS NULL`
- `(validation_status)` WHERE ok/warn AND `evaluation_status IS NULL`
- существующие на tenure/area/recommendation сохраняются

---

## Re-runnability

| Инструмент | Re-run поведение | Механизм |
|---|---|---|
| Scraper | **UPSERT** при повторе same source_url | обновляет цену, append в `price_history` JSONB, сохраняет `first_seen_at`, обновляет `last_seen_at` |
| Normalizer | да (force flag: сбрасывает `normalization_status=NULL`) | используется при смене LLM или prompt |
| Validator | да всегда | пересчёт правил при смене вокабуляра |
| Evaluator | да всегда | пересчёт z-score при обновлении market_snapshots |

**Обоснование Scraper UPSERT:** price drops — ключевой сигнал на Бали; без обновления Evaluator их не видит.

---

## Trigger model (self-healing через invalidation)

| Инструмент | Automatic trigger | Manual trigger |
|---|---|---|
| **Scraper** | daily cron 04:00 WITA (Bali time) | `--force-scrape` |
| **Normalizer** | новые `raw_listings` (status='pending') | `--force-normalize` (смена LLM/prompt) |
| **Validator** | новые properties ИЛИ обновление `updated_at` у `_lookup_red_flags_vocabulary`/`_lookup_area_defaults` → invalidate `validation_status=NULL` для affected records → Validator подхватит в следующем cron | `--force-validate` |
| **Evaluator** | новые validated properties ИЛИ обновление `market_snapshots` для соответствующего segment → invalidate `evaluation_status=NULL` | `--force-evaluate` |

Ключевой self-healing механизм: при обновлении lookup через Supabase UI — пересчёт автоматический.

---

## Decisions from Ilya

**1. Validator severity thresholds:**

- `fail` — запись нельзя передавать в Evaluator:
  - price=0 или NULL
  - size=0 или NULL
  - `tenure_type='unknown' AND listing_type='land'`
  - `zoning='green' AND target_scenario='foreign_investor_str_via_pma'`
- `warn` — Evaluator обработает с asterisk:
  - `tenure_type='leasehold' AND lease_years_remaining < 25`
  - price вне 10th-90th percentile area × tenure × listing_type
  - size извлечён из `bata` без подтверждения коэффициента
- `ok` — всё прошло

Конкретные rule_id — в отдельном `docs/validator-rules.md` после этой архитектуры.

**2. Evaluator minimum sample size: 10.**

- sample ≥ 30 → `z_calibrated = high_confidence`
- 10 ≤ sample < 30 → `z_calibrated = low_confidence`
- sample < 10 → `evaluation_status = uncalibrated`, narrative flag "area sample too thin"

**3. Scraper cron: 1 раз в сутки, 04:00 WITA (Bali time).**
CF-friendly, off-peak. Ручной повторный запуск через `--force-scrape`.

**4. Re-run triggers:** см. секцию Trigger model выше. Self-healing через invalidation статусов при обновлении lookups/market_snapshots.

---

## Out of scope этого документа

Layer-модель L1-L7, сценарии покупателя, IVSC-обоснование, regex patterns, CSS-селекторы, Pydantic-схемы, LLM prompts, конкретные rule_id Validator — внутренности конкретных инструментов. Описываются отдельно, после approval этой архитектуры.
