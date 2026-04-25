# Architecture Decisions Log — Bali Realty Evaluator

**Status:** living document. ADR records are sequential, never deleted. Corrections handled via new ADR with `Supersedes: ADR-NNN` field.

**Initial population date:** 2026-04-19 (Phase A closing).
**Scope:** все ключевые архитектурные решения Phase A (architecture of the Evaluator tool within Realty Portal canon).

---

## ADR-001: 4-tool pipeline architecture with status-field contract

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Нужно было решить, как организовать pipeline от скрейпинга до advisory. Варианты: monolithic pipeline, microservices, queue-based.
- **Decision:** Четыре независимых инструмента (Scraper → Normalizer → Validator → Evaluator), связанных через статусные поля в `properties` таблице (`normalization_status`, `validation_status`, `evaluation_status`).
- **Rationale:** Канон Алексея (4 таблицы) не позволяет ввести queue-таблицы. Статусы дают контракт без новой инфраструктуры, позволяют независимый re-run каждого инструмента, поддерживают self-healing через invalidation.
- **Alternatives rejected:**
  - Monolithic `evaluate_listing(id)` — нельзя восстановить из частичного failure
  - Kafka/queue между инструментами — overkill для MVP, требует новую инфру
  - Event-driven через Supabase realtime — добавляет complexity без MVP value
- **Implements:** tool-architecture.md v1.1 §2
- **Source docs:** `tool-architecture.md v1.1`

---

## ADR-002: Validator as separate tool (not inside Normalizer)

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Patches 1-3 предполагали валидацию внутри normalize_listing. Clause Code поднял вопрос, не стоит ли выделить отдельно.
- **Decision:** Validator — отдельный pipeline stage со своим статусом.
- **Rationale:** Правила разумности — доменное знание Ильи, меняется субъективно и часто. Normalizer — механика, меняется редко. Разделение позволяет перезапуск Validator без перепарсинга (экономия LLM-бюджета).
- **Alternatives rejected:** Объединение с Normalizer (меньше stages, но mixing concerns).
- **Implements:** EVL-VAL-013 detect_validity_violations, tool-architecture.md §3
- **Source docs:** `tool-architecture.md v1.1 §3`

---

## ADR-003: Zoning as soft-layer, not hard blocker

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Первоначально zoning предлагался как отдельный verification блок с правом блокировать сделку (например, green + foreign_str = FAIL). Ilya возразил: карты Бали могут быть неточны.
- **Decision:** Zoning — soft-layer внутри Sales Comparison. Влияет на (1) сегментацию comp-пула, (2) zone_multiplier в нормализации, (3) задаёт вопрос пользователю в narrative (S_ZONE_CONFIRMATION).
- **Rationale:** Система работает в помойном ведре с неточными данными. Блокировать deal на basis неточного assumption — неправильно. Честнее — показать assumption + consequences, дать пользователю решить.
- **Alternatives rejected:**
  - Hard blocker на `green AND scenario=foreign_str` (rejected из-за inaccuracy risk)
  - Ignoring zoning entirely (rejected — теряется сигнал)
- **Implements:** EVL-CLS-003 classify_assumed_zoning, EVL-NAR-015 (S_ZONE_CONFIRMATION)
- **Source docs:** `sales-comparison-logic.md v1.1 §2`

---

## ADR-004: Legal as external contour (Indologos bot + PNB Law Firm)

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Обсуждался отдельный Legal Verification блок внутри системы.
- **Decision:** Наша система только флагит red_flags и маршрутизирует. Legal verdict — ответственность пользователя + Индологос bot + Philo Dellano (PNB Law Firm).
- **Rationale:** У Ilya уже есть Индологос bot с индонезийским законодательством. Дублировать — неэффективно. Наша задача — правильно идентифицировать ситуации, требующие DD, не замещать юриста.
- **Alternatives rejected:** Full legal engine inside system (overkill, дублирует Индологос).
- **Implements:** EVL-LEG-014 route_legal_to_external
- **Source docs:** `sales-comparison-logic.md v1.1 §3`

---

