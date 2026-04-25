# Sales Comparison Logic v1.1 (Final) — Bali Realty Evaluator

**Статус:** v1.1 Final. Изменения от v1.0: split `find_comps_configuration` → `find_comps_villa` + `find_comps_rumah` (ADR-017). Добавлен 9-й значение listing_subtype + `find_comps_commercial` (ADR-017, ADR-018). Итого 16 скиллов (было 14). См. v1.0→v1.1 diff в конце.
**Область:** Phase A — логика сравнительного метода оценки (primary). Income и Cost — Phase 2.
**Позиция в pipeline:** Evaluator (4-й инструмент в `tool-architecture.md v1.1`).

---

## 0. Terminology

| Термин | Определение |
|---|---|
| **Layer (L1-L8)** | analytical concept — **что** оцениваем |
| **Skill** | execution unit — **кто** оценивает |
| **Block** | group of skills (пример: «comp retrieval block» = `find_comps_land` + `find_comps_villa` + `find_comps_rumah` + `find_comps_apartment` + `find_comps_commercial`) |

Один layer может реализовываться несколькими скиллами. Пример: **L2 (configuration comps)** = 4 скилла по `listing_subtype`. Оркестратор выбирает нужный по значению поля.

---

## 1. Primary method и место в IVSC triad

| Method | Роль | Фаза |
|---|---|---|
| **Sales Comparison** | primary (строим сейчас); даёт price_interval и z-score | A / MVP |
| Income approach | super-verification (rental yield, cap rate) | Phase 2 |
| Cost approach | super-verification (rebuild cost / Residual Land Value) | Phase 2 |

**Convergence signal:** на здоровом рынке три метода должны сходиться в пределах ~10-20%. Расхождение >20% = рыночная неэффективность ИЛИ сломанный Sales Comparison.

**Indonesian standards alignment:** наша архитектура соответствует **SPI Edition VI (2015)** — **Pendekatan Pasar** (Market Approach) primary для residential. Для commercial SPI требует weighted application всех трёх методов (Phase 2). См. `indonesian-valuation-standards-reference.md`.

Цель Phase A: для каждой записи `properties` с `validation_status ∈ {ok, warn}` — вернуть `price_interval [low, mid, high]`, z-score vs сегмент рынка, **diagnostic narrative**.

---

## 2. Zoning as soft-layer

**Zoning не блокирует сделку, а задаёт вопрос пользователю.** Карты Бали могут быть неточны; наше предположение о зоне — это assumption, не факт. Вместо блокировки: сегментируем comp-пул + показываем assumption + задаём вопрос с price-консеквенциями (ADR-003).

### 2.1 Уровни confidence

| Confidence | Источник | Применение |
|---|---|---|
| `high` | RTRW shapefile + координаты (Phase 2) | multiplier без вопроса |
| `medium` | `_lookup_area_defaults` consistent + listing не противоречит | multiplier + narrative декларирует assumption |
| `low` | area unknown / mixed / listing hints противоречат | narrative задаёт user question с альтернативами |

### 2.2 Zone sensitivity matrix (2 MVP scenarios)

| Scenario | Zone | min | mid | max | Rationale |
|---|---|---|---|---|---|
| `foreign_investor_str_via_pma` | pink | 1.00 | 1.00 | 1.00 | STR легально через Pondok Wisata/TDUP |
| `foreign_investor_str_via_pma` | yellow | 0.75 | 0.80 | 0.85 | MSME proxy, operational friction 10-15% |
| `foreign_investor_str_via_pma` | green | 0.50 | 0.55 | 0.60 | STR нелегален; LTR/agri exit, тонкий пул покупателей |
| `land_for_development` | pink | 1.00 | 1.00 | 1.00 | Dev + STR exit fully liquid |
| `land_for_development` | yellow | 0.70 | 0.75 | 0.80 | Residential-only exit, STR-dev блокирован |
| `land_for_development` | green | 0.35 | 0.40 | 0.45 | Development blocked, subak/agri risk |

Остальные scenarios — Phase 2+ (§14).

### 2.3 Zone multiplier policy (applied value within range)

| Condition | Applied value |
|---|---|
| `confidence = high` | mid |
| `confidence = medium` | mid |
| `confidence = low` | min (conservative) |
| listing hints contradict area_defaults | min (conservative) |

Narrative **всегда** цитирует range + применённое значение + источник confidence.

### 2.4 Comp selection сегментация

