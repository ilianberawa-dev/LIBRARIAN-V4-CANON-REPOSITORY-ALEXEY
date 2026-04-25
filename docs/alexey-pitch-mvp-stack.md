# MVP стек парсера-скрейпера недвижимости Бали

**Для:** Алексей (автор канона `architecture.md`)
**От:** Илья (PT Royal Palace Address, KBLI 68111, брокер 20+ лет)
**Дата:** 2026-04-19
**Цель документа:** согласовать архитектуру Этапа 2 канона (скиллы парсинга/нормализации) до написания кода. Просьба: зарезать всё лишнее по вашему усмотрению.

---

## 1. TL;DR

Парсер-скрейпер объявлений недвижимости Бали с 2 сайтов (Rumah123 + OLX) → сырые карточки в `raw_listings` → LLM-нормализация в `properties` → z-score аномалий → advisory-отчёт в человеческом виде «мы считаем, что…».

- **Scope MVP:** 2 сценария покупателя (`foreign_investor_str_via_pma` + `land_for_development` — профильный для PT Royal Palace Address). 4 типа объектов: land / rumah-flip / villa (comps) / apartment (P2-target, STR-сегмент Sanur/Seminyak/Jimbaran). Все получают condition class C1-C5.
- **Бюджет:** ≤$5/мес LLM (Gemini 2.0 Flash primary + Claude Haiku fallback через LiteLLM) поверх уже оплаченной Aeza + Supabase self-hosted.
- **Output:** не Zillow-точность, а грубая сетка стоимости + красные флаги + рекомендация (`pursue / negotiate to $X / watch / skip`).
- **Таймлайн:** 2 недели (Этап 2 канона).
- **Новых таблиц не создаём** — всё в канон-4 (raw_listings / properties / market_snapshots / sources).

---

## 2. Архитектура

8 скиллов поверх существующих 3 сервисов (Supabase + LightRAG + OpenClaw, канон не меняем):

| Скилл | Входы | Выходы | Приоритет MVP |
|---|---|---|---|
| `parse_land` | URL-шаблоны Rumah123 tanah | строки в `raw_listings` | P1 |
| `parse_rumah_flip` | Rumah123 house фильтр ≤Rp 3bn в core-районах | `raw_listings` | P1 |
| `parse_villa` | Rumah123/FazWaz villa (comps + direct target) | `raw_listings` | P2 |
| `parse_apartment` | Rumah123 apartemen (STR-сегмент + сдача) | `raw_listings` | P2 |
| `normalize_listing` | `raw_listings.id` | `properties` (LLM + Pydantic) | P1 блокер |
| `store_to_supabase` | normalized `properties` | upsert + price_history | P1 |
| `compute_z_score` | `properties` сегментированные | `market_snapshots` + поля аномалий | P2 |
| `generate_advisory_narrative` | `properties` + z-score | текст для брокера (S1+S4+S6+S7) | P2 |

**Пайплайн:** scrape (curl_cffi impersonate chrome120) → raw_listings → normalize (regex + Gemini Flash + Pydantic retry → Claude fallback) → properties → z-score MAD → narrative (LLM slot-filling по template).

---

## 3. Изменения в модели данных

Канон-4 таблицы **не трогаем**. Только `ALTER TABLE` + seed в `sources`.

### 3.1. `properties` — новые колонки (миграция 0003)

| Колонка | Тип | Назначение |
|---|---|---|
| `tenure_type` | TEXT CHECK (freehold/leasehold/hak_pakai/hgb/unknown) | Ветвь модели оценки |
| `lease_years_remaining` | INTEGER 0-99 | Для leasehold decay factor |
| `condition_class` | TEXT CHECK (C1..C5/unknown) | 5 классов от ruins до luxury |
| `zoning` | TEXT CHECK (pink/yellow/green/mixed/unknown) | Из area_defaults lookup |
| `specific_area` | TEXT | Canggu/Berawa/Pererenan/... |
| `social_bucket` | TEXT | expat_enclave/mixed/local_dominant |
| `red_flags` | JSONB `[]` | Массив маркеров |
| `far_default`, `kdb_default`, `max_buildable_m2` | NUMERIC/INTEGER | Для land_for_development сценария |
| `narrative_s1_verdict`, `narrative_s4_z_score`, `narrative_s7_recommendation`, `narrative_full_text` | TEXT/NUMERIC | Денормализованный output для быстрого retrieve |
| `normalization_status` | TEXT DEFAULT 'raw' | raw/partial/complete/failed |