## ADR-005: Sales Comparison primary, Income/Cost as Phase 2 super-verification

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** IVSC triad (Sales / Income / Cost) — все три метода существуют. Вопрос — что строить первым.
- **Decision:** Sales Comparison строится в MVP как primary. Income (rental yield, cap rate) и Cost (rebuild matrix, Residual Land Value) — Phase 2 super-verifications. Convergence signal: 10-20% расхождение — здоровый рынок; >20% — неэффективность или сломанный Sales Comparison.
- **Rationale:** Sales Comparison — общий для всех residential типов. Income требует AirDNA/Booking scraping (отдельный блок). Cost требует rebuild matrix, которая уже частично калибрована Ilya ($400-1000/m²).
- **Alternatives rejected:** Начать с Income (требует рент-данные Phase 2), начать с Cost (требует полную калибровку matrix).
- **Implements:** весь Evaluator (Phase A scope)
- **Source docs:** `sales-comparison-logic.md v1.1 §1`

---

## ADR-006: Scraper parametrized, not 4 separate skills

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Q-ARCH-1 — 4 отдельных скилла (`scrape_rumah123_land`, `_house`, `_villa`, `_apartment`) vs 1 параметризованный `scrape_rumah123(listing_type)`?
- **Decision:** Один параметризованный скилл с параметром `listing_type`.
- **Rationale:** HTML Rumah123 одинаковый, различается только URL-шаблон и фильтр. 4 скилла = дублирование warm-up / CF-handling / selectors. Дисциплина Алексея "одна задача один скилл" удовлетворена через задачу = "scrape Rumah123", `listing_type` — параметр.
- **Alternatives rejected:** 4 отдельных скилла (дублирование кода).
- **Implements:** scraper skill (Scraper tool, pre-Evaluator)
- **Source docs:** `tool-architecture.md v1.1 §2`

---