Comps одного объекта берутся из того же assumed zone. Pink не сравнивается с green. При недостатке (<10) в сегменте — эскалация до "mixed zone" с явным narrative-флагом.

---

## 3. Legal as external contour

**Мы флагим, не оцениваем.** Legal verdict — ответственность пользователя + Индологос бот + PNB Law Firm (Philo Dellano) (ADR-004).

### 3.1 Routing triggers

| Severity | Routing recommendation |
|---|---|
| `high` (girik, petok D, nominee, atas nama orang lokal, pinjam nama, sertifikat dalam proses, sertifikat belum pecah, sertifikat bermasalah, tanah sengketa) | narrative: «документы передать в Индологос бот / PNB Law Firm до любых задатков» |
| `medium` (adat mention, PBG dalam proses, izin tidak lengkap) | narrative: «отметить для юриста при due diligence» |
| `low`/`positive` | не триггерит |

### 3.2 Что narrative делает и НЕ делает

- **Делает:** называет red_flags, указывает external legal address, советует НЕ вносить задаток до legal-clearance
- **НЕ делает:** legal verdict, юридический совет, purchase recommendation на основе legal

---

## 4. Data flow внутри Sales Comparison

```
properties (validation_status ∈ ok/warn)
   │
   ├─►  enrich_area_context             ──► area defaults + market snapshot
   ├─►  classify_condition              ──► condition_class C1-C5 + confidence
   ├─►  classify_assumed_zoning         ──► assumed_zone + confidence
   ├─►  normalize_tenure_to_freehold_eq ──► price_per_m2_freehold_eq
   │
   ├─►  find_comps_land         [if listing_subtype = land]
   ├─►  find_comps_villa        [if listing_subtype = villa]
   ├─►  find_comps_rumah        [if listing_subtype = rumah]
   ├─►  find_comps_apartment    [if listing_subtype = apartment]
   ├─►  find_comps_commercial   [if listing_subtype ∈ commercial_*]
   ├─►  (villa + rumah both)    [if listing_subtype = ambiguous]
   │
   ├─►  compute_price_interval        ──► [low, mid, high]
   ├─►  compute_z_score               ──► z + calibration
   ├─►  assess_liquidity_proxy        ──► days_on_market signal
   │
   ├─►  detect_validity_violations    ──► fail/warn surfacing
   ├─►  route_legal_to_external       ──► Индологос routing flags
   │
   └─►  generate_advisory_narrative   ──► S1 + S4 + S6 + S7 
                                         + S_ZONE_CONFIRMATION (условно)
                                         + S_SUBTYPE_CONFIRMATION (если ambiguous)
                                         + S_COMMERCIAL_DISCLAIMER (если commercial_*)

   (orchestrator: evaluate_sales_comparison)
```

---

## 5. Набор скиллов (16: 15 workers + 1 orchestrator)

| # | Catalog ID | Skill | Calibration type | Applies to |
|---|---|---|---|---|
| 1 | EVL-CTX-001 | `enrich_area_context` | lookup | все |
| 2 | EVL-CLS-002 | `classify_condition` | llm_prompt | все не-land |
| 3 | EVL-CLS-003 | `classify_assumed_zoning` | llm_prompt | все |
| 4 | EVL-NOR-004 | `normalize_tenure_to_freehold_eq` | deterministic_formula | все |
| 5 | EVL-COMP-005 | `find_comps_land` | sql_query | land |
| 6 | EVL-COMP-006 | `find_comps_villa` | sql_query | villa (+ambiguous branch) |
| 7 | EVL-COMP-007 | `find_comps_rumah` | sql_query | rumah (+ambiguous branch) |
| 8 | EVL-COMP-008 | `find_comps_apartment` | sql_query | apartment |
| 9 | EVL-COMP-009 | `find_comps_commercial` | sql_query | commercial_* (param by commercial_subtype) |
| 10 | EVL-STAT-010 | `compute_price_interval` | sql_query | все не-failed |
| 11 | EVL-STAT-011 | `compute_z_score` | sql_query | все не-uncalibrated |
| 12 | EVL-LIQ-012 | `assess_liquidity_proxy` | rule_based | все |
| 13 | EVL-VAL-013 | `detect_validity_violations` | rule_based | все |
| 14 | EVL-LEG-014 | `route_legal_to_external` | rule_based | все |
| 15 | EVL-NAR-015 | `generate_advisory_narrative` | llm_prompt | все |
| 16 | EVL-ORC-016 | `evaluate_sales_comparison` (orchestrator) | orchestrator | meta |