Индексы: `(tenure_type, specific_area)`, `(lease_years_remaining) WHERE tenure='leasehold'`, `(narrative_s7_recommendation)`.

### 3.2. `market_snapshots` — новые колонки

| Колонка | Назначение |
|---|---|
| `market_health_gap_pct` | Asking-vs-sold gap, вводится вручную брокером; **fail-safe: если NULL или >90 дней — z-score помечается uncalibrated** |
| `market_health_gap_entered_at` | Timestamp ручного ввода |
| `median_price_per_m2_freehold_idr` | Tenure-stratified медиана |
| `median_price_per_m2_leasehold_30yr_equiv_idr` | Leasehold приведённая к freehold |
| `median_str_yield_pct`, `median_ltr_yield_pct` | Для inefficiency-сигнала |
| `median_days_on_market`, `sample_size` | Для исключения dead listings (>365 дней) |

### 3.3. `sources` — seed-запись `_lookup_area_defaults` (новых полей нет)

JSONB-справочник per-area defaults (zoning/FAR/KDB/subak_risk/social_bucket) для 12 приоритетных районов. Читается через helper `get_area_default(area, field)`. Редактируется через Supabase UI.

> **Q8 Алексею:** допустимо ли использовать `sources` для конфиг-справочников (запись типа `lookup`, имя с префиксом `_lookup_*`)? Альтернатива — YAML-файл на диске вне БД.

---

## 4. Методология оценки

### Слои L1–L7 (научная база: thin-market appraisal, IVSC IVS 104/410, robust z-score Huber 1981)

- **L1** — comps по земле (price_per_m2 freehold-equivalent, сегмент = area × tenure)
- **L2** — comps по конфигурации (bedrooms/size/condition class)
- **L3** — negative externalities (шум, субак, сельхоз-зона для foreign resale)
- **L4** — infrastructure score (MVP: не считаем, Phase 2 через POI density)
- **L5** — social profile (compute both: нейтральный `social_bucket` + scenario-dependent `expat_exit_penalty`)
- **L6** — condition class C1–C5 (C1=ruins/documents-only, C2=distressed, C3=standard, C4=modern, C5=luxury/branded). **Правило абсорбции:** C4/C5 имеют renovation premium уже в asking price, flip-сценарий отключается. Для C3 с ценой ≥ area median — тоже отключаем.
- **L7** — tenure × zone compound (freehold pink > leasehold pink > freehold yellow > ...)

### Output для MVP — только 4 секции narrative:

- **S1** — one-line verdict («мы считаем что…», ≤25 слов)
- **S4** — inefficiency signal (z-score MAD робастный, calibrated flag)
- **S6** — red flags list (high-severity always, medium/low collapsed)
- **S7** — recommendation enum (`pursue_at_asking / pursue_with_negotiation / watch_for_price_drop / skip`) + walk-away-price

**S2/S3/S5 — Phase 2** (полный layer-by-layer reasoning, liquidity, narrative for alternative scenarios).

---

## 5. Сценарии покупателя (IVSC IVS 104)

MVP-2 + Phase 2-3:

| Scenario | Статус MVP | Формула оценки |
|---|---|---|
| `foreign_investor_str_via_pma` | **default** | L7 compound active, rental yield STR |
| `land_for_development` | **2nd default** (профиль Ильи) | Residual Land Value: max_land = (exit_value × zone_factor) − (construction + soft_costs + permits + holding + PMA + profit_margin 20-30% + selling 5-7%) |
| `flip_to_villa` | Phase 2 | `(comparable_villa_price × zone_factor) − (entry + rebuild + permits + PMA + holding 18mo + selling)` |
| `foreign_investor_ltr_via_pma` | Phase 2 | L7 zone мягче, yield LTR ×3-5 ниже STR |
| `local_primary_residence` | Phase 2 | zone_factor = 1.0, rental irrelevant |
| `lifestyle_buyer` | Phase 3 | L4 infra weight high |