## ADR-007: Status fields in properties table, not separate pipeline_state table

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Q-ARCH-4 — статусы pipeline в properties или отдельной таблице?
- **Decision:** Статусы в `properties` таблице (`normalization_status`, `validation_status`, `evaluation_status`).
- **Rationale:** Канон Алексея 4 таблицы нельзя расширять без approval. Добавить 3 колонки + индексы = минимальное вторжение в канон. Читается через `WHERE status`, быстро, нативно.
- **Alternatives rejected:** Отдельная `pipeline_state` таблица (добавляет JOIN'ы, расширяет канон).
- **Implements:** migration 0003, tool-architecture.md §4
- **Source docs:** `tool-architecture.md v1.1 §4`

---

## ADR-008: Diagnostic narrative principle

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Ilya указал, что единственный способ проверить правильность Evaluator — читать narrative и вручную калибровать ломающиеся этапы.
- **Decision:** Narrative — диагностический отчёт, не marketing text. Каждая секция S обязательно называет intermediate results (сегмент, sample_size, confidence level, применённый multiplier, источник lookup). Никакой гладкой прозы — каждое прилагательное подкрепляется числом или идентификатором.
- **Rationale:** Калибровка 16+ скиллов невозможна без возможности трассировать narrative-ошибки обратно к конкретному скиллу. Без диагностической прозрачности — тюнинг вслепую.
- **Alternatives rejected:** Smooth advisory narrative в стиле broker-report (rejected — не калибруется).
- **Implements:** EVL-NAR-015 generate_advisory_narrative
- **Source docs:** `sales-comparison-logic.md v1.1 §12.1`

---

## ADR-009: 27-area closed enum gazetteer

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Сколько областей Бали поддерживать в MVP?
- **Decision:** 27 областей в закрытом gazetteer (Canggu, Berawa, Pererenan… Sidemen). Каждая с per-area defaults (`zone_default`, FAR, KDB, `social_bucket`, `subak_risk`, `parent_district`).
- **Rationale:** 27 покрывает 95% транзакций на Бали (Badung + Gianyar + Denpasar + Tabanan + ограниченно Karangasem/Klungkung/Buleleng). Закрытый enum = детерминированный мэппинг, LLM не выдумывает регионы.
- **Alternatives rejected:** Open-ended geocoding через Nominatim (70% Бали покрытие, добавляет rate-limit complexity).
- **Implements:** `sources._lookup_area_defaults`, `_lookup_bali_gazetteer`, EVL-CTX-001, EVL-CLS-003
- **Source docs:** `sales-comparison-logic.md v1.1 §10`

---

## ADR-010: Zone sensitivity matrix scenario-dependent

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Как количественно оценить влияние zoning на price?
- **Decision:** Matrix multiplier per (scenario × zone). Foreign_str: pink=1.00, yellow=0.75-0.85, green=0.50-0.60. Land_for_development: pink=1.00, yellow=0.70-0.80, green=0.35-0.45.
- **Rationale:** Foreign STR нелегал в green (только LTR exit), yellow требует MSME proxy структуры (operational friction 10-15%). Land dev в green заблокирован (subak + agri risk). Multipliers отражают **рыночный exit pool**, не теоретическую стоимость.
- **Alternatives rejected:** Scenario-independent multipliers (теряет главный фактор).
- **Implements:** EVL-NOR-004 (через zone_multiplier переменную), EVL-STAT-010 compute_price_interval
- **Source docs:** `sales-comparison-logic.md v1.1 §2.2`

---

## ADR-011: Tenure × Zone strictly multiplicative compound

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Как комбинировать tenure decay и zone multiplier?
- **Decision:** Strictly multiplicative: `p_norm = asking ÷ tenure_decay ÷ zone_multiplier × (1−pma) × (1−expat)`.
- **Rationale:** Экономически корректно — penalties накладываются последовательно, не суммируются. Leasehold 20y в yellow zone стоит НЕ (original − 30% − 20%), а (original × 0.67 × 0.80) = 53%. Аддитивный вариант систематически занижает ценность в multi-penalty случаях.
- **Numerical example:** comp leasehold 20 лет yellow за $1000/m², scenario=foreign_str, area=Berawa. `tenure_decay=0.67`, `zone_mult=0.80`, `pma=0.05`, `expat=0.07`. Freehold_pink_eq = $1000 / 0.67 / 0.80 × 0.95 × 0.93 = **$1,649/m²**.
- **Alternatives rejected:** Additive compound (математически неверный для multiplicative risks).
- **Implements:** EVL-NOR-004 normalize_tenure_to_freehold_eq — **do NOT refactor to additive without new superseding ADR**
- **Source docs:** `sales-comparison-logic.md v1.1 §8`

---

## ADR-012: Condition C1-C5 with renovation premium absorption rule

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Как классифицировать состояние и когда flip (купить+отремонтировать+продать) имеет смысл?
- **Decision:** 5 classes (C1 ruins, C2 distressed, C3 standard, C4 modern/renovated, C5 luxury/branded). Absorption rule: C4/C5 → flip всегда disabled (премия уже в asking). C3 AND asking ≥ area_median → flip disabled. C1/C2 → flip open.
- **Rationale:** Продавцы в Бали уже включают ремонт в asking для C4-C5. Платить premium за отремонтированный объект + тратить на дополнительную reno = убыток. MVP считает это явно.
- **Alternatives rejected:** Always-open flip (игнорирует premium), class-independent (теряет сигнал).
- **Implements:** EVL-CLS-002 classify_condition, narrative flip_rule logic
- **Source docs:** `sales-comparison-logic.md v1.1 §9`

---

## ADR-013: Robust z-score via MAD (not std dev)

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Как измерять аномалию цены в сегменте?
- **Decision:** Z-score через median + MAD (Median Absolute Deviation): `z = 0.6745 × (value − median) / MAD`. Коэффициент 0.6745 — унбайашный (Iglewicz & Hoaglin 1993).
- **Rationale:** Помойное ведро = шумные outliers (scam listings, mis-entries). Standard deviation чувствителен к outliers и сам искажается ими. MAD robust. Iglewicz & Hoaglin 1993 — стандартный reference для modified z-score.
- **Alternatives rejected:**
  - Standard deviation z-score (outlier-sensitive — один scam листинг за $100M ломает std всего сегмента)
  - Percentile-based ranking (теряет magnitude сигнала)
- **Implements:** EVL-STAT-011 compute_z_score — **do NOT change to std dev without reading this ADR**
- **Source docs:** `sales-comparison-logic.md v1.1 §5 (skill row 11)`

---

## ADR-014: Sample size thresholds (10 / 30)

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Когда z-score доверяем?
- **Decision:** `sample ≥ 30` → `z_calibrated = high_confidence`. `10 ≤ sample < 30` → `low_confidence`. `sample < 10` → `evaluation_status = uncalibrated`.
- **Rationale:** 30 — стандартный stat-порог для асимптотики. 10 — минимум для осмысленной dispersion-оценки. На тонком рынке Бали (villa в pink Berawa — возможно 20-40 comps) — 30 часто недостижимо, поэтому есть промежуточная категория.
- **Alternatives rejected:**
  - Single threshold 30 (слишком много uncalibrated, теряем сигнал на среднем sample)
  - No thresholds (даёт доверие nonsense numbers при sample=3)
- **Implements:** EVL-STAT-011 compute_z_score, EVL-COMP-005..009 sample size surfacing
- **Source docs:** `sales-comparison-logic.md v1.1 §5 (skill row 11)`

---

## ADR-015: OLX dropped from MVP (Akamai Bot Manager)

- **Date:** 2026-04-19
- **Status:** Accepted (Phase 2+ revisit via Q-OPEN-03)
- **Phase:** A
- **Context:** Изначально OLX планировался как второй источник после Rumah123. Verification показал, что OLX за Akamai Bot Manager, `curl_cffi` не пробивает (возвращает 200 OK + 2.3 KB interstitial page с `bm-verify` токеном, требующим JS execution + proof-of-work).
- **Decision:** OLX dropped из MVP scope. Rumah123 только. OLX → Phase 2+ с другим scraping подходом (Playwright в Docker / residential proxies).
- **Rationale:** Akamai bot detection — серьёзный блок, требует dedicated infra (4-й сервис в канон-«3 сервиса»). Не MVP уровня. Rumah123 покрывает 60-70% Бали real estate listings.
- **Alternatives rejected:**
  - Full OLX scraping через residential proxies (expensive, unstable)
  - FlareSolverr / commercial bypass services (budget constraint)
- **Implements:** scraper tool scope (single-source MVP)
- **Source docs:** `tool-architecture.md v1.1 §8 Critical finding`, HTML evidence in `/tmp/olx_probe/` on Aeza

---

## ADR-016: pma_compliance_overhead_pct — compliance (NOT taxes), with leasehold-aware amortization

- **Date:** 2026-04-19 (revised после Ilya's clarification)
- **Status:** Accepted (calibration pending Q-OPEN-10)
- **Phase:** A
- **Context:** Foreign buyer через PT PMA несёт annual compliance cost юр-лица. Нужен параметр в compound-формуле §8.
- **Decision:**
  - Параметр переименован: `pma_overhead_pct` → **`pma_compliance_overhead_pct`** (явно указывает что это compliance, не налоги).
  - Default **5%** для base case (freehold, 10-year target holding).
  - **Leasehold-aware amortization:** `pma_compliance_overhead_pct_applied = 0.05 × (effective_amortization_years / 10)`, где `effective_amortization_years = freehold: 10; leasehold: min(10, lease_years_remaining)`.
  - Stored в `sources._lookup_evaluation_constants`:
    - `pma_compliance_overhead_pct_default = 0.05`
    - `default_target_holding_years = 10`
- **Rationale (compliance scope):**
  - **IN scope:** notary annual retainer, accountant (Disa / Delta Pro), LKPM quarterly reports (BKPM), BPJS director insurance, virtual office rental. ~€1500-2500/год amortized over holding period.
  - **OUT of scope (explicitly):** BPHTB (transfer tax), PPh (income tax), PPN (VAT on commercial), PBB (annual property tax). **Taxes belong to transaction-economics block (Q-OPEN-14), Phase 2+.**
- **Rationale (leasehold scaling):** если lease осталось 5 лет — PMA нельзя держать 10 лет после окончания аренды. Amortization укорачивается до `min(target, remaining)`. Короткий leasehold → меньше compliance pct applied. Это математически и экономически корректно; фиксированные 5% для всех tenure систематически over-penalize короткие leasehold.
- **Alternatives rejected:**
  - 0% (unrealistic — compliance реален)
  - 10% (over-penalizes lifestyle buyer)
  - Fixed 5% for all tenures (old v1.0 version, rejected — неверен для leasehold)
  - Include taxes (rejected — taxes = transaction economics, not normalization)
- **Implements:** EVL-NOR-004 normalize_tenure_to_freehold_eq, `_lookup_evaluation_constants`
- **Source docs:** `sales-comparison-logic.md v1.1 §8`
- **Trigger for revision:** Q-OPEN-10 (Disa cost sheet calibration) + Q-OPEN-14 (transaction economics separate block)

---

## ADR-017: 9-value listing_subtype enum including commercial

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A
- **Context:** Claude Code предложил split villa/rumah (они — разные рыночные сегменты на Бали). Ilya добавил commercial (kantor/gudang/pabrik/ruko) из Rumah123 listings.
- **Decision:** `listing_subtype ∈ {land, villa, rumah, apartment, commercial_office, commercial_warehouse, commercial_industrial, commercial_shop, ambiguous}`. Extraction в Normalizer через keyword matching.
- **Rationale:** Villa и rumah на Бали — РАЗНЫЕ рыночные сегменты (tourist STR vs local family). Объединение comp-pool = искажённый z-score (обе группы выглядят аномальными относительно усреднённой median). Commercial добавлен для покрытия полного Rumah123 classification tree с MVP-disclaimer в narrative.
- **Numerical justification for split:** Canggu villa median ~$350K (C4-ready STR), Canggu rumah median ~$150K (C2-C3 local family). Объединённая median ~$250K → обе группы выглядят аномальными.
- **Alternatives rejected:**
  - Single "house" category (reject — ломает сегментацию)
  - Only residential (reject — Rumah123 имеет commercial листинги)
  - Single `find_comps_configuration(listing_type)` параметризованный (reject — неявно объединяет pools без явного split-контракта)
- **Ambiguous fallback:** Ilya's addendum — если keywords смешаны или отсутствуют → `ambiguous` → запускаются оба скилла villa + rumah, выбирается interval с tighter MAD, flag в narrative `S_SUBTYPE_CONFIRMATION`.
- **Implements:** Normalizer `listing_subtype` field; EVL-COMP-005..009 (5 separate comp skills by subtype); EVL-ORC-016 routing logic
- **Source docs:** `sales-comparison-logic.md v1.1 §4-5`, `tool-architecture.md v1.1 §2`

---

## ADR-018: Industrial (pabrik) forced uncalibrated

- **Date:** 2026-04-19
- **Status:** Accepted (validation pending Q-OPEN-07)
- **Phase:** A
- **Context:** Для commercial в общем Sales Comparison работает как approximation. Для industrial — не работает в принципе.
- **Decision:** Если `listing_subtype = commercial_industrial` → `evaluation_status = uncalibrated` (forced, независимо от sample_size). Narrative выдаёт отдельный disclaimer и рекомендует specialized industrial appraiser.
- **Rationale:** Industrial имеет specific equipment, permits, workforce infrastructure, которые делают каждый объект уникальным. Comp-pool для pabrik в принципе не сопоставим. Честнее отказаться от оценки, чем давать misleading interval.
- **Alternatives rejected:** Same logic as commercial_office/warehouse (даёт cargo-cult number).
- **Implements:** EVL-ORC-016 force-uncalibrated routing, EVL-NAR-015 industrial-specific disclaimer в S_COMMERCIAL_DISCLAIMER
- **Source docs:** `sales-comparison-logic.md v1.1 §12`

---

## ADR-019: Calibration type per skill (not uniform triangulation)

- **Date:** 2026-04-19
- **Status:** Accepted
- **Phase:** A pre-Day-1
- **Context:** Изначально предлагалась LLM triangulation всех 16 скиллов одинаково (4 LLM per skill через OpenRouter, agreement scoring).
- **Decision:** 6 calibration types. Каждый SKILL.md получает field `calibration_type` в YAML header.
  - **llm_prompt** (3 скилла): 4 LLM через OpenRouter/free APIs, agreement scoring, grade A-F
  - **sql_query** (7 скиллов): 3 LLM propose SQL, result-set diff на test fixtures
  - **deterministic_formula** (1 скилл): unit tests с fixture inputs
  - **rule_based** (3 скилла): table-driven tests
  - **lookup** (1 скилл): SQL sanity check
  - **orchestrator** (1 скилл): integration test через full pipeline
- **Rationale:** Пуск 4 LLM на deterministic formula `price ÷ decay ÷ zone × (1-pma)(1-expat)` — theatre. Все дадут одинаковое число. Triangulation осмыслена только там, где есть judgment (classification, narrative). Остальные 13 скиллов валидируются дешевле и точнее через tests / SQL diff / rule tables.
- **Cost savings:** Triangulation battery $5-7 → $1-2 per iteration (reality: ~$0 если через free-tier APIs).
- **Alternatives rejected:** Uniform 4-LLM triangulation (wasted calls + agreement theatre на детерминистике).
- **Implements:** `validate_skills_cross_ai.py` branches by calibration_type, SKILL.md YAML header
- **Source docs:** Catalog update discussion, Day 1 plan

---

## ADR-020: Markdown ADR log instead of vectorized architecture library

- **Date:** 2026-04-19
- **Status:** Accepted (vectorization deferred to Phase 2-3 via Q-OPEN-04)
- **Phase:** A pre-Day-1
- **Context:** Claude-architect предложил vectorize все чаты + research outputs в pgvector для semantic search with supersedes/superseded relationships auto-classification.
- **Decision:** MVP knowledge preservation = 3 markdown-файла (`ilian-core-context.md` + `decisions-log.md` + `open-questions.md`). Vectorization отложена до Phase 2-3.
- **Rationale:**
  - Corpus <500K tokens (architect изначально оценил 1.5M — завышено в 3-4×)
  - Query frequency 2-3 per month (не 10/day)
  - Markdown grep + git diff покрывают 95% use cases
  - Vectorization дает +5% за 20× complexity и стоимость
  - Technical issue: Voyage embeddings не доступен через OpenRouter (architect ошибся)
  - Chat exports требуют часов ручной работы Ilya (не «тривиально автоматически»)
  - Supersedes/superseded detection через Haiku даёт noisy output
- **Triggers for reconsideration (Phase 2-3):** corpus grows >10M tokens, OR query frequency >5/day, OR multi-user access, OR calibration history accumulates (1280+ LLM outputs).
- **Alternatives rejected:**
  - Full vectorization now (YAGNI)
  - No knowledge preservation at all (архитектурный дрейф risk через 3 месяца)
- **Implements:** this `decisions-log.md` file itself
- **Source docs:** Claude Code sanity-check response

---

# Index — quick lookup

**Pipeline architecture:**
- ADR-001 — 4 tools + status contract
- ADR-002 — Validator separation
- ADR-007 — Status fields, not separate table

**Evaluator methodology:**
- ADR-003 — Zoning as soft-layer
- ADR-005 — Sales Comparison primary, Income/Cost Phase 2
- ADR-008 — Diagnostic narrative principle
- ADR-019 — Calibration type per skill

**Domain decisions:**
- ADR-004 — Legal external (Indologos)
- ADR-009 — 27-area gazetteer
- ADR-010 — Zone sensitivity matrix
- ADR-011 — Multiplicative compound
- ADR-012 — Condition C1-C5 with absorption
- ADR-016 — pma_overhead 5%
- ADR-017 — 9-value listing_subtype
- ADR-018 — Industrial forced uncalibrated

**Statistical choices:**
- ADR-013 — MAD-based z-score
- ADR-014 — Sample thresholds 10/30

**Scope decisions:**
- ADR-006 — Parametrized scraper
- ADR-015 — OLX dropped MVP
- ADR-020 — Markdown ADR (not vectorization)

---

## ADR → Skill mapping (auto-generated header for gen_skills_v1)

Used by `gen_skills_v1_from_logic.py` to inject **Architectural lineage** section into each SKILL.md.

| Skill catalog_id | Primary ADRs |
|---|---|
| EVL-CTX-001 | ADR-009 |
| EVL-CLS-002 | ADR-008, ADR-012 |
| EVL-CLS-003 | ADR-003, ADR-009, ADR-010 |
| EVL-NOR-004 | ADR-011, ADR-016 |
| EVL-COMP-005 | ADR-017 |
| EVL-COMP-006 | ADR-017, ADR-010 |
| EVL-COMP-007 | ADR-017, ADR-010 |
| EVL-COMP-008 | ADR-017 |
| EVL-COMP-009 | ADR-017, ADR-018 |
| EVL-STAT-010 | ADR-010, ADR-014 |
| EVL-STAT-011 | ADR-013, ADR-014 |
| EVL-LIQ-012 | (none specific; general pipeline ADR-001) |
| EVL-VAL-013 | ADR-002 |
| EVL-LEG-014 | ADR-004 |
| EVL-NAR-015 | ADR-008, ADR-003, ADR-017, ADR-018 |
| EVL-ORC-016 | ADR-001, ADR-006, ADR-007, ADR-017, ADR-018 |