**Calibration type breakdown:** 3 llm_prompt + 7 sql_query + 1 deterministic_formula + 3 rule_based + 1 lookup + 1 orchestrator = 16.

---

## 6. Слои L1-L8

| L | Что вычисляет | Skip conditions | Implements via |
|---|---|---|---|
| **L1** | land comps | land_size_m2 NULL; listing_subtype ≠ land | EVL-COMP-005 |
| **L2** | configuration comps | listing_subtype = land | EVL-COMP-006/007/008/009 (4 skills) |
| **L3** | negative externalities | — | absorbed в L1/L2 сегментации; Phase 2 own skill |
| **L4** | infrastructure score | — | absorbed в L1/L2; Phase 2 own skill |
| **L5** | social profile | scenario ∈ local/lifestyle → penalty=0 | EVL-CLS-003 + normalize step |
| **L6** | condition class | zero text + zero photo → unknown | EVL-CLS-002 |
| **L7** | tenure × zone compound | tenure=unknown AND listing=land → fail earlier | EVL-NOR-004 |
| **L8** | liquidity proxy | first_seen_at NULL → skip | EVL-LIQ-012 |

---

## 7. Zone Sensitivity Matrix

См. §2.2 (matrix) + §2.3 (applied-value policy).

---

## 8. Tenure × Zone compound normalization

Формула **strictly multiplicative** (ADR-011).

```
price_per_m2_freehold_pink_eq  =
    asking_price_per_m2
    ÷ tenure_decay
    ÷ zone_multiplier
    × (1 − pma_compliance_overhead_pct_applied)  # foreign scenarios only
    × (1 − expat_exit_penalty_pct)               # foreign scenarios only
```

> **ВАЖНО: `pma_compliance_overhead_pct` — это НЕ налоги.** Это amortized compliance costs существования PT PMA как юр-лица (notary, accountant, LKPM, BPJS, virtual office). Налоги (BPHTB transfer tax, PPh income tax, PPN VAT, PBB property tax) — **в compound нормализации НЕ входят**, они считаются отдельным transaction-economics блоком (см. Q-OPEN-14, Phase 2).

### Параметры

| Параметр | Значение MVP | Источник |
|---|---|---|
| `tenure_decay` | freehold=1.0; leasehold=min(1.0, years/30); hak_pakai/hgb as leasehold | EVL-NOR-004 |
| `zone_multiplier` | §2.2 + §2.3 policy | `_lookup_area_defaults` + listing hints |
| `pma_compliance_overhead_pct_applied` | **tenure-dependent** (формула ниже) | `_lookup_evaluation_constants` |
| `expat_exit_penalty_pct` | area × scenario (Q-OPEN-13) | L5 skill |

### Leasehold-aware amortization для pma_compliance

PMA-compliance costs (annual) amortized over effective holding period. Для leasehold effective период ограничен сроком аренды:

```
pma_compliance_overhead_pct_applied =
    pma_compliance_overhead_pct_default × 
    (effective_amortization_years / default_target_holding_years)

where:
    effective_amortization_years:
        freehold          → default_target_holding_years (по умолчанию 10)
        leasehold/hak_pakai/hgb → min(default_target_holding_years, lease_years_remaining)
```

**Defaults из `_lookup_evaluation_constants`:**

- `pma_compliance_overhead_pct_default = 0.05` (ADR-016)
- `default_target_holding_years = 10`

**Intuition:** если leasehold с 5 годами остатка — держать PMA 10 лет нельзя (lease кончится). Amortization укорачивается → compliance pct меньше. При leasehold ≥10 лет — base case 5% применяется как обычно.

### Numerical examples (ADR-011)

**Example 1 — leasehold 20 лет, Berawa yellow, foreign_str** (base case, amortization=10):

- `tenure_decay` = 20/30 = **0.67**
- `zone_multiplier` = **0.80** (yellow mid, confidence medium)
- `effective_amortization_years` = min(10, 20) = **10** → `pma_compliance_applied` = 0.05 × (10/10) = **0.05**
- `expat_exit_penalty_pct` = **0.07** (Berawa assumption, Q-OPEN-13)

```
freehold_pink_eq = $1000 / 0.67 / 0.80 × (1-0.05) × (1-0.07)
                 = $1000 / 0.536 × 0.95 × 0.93
                 = $1,649/m²
```

**Example 2 — leasehold 5 лет, Berawa yellow, foreign_str** (short lease, amortization scaled):