**Rebuild cost MVP placeholder:** $1000/m² turnkey (включая soft + 15% contingency). **Требует калибровки Ильёй** по проекту Berawa (см. Q10).

---

## 6. Red flags vocabulary (категории)

Полный индо-словарь с confidence score — **open question Q2** (нужен вклад Алексея/Ильи). Категории:

- **flip_signals:** BU / butuh uang / dijual cepat / harga miring / bangunan lama / perlu renov / butuh renovasi total / owner pindah
- **tenure_risks:** girik / petok D / nominee / atas nama orang lokal / sertifikat dalam proses / sertifikat belum pecah
- **permit_risks:** no PBG / no SLF / permit pending
- **price_risks:** harga nego / call for price / harga on request
- **direct_owner:** dijual langsung pemilik / tanpa perantara / no broker
- **subak_zone:** sawah subak / zona hijau / lahan pertanian
- **foreign_restricted:** zona hijau + foreign investor = нельзя

---

## 7. Stack & библиотеки

- **Python 3.11+**, venv в `/opt/realty-portal/scrapers/.venv/` (уже установлен)
- **Scrape:** `curl_cffi` (impersonate chrome120 — обходит Cloudflare IUAM Rumah123) + BeautifulSoup4 + lxml
- **LLM:** LiteLLM → Gemini 2.0 Flash (primary, ~$0.075/1M tokens) → Claude Haiku 4.5 (fallback при 2× JSON-fail)
- **Validation:** Pydantic v2 `ListingExtraction` схема с retry
- **DB:** `psycopg` v3 к Supabase через supavisor pooler
- **Rate limits:** 4-6s между запросами, User-Agent rotation, HTML cache 48h
- **Не используем в MVP:** PostGIS, RTRW shapefile, vision-LLM, own CNN, Playwright (см. §12 про OLX)

---

## 8. Критическая находка — OLX Akamai Bot Manager

При probe 2026-04-19 выявлено: **OLX.co.id за Akamai Bot Manager (не Cloudflare)**. Возвращает 200 OK + 2.3 KB interstitial page с `bm-verify` токеном, требующим JS-execution + proof-of-work.

`curl_cffi` обходит Cloudflare (работает на Rumah123), но **не обходит Akamai**. Для OLX нужен Playwright/headless Chrome.

**Варианты:**

- **A.** Добавить 4-й сервис `realty_scraper` с Playwright (Docker, ~200 MB image, ~300 MB RAM) → **отход от канона «3 сервиса»**
- **B.** MVP-only Rumah123 (land через `/jual/bali/tanah/`, flip через `/jual/bali/rumah/` с фильтром цены post-scrape), OLX откладываем в Phase 2
- **C.** Коммерческий bypass (FlareSolverr/Bright Data) — деньги, нарушает минималистичный бюджет

**Предлагаемый MVP-default: B** (Rumah123-only, ~26 000 листингов tanah+rumah — достаточно для грубой сетки). OLX как Phase 2 через вариант A при вашем одобрении.

> **Q11 Алексею:** выбор A/B/C.

---

## 9. Open Questions для Алексея

| # | Вопрос | Предложенное по умолчанию |
|---|---|---|
| Q2 | Полный red_flags vocabulary (30-50 индо-маркеров с confidence) | Brokerage-консалтинг или LLM-генерация |
| Q3 | Leasehold normalization MVP: linear decay `years/30` vs NPV | Linear decay для MVP; NPV в Phase 2 |
| Q4 | OLX-детальные селекторы + days_on_market извлечение | Откладываем до Q11 (OLX вообще) |
| Q5 | Regex patterns цен/площадей/WhatsApp/price_range | Claude-помощь в реализации |
| Q6 | Apartments — глубина интеграции в MVP: полная (отдельная L9-подветка с management_company / service_charge / amenities) или minimal (общая C1-C5 + дефолтный набор полей villa) | Minimal в MVP, deep-dive apartments-specific логика — Phase 2 |
| Q7 | Geocoding specific_area без RTRW | LLM + gazetteer of 12 priority areas |
| Q8 | `sources` как config-lookup (мисюз?) | Да, префикс `_lookup_*` |
| Q9 | `market_snapshots` расширение `market_health_gap` + tenure medians | Да |
| Q10 | Berawa project (170m²/218m²/$245K/Japandi) как regression anchor — Ильин proprietary case, можно сохранять в memory скилла? | Только Ильино решение |
| Q11 | OLX — варианты A/B/C выше | B (Rumah123-only MVP) |