- `tenure_decay` = 5/30 = **0.167**
- `zone_multiplier` = **0.80**
- `effective_amortization_years` = min(10, 5) = **5** → `pma_compliance_applied` = 0.05 × (5/10) = **0.025**
- `expat_exit_penalty_pct` = **0.07**

```
freehold_pink_eq = $1000 / 0.167 / 0.80 × (1-0.025) × (1-0.07)
                 = $1000 / 0.134 × 0.975 × 0.93
                 = $6,774/m²
```

Огромный freehold-eq значит: **реальная ценность такого короткого leasehold как freehold ≈ $6,774/m²**, но **ликвидность у него почти нулевая** (<25 лет = warn per §11). Narrative выдаёт heavy warning S_ZONE + leasehold-under-25y.

Subject сравнивается с нормализованным значением, не с raw $1000.

---

## 9. Condition C1-C5 matrix

| Class | Visual | Text signs | Valuation | Flip rule |
|---|---|---|---|---|
| **C1** | ruins / missing roof | «tanah + bangunan hancur», «hanya tanah» | price = land only | open |
| **C2** | 1990s fixtures, overgrown | «perlu renovasi», «bangunan lama» | land + 10-30% salvage | open |
| **C3** | clean modest, basic tile | «siap huni», «standard finish» | market-median | **disabled** if asking ≥ area_median |
| **C4** | open-plan, wood accents, pool | «modern design», «fully renovated YEAR» | +10-25% over C3 | **DISABLED** (premium absorbed) |
| **C5** | architect-signed, branded | Ritz-Carlton, Six Senses, Bvlgari, Aman, Soori | narrow comps, 2-4× median | **DISABLED** |

**Absorption rule (ADR-012):** C4/C5 → flip always disabled. C3 AND asking ≥ area_median → flip disabled. C1/C2 → flip open.

---

## 10. Area defaults gazetteer (27 areas)

| Area | Parent | Zone | FAR | KDB | Social | Subak |
|---|---|---|---|---|---|---|
| Canggu | Badung | pink | 0.6 | 0.50 | expat_enclave | low |
| Berawa | Badung | pink | 0.6 | 0.50 | expat_enclave | low |
| Pererenan | Badung | pink | 0.6 | 0.50 | mixed_transitional | medium |
| Umalas | Badung | pink | 0.6 | 0.50 | expat_enclave | low |
| Kerobokan | Badung | yellow | 0.4 | 0.40 | mixed_intl | low |
| Seminyak | Badung | pink | 0.6 | 0.50 | expat_enclave | none |
| Legian | Badung | pink | 0.6 | 0.50 | mixed_intl | none |
| Kuta | Badung | pink | 0.6 | 0.50 | mixed_intl | none |
| Sanur | Denpasar | pink | 0.5 | 0.50 | mixed_intl | low |
| Denpasar | Denpasar | yellow | 0.5 | 0.45 | local_dominant | low |
| Ubud | Gianyar | mixed | 0.5 | 0.45 | mixed_intl | high |
| Penestanan | Gianyar | mixed | 0.5 | 0.45 | mixed_intl | high |
| Mas | Gianyar | mixed | 0.5 | 0.45 | local_dominant | high |
| Uluwatu | Badung | pink | 0.4 | 0.40 | mixed_intl | none |
| Jimbaran | Badung | pink | 0.5 | 0.45 | mixed_intl | low |
| Nusa Dua | Badung | pink | 0.5 | 0.45 | mixed_intl | none |
| Pecatu | Badung | pink | 0.4 | 0.40 | mixed_intl | none |
| Bingin | Badung | pink | 0.4 | 0.40 | mixed_intl | none |
| Padang Padang | Badung | pink | 0.4 | 0.40 | mixed_intl | none |
| Tabanan | Tabanan | green | 0.3 | 0.35 | local_dominant | high |
| Cemagi | Badung | mixed | 0.4 | 0.40 | mixed_transitional | medium |
| Seseh | Badung | mixed | 0.4 | 0.40 | mixed_transitional | medium |
| Tanah Lot | Tabanan | mixed | 0.4 | 0.40 | local_dominant | medium |
| Lovina | Buleleng | yellow | 0.4 | 0.40 | mixed_intl | low |
| Amed | Karangasem | yellow | 0.4 | 0.40 | mixed_intl | low |
| Ubuk | Klungkung | yellow | 0.4 | 0.40 | local_dominant | medium |
| Sidemen | Karangasem | yellow | 0.4 | 0.40 | local_dominant | medium |

Хранится в `sources._lookup_area_defaults` + `_lookup_bali_gazetteer`.

---

## 11. Validity constraints

### Fail → `evaluation_status = failed`

- `price_idr = 0 OR NULL`
- `size_m2 = 0 OR NULL`
- `tenure_type='unknown' AND listing_subtype='land'`
- `tenure_type='leasehold' AND lease_years_remaining IS NULL`
- tenure conflicting markers (SHM + leasehold одновременно)

### Forced uncalibrated (ADR-018)

- `listing_subtype = commercial_industrial` → `evaluation_status = uncalibrated`, regardless of sample_size

### Warn → process с asterisk

- `tenure_type='leasehold' AND lease_years_remaining < 25`
- price вне 10th-90th percentile segment
- size в bata без confirmation (1 bata ≈ 12-14 m², Q-OPEN-12)
- `market_health_gap` stale (>90 дней) → z-score uncalibrated
- segment sample < 10 → z-score low_confidence
- `assumed_zoning.confidence = low` → zone multiplier uncertain
- `zoning = green AND scenario = foreign_investor_str_via_pma` — heavy warning

---

## 12. Narrative output templates

**Tone rules:** «мы считаем / мы оцениваем / по нашим данным»; mandatory hedge. **Banned:** «is worth», «guaranteed», «fair value is», «definitely».

| Section | Когда | Шаблон (суть) | Intermediate results to expose |
|---|---|---|---|
| **S1** verdict | всегда | «Мы считаем [under/fair/over]priced для [scenario] с [high/med/low] confidence» | applied scenario, confidence, direction |
| **S4** inefficiency | всегда | «z = [value] vs [area × tenure × listing_subtype × zone]; sample_size=[n]; calibration=[level]» | z-value, full segment ID, sample_size, calibration |
| **S6** red flags + legal | high-severity есть | нумерованный list markers + severity + routing | each marker + severity + routing |
| **S7** recommendation | всегда | enum + trigger/walk-away price + reasoning trace | enum, trigger price, aggregated signals |
| **S_ZONE_CONFIRMATION** | confidence ∈ {medium, low} | «Мы предположили [zone] (range [min-max], applied [value], source [lookup_key]). Альт-zone interval [range]» | assumed zone, range+value, source, alternatives |
| **S_SUBTYPE_CONFIRMATION** | listing_subtype=ambiguous (ADR-017) | «Не смогли однозначно определить тип (villa/rumah). Проверили оба пула. Применили [X] — interval уже. Если считаете иначе — пересчитаем» | subtype ambiguity, two-pool results, selection basis |
| **S_COMMERCIAL_DISCLAIMER** | listing_subtype ∈ commercial_* | см. 3 варианта ниже (general / office-warehouse-retail / industrial) | SPI reference, primary method per SPI, our approximation level |

### S_COMMERCIAL_DISCLAIMER variants (ADR-018)

**Variant 1 — general commercial** (office / warehouse / shop):
> Наша оценка применяет Market Approach (SPI terminology: Pendekatan Pasar), который для коммерческой недвижимости согласно SPI является secondary. Primary = Income Approach (Phase 2). Для банковской ипотеки / судебных дел / institutional investment требуется KJPP appraisal с weighted application трёх методов.

**Variant 2 — industrial (pabrik)**:
> Для промышленной недвижимости (pabrik) SPI требует specialized industrial appraiser. Каждая фабрика уникальна — equipment (30-60% стоимости), environmental permits, workforce infrastructure. Наш Sales Comparison не применим в принципе. `evaluation_status = uncalibrated`. Рекомендуем KJPP с industrial specialization (например, TÜV SÜD Indonesia).

**Variant 3 — office / warehouse / retail-ruko**:
> Наш Sales Comparison — approximation для pre-purchase screening. Для final investment decision требуется Income Approach (NOI / Cap Rate). Phase 2 подключает cap rates из Colliers / Knight Frank reports.

---

## 12.1 Diagnostic principle

**Narrative — диагностический отчёт, не marketing text** (ADR-008). Это ПЕРВЫЙ инструмент калибровки системы.

**Универсальное правило:** никакой гладкой прозы. Каждое прилагательное подкрепляется числом или идентификатором, трассируемым до конкретного скилла / lookup / слоя.

### Good vs bad examples