---

## 10. Timeline (2 недели, при условии sync-ответов Ильи)

| День | Задача |
|---|---|
| 1-2 | Migration 0003 applied + sources seed `_lookup_area_defaults` + Илья верифицирует 12 areas |
| 3-4 | `parse_land` (Rumah123 tanah) на 50 листингов → raw_listings |
| 5 | `normalize_listing` (regex + Gemini + Pydantic) тестируется на 50 raw |
| 6-7 | `store_to_supabase` + `compute_z_score` + Илья вводит начальный market_health_gap по core-areas |
| 8-9 | `generate_advisory_narrative` (template + LLM fill для S1+S4+S6+S7) |
| 10 | E2E-прогон 200 листингов + Илья review 20 random samples |
| 11-12 | `parse_rumah_flip` + `parse_villa` + `parse_apartment` (minimal), 2-й E2E ~500 combined |
| 13-14 | Devil's advocate calibration — Илья находит 10 явно-неправильных, regression fixes |

---

## 11. Бюджет

| Статья | $ / мес |
|---|---|
| VPS Aeza Вена (уже оплачена) | €10 → ~$11 |
| Gemini 2.0 Flash (200 листингов/день, ~$0.0001/листинг normalize) | $1-2 |
| Claude Haiku fallback (~5% fallback rate) | $0.5 |
| Narrative generation (200 листингов × 4 секции) | $1-2 |
| **Incremental сверх уже оплаченного** | **$2-4.5** |

---

## 12. Risks & Mitigations

| Риск | Mitigation |
|---|---|
| Site HTML structure меняется | Модульные scrapers (один файл per site), fix <30 мин, мониторинг <30% extraction success → alert |
| Rate-limit / IP-ban (Cloudflare) | UA rotation, 4-6s delay, daily cron not hourly, graceful stop при 403. **Реально проверено 2026-04-19** — заблокировали Aeza IP на 20 мин после ~10 запросов |
| LLM invalid JSON | Pydantic retry 2× → Claude fallback → partial+log; **никогда не дроп записи** |
| Gemini Indonesia-block | LiteLLM auto-fallback на Claude |
| Supabase write fail | Local SQLite cache + retry next cron |
| Market_health_gap stale | z-score flagged uncalibrated в narrative |
| Akamai OLX (см. §8) | MVP без OLX (вариант B) |
| Алексей режет canon-нарушения | Все canon-extensions помечены как Q8-Q11, откат через filesystem-only подход |

---

## 13. Что уже работает (Этап 0 + 1.1-1.8 канона закрыты)

- 17 Docker-контейнеров с префиксом `realty_*` на Aeza Вена, все healthy
- Supabase self-hosted с 4 таблицами канона + seed 3 sources Бали
- LightRAG + LiteLLM + Ollama (embedding only)
- OpenClaw self-hosted с `anthropic/claude-haiku-4-5-20251001`
- MCP: supabase-mcp@1.5.0 + lightrag-mcp@1.0.11, E2E подтверждены
- **Прототип парсера Rumah123:** `scrapers/rumah123/run.py` собирает 20 карточек/страница с 100% fill rate по 7 полям (url, title, price_text, location, bedrooms, bathrooms, land_area, building_area). Миграция 0002 (UNIQUE source_url для дедупа) applied.
- doctor.sh: 19/19 passed

---

## Решение для Алексея

**Главное:** одобряете ли вы пайплайн в текущей формулировке (минус всё, что в Q8-Q11)?
**Второе:** конкретные ответы по Q8-Q11 для разблокировки MVP.
**Третье:** общий режим — есть ли ваши рекомендации отрезать ещё что-то (например, сценарий `land_for_development` как «слишком сложно для MVP» — тогда остаётся только foreign_investor_str_via_pma).

После одобрения — начинаем Week 1.