| Section | Bad | Good | Диагностирует |
|---|---|---|---|
| **S1** | «Объект дороговат» | «Переоценён на 25% для foreign_investor_str_via_pma, confidence medium» | applied scenario |
| **S4** | «Выше рыночной» | «z=+1.8 vs (pink·freehold·villa·Berawa); sample=23; calibration=high» | segment definition + sample |
| **S6** | «Юр-вопросы есть» | «⚠ leasehold 22y (medium, <25y threshold). ⚠ 'atas nama orang lokal' (high, nominee → Indologos/PNB до задатков)» | vocabulary + severity |
| **S7** | «Подождать» | «watch_for_price_drop. Trigger=$520K (mid − 10% buffer). Основа: z=+1.8 (S4) + leasehold warn (S6) + zone uncertainty medium (S_ZONE)» | signal aggregation |
| **S_ZONE** | «Зона может отличаться» | «Предположили pink (medium, _lookup_area_defaults[Berawa]). Yellow → [$380K-$450K]. Green → [$210K-$260K]» | lookup source |

### Calibration methodology (Phase D forward-looking)

20 реальных Rumah123-листингов end-to-end. Ilya маркирует каждый narrative: `adequate / strange_at_step_X / nonsense_at_step_Y`. Калибровка нацеливается на группу скиллов где breakage. Итерируем пока все группы reasonable.

---

## 13. Synthesis

```
1. enrich_area_context             → context attached
2. classify_condition              → C1-C5 + confidence
3. classify_assumed_zoning         → zone + confidence + source
4. normalize_tenure                → subject в freehold-pink-eq

5. listing_subtype routing:
   land       → find_comps_land         → land_comp_range
   villa      → find_comps_villa        → villa_comp_range
   rumah      → find_comps_rumah        → rumah_comp_range
   apartment  → find_comps_apartment    → apt_comp_range
   commercial_* → find_comps_commercial → commercial_comp_range
   ambiguous  → villa + rumah both      → tighter-MAD selection
     [все comps приведены к freehold-pink-eq через §8 compound]

6. L6 applies condition adjustment
7. L5 expat_exit_penalty subtract (foreign scenarios)
8. compute_price_interval          → [low=p10, mid=p50, high=p90]
9. compute_z_score                 → z + calibration
10. assess_liquidity_proxy         → signal attached
11. detect_validity_violations     → surface fail/warn/uncalibrated
12. route_legal                    → routing if triggered
13. generate_advisory_narrative    → S1+S4+S6+S7 + условные секции
```

Final output: `properties.evaluation_status`, narrative denorm fields + `narrative_full_text`.

---

## 14. Out of scope v1.1

- **Income approach** (rental yield, cap rate STR/LTR, AirDNA/Booking scraping) — Phase 2 (cap rates готовы в `indonesian-valuation-standards-reference.md` §9)
- **Cost approach** (rebuild matrix, Residual Land Value) — Phase 2
- **RTRW shapefile integration** — Phase 2 (MVP = area_defaults assumption)
- **L3 externalities и L4 infrastructure как own skills** (`score_externalities_l3`, `score_infrastructure_l4`) — Phase 2 при POI scraping
- **Scenarios beyond 2 MVP defaults** (`local_primary_residence`, `flip_to_villa`, `foreign_investor_ltr_via_pma`, `lifestyle_buyer`) — Phase 2+
- **Management company / M1-M5 apartment classification** — Phase 2
- **Индологос bot API integration** — отдельный трек
- **Vision detailed prompting** для condition_class — MVP text-hints-only
- **Scientific grounding** refs — в `docs/methodology.md` (отдельно)
- **Технологии реализации** (Phase B)
- **Feasibility / стоимость / сроки** (Phase C)

---

## v1.0 → v1.1 diff

| Изменение | Раздел |
|---|---|
| Split `find_comps_configuration` → `find_comps_villa` + `find_comps_rumah` (ADR-017) | §5 table (16 skills) |
| Added `find_comps_commercial` (5 subtypes consolidated) + `find_comps_apartment` as separate skill (ADR-017) | §5 table |
| Added `listing_subtype` routing logic in synthesis | §4 + §13 |
| Added `S_SUBTYPE_CONFIRMATION` narrative section (ambiguous fallback) | §12 |
| Added `S_COMMERCIAL_DISCLAIMER` narrative section with 3 variants (general/industrial/office-warehouse-retail) | §12 |
| Added industrial forced uncalibrated rule (ADR-018) | §11 |
| Indonesian standards alignment reference | §1 |
| Full numerical example (including expat_exit_penalty=0.07 → $1,649/m²) | §8 |
| Catalog IDs throughout (EVL-*-NNN format) + calibration_type column | §5 |
| ADR-018, ADR-019, ADR-020 cross-references | throughout |
