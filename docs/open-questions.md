# Open Questions — живой список pending validations и deferred decisions

**Формат:** каждый вопрос имеет ID `Q-OPEN-NN`, статус, источник, метод валидации, trigger для reconsideration. Закрытые вопросы перемещаются в `decisions-log.md` как новые ADR.

---

## Q-OPEN-01: Zoning enum extension (red / blue)

- **Status:** deferred until commercial listings accumulate
- **Priority:** low для MVP
- **Source:** `sales-comparison-logic.md v1.1 §2`, ADR-017
- **Context:** Текущий `zoning` enum = `{pink, yellow, green, mixed, unknown}`. На Бали commercial недвижимость использует `red` (коммерческая) и `blue` (индустриальная) зоны RTRW. В MVP commercial объекты получают `mixed` или `unknown` + flag в narrative.
- **Validation method:** когда 10-20 commercial-листингов (`listing_subtype IN commercial_*`) попадут в raw_listings — проверить как parser их классифицирует и какие zoning hints в description. Тогда решить: расширять enum или оставить `mixed` как catch-all.
- **Trigger for reconsideration:** ≥10 commercial listings in raw_listings

---

## Q-OPEN-02: Rebuild cost calibration через Berawa project

- **Status:** pending owner confirmation
- **Priority:** medium (блокирует точность `land_for_development` scenario в Phase 2)
- **Source:** Clause-architect conversation, `rebuild_cost_per_m2` placeholder $1000/m² turnkey
- **Context:** Cost approach формула `max_land_price = exit_value × zone_factor − (construction + soft_costs + permits + holding + PMA + profit_margin + selling)` требует реалистичной `rebuild_cost_per_m2`. Клод-архитектор упомянул проект Ильи Berawa (170 m² земли, 218 m² built, $245K total, Japandi style «OceaniQ Stone Fortress») — implicit ~$1120/m² включая soft. Проверить актуальность.
- **Validation method:** Илья подтверждает параметры проекта или корректирует. Сохранить как regression anchor в `sources._lookup_evaluation_constants.rebuild_cost_per_m2_by_segment`.
- **Trigger for reconsideration:** Илья готов калибровать; или когда Phase 2 начнёт Cost approach

---

## Q-OPEN-03: OLX revisit через Playwright infrastructure

- **Status:** deferred to Phase 2
- **Priority:** medium (потеря 20 000+ листингов tanah от прямых собственников)
- **Source:** ADR-015
- **Context:** OLX.co.id за Akamai Bot Manager, требует JS execution + proof-of-work. `curl_cffi` не пробивает. Альтернативы: (a) 4-й сервис `realty_scraper` с Playwright в Docker; (b) коммерческий bypass (FlareSolverr / Bright Data); (c) residential proxy ротация.
- **Validation method:** по завершении Phase A production + первый cycle калибровки — пересмотреть ROI добавления OLX. Если Rumah123 даёт недостаточно land-comps в `find_comps_land` (sample_size <10 часто) — OLX критичен. Если Rumah123 хватает — можно отложить Phase 3.
- **Trigger for reconsideration:** Phase 2 start; OR Rumah123 sample_size для land segment регулярно <10

---

## Q-OPEN-04: Vectorized Architecture KB reconsideration

- **Status:** deferred (ADR-020)
- **Priority:** low
- **Source:** ADR-020
- **Context:** Выбрали markdown ADR log вместо pgvector Architecture KB для MVP. Пересмотреть если условия изменятся.
- **Triggers for reconsideration:**
  - Corpus grows >10M tokens (сейчас ~500K)
  - Query frequency >5/day (сейчас 2-3 раз в месяц)
  - Multi-user access (сейчас single-user Ilya)
  - Calibration history накапливается (1280+ LLM outputs после 3-5 batteries)
- **Validation method:** quarterly review; если любой trigger сработал — revisit

---

## Q-OPEN-05: Gemini + DeepSeek + Groq API keys (Day 3 triangulation)

- **Status:** pending — Ilya регистрируется
- **Priority:** high (блокирует Day 3 triangulation battery)
- **Source:** ADR-019 calibration type per skill; 4-LLM triangulation для llm_prompt skills
- **Context:** Triangulation для 3 llm_prompt скиллов (EVL-CLS-002 classify_condition, EVL-CLS-003 classify_assumed_zoning, EVL-NAR-015 generate_advisory_narrative) требует 4 независимых вендоров. Claude Opus уже есть (ключ в `/opt/realty-portal/.env`). Добавить:
  - Gemini 2.5 Pro через Google AI Studio free tier ([ai.google.dev](https://ai.google.dev))
  - DeepSeek R1 через прямой API ($5 free credits, [platform.deepseek.com](https://platform.deepseek.com))
  - Groq Llama 3.3 70B через free tier ([console.groq.com](https://console.groq.com))
- **Validation method:** Ilya регистрирует → передаёт keys → добавить в `.env` + LiteLLM config.yaml → smoke-test каждого вендора через 1 ping-запрос.
- **Trigger:** Ilya готов регистрироваться

---

## Q-OPEN-06: Alexey approval на Phase A docs

- **Status:** pending owner action
- **Priority:** low для Day 1-5 (не блокирует), high для production deploy
- **Source:** `docs/alexey-pitch-mvp-stack.md`
- **Context:** `tool-architecture.md v1.0` + `sales-comparison-logic.md v1.0` отправлены Алексею на approval через sales-pitch document. Расширения к канону (area_defaults в `sources.config` JSONB, status fields в properties) требуют формального sign-off Алексея. До approval — двигаемся параллельно (код пишется на правах Phase A approved tentatively).
- **Validation method:** Ilya отправляет Алексею документы → получает feedback → корректировки в v1.2 если нужно.
- **Trigger:** Ilya готов отправить Алексею; OR production deploy approaches

---

## Q-OPEN-07: Industrial subtype (pabrik) — real-world validation

- **Status:** open assumption
- **Priority:** low (edge case)
- **Source:** ADR-018
- **Context:** Приняли что `commercial_industrial` (pabrik) → `evaluation_status=uncalibrated` forced, narrative рекомендует specialized appraiser. Assumption: каждая фабрика unique, comp-pool не сопоставим. Валидация: при первых 5-10 pabrik-листингах в raw_listings — проверить, что действительно есть специфичные equipment/permits/workforce markers в descriptions.
- **Validation method:** pabrik listings arrive → проверить descriptions → подтвердить или revise ADR-018.
- **Trigger:** ≥5 pabrik listings in raw_listings

---

## Q-OPEN-08: Ambiguous listing_subtype — tighter-MAD selection правильно?

- **Status:** open assumption
- **Priority:** low
- **Source:** ADR-017 (Ilya's addendum — ambiguous fallback)
- **Context:** При `listing_subtype=ambiguous` запускаются оба скилла `find_comps_villa` + `find_comps_rumah`, выбирается interval с **tighter MAD**. Assumption: tighter MAD = более релевантный comp-pool. Альтернатива: выбирать pool с бóльшим sample_size; или всегда выдавать оба + просить user решить.
- **Validation method:** после первой calibration-батареи — посмотреть на 5-10 ambiguous cases, оценить правильность selection. Если tighter-MAD часто выбирает «wrong» pool — revise правило.
- **Trigger:** first calibration battery output includes ≥5 ambiguous listings

---

## Q-OPEN-09: Zone multiplier ranges точны ли?

- **Status:** open — need real-data validation
- **Priority:** medium (влияет на все оценки в yellow/green zones)
- **Source:** `sales-comparison-logic.md v1.1 §2.2`, ADR-010
- **Context:** Matrix multipliers (например foreign_str yellow=0.75-0.85) — это broker judgment + industry reports, не real-data regression. В Phase 2+ после накопления 100+ yellow-comps возможно regression-based calibration.
- **Validation method:** Phase 2 — когда properties содержит 100+ yellow-zone transactions, посчитать actual median price ratio vs pink-zone → сверить с 0.80 midpoint.
- **Trigger:** 100+ yellow-zone properties in BD; OR first cycle production reveals systematic bias

---

## Q-OPEN-10: pma_overhead_pct = 5% vs реальность PT Royal Palace Address

- **Status:** pending owner calibration
- **Priority:** low (уже в MVP как default)
- **Source:** ADR-016
- **Context:** 5% amortized hardcoded. Ilya может проверить на cost-книгах PT Royal Palace Address: годовой notary + accountant + LKPM + BPJS + virtual office vs property value × holding period. Если реальность 3-4% или 7-8% — подкорректировать.
- **Validation method:** Disa (accountant) выдаёт annual cost sheet PT Royal Palace → calculate effective pct. Обновить `_lookup_evaluation_constants.pma_overhead_annual_amortized_pct`.
- **Trigger:** Ilya готов запросить у Disa cost breakdown

---

## Q-OPEN-11: Bali cap rates для Phase 2 Income Approach (Colliers/Knight Frank)

- **Status:** deferred to Phase 2
- **Priority:** medium (блокирует Income Approach super-verification)
- **Source:** `indonesian-valuation-standards-reference.md`
- **Context:** Phase 2 подключает Income Approach как cross-verification Sales Comparison. Требует cap rates по сегментам: Bali office 8-10%, retail/ruko 9-11%, warehouse 7-9%, villa STR 7-10%, hotel 9-13%, industrial 10-14%. Эти числа — из Colliers Indonesia / Knight Frank / published KJPP reports. Для MVP пишем как placeholder в `_lookup_evaluation_constants.cap_rates_by_segment`, Phase 2 валидируем/обновляем через реальные market reports.
- **Validation method:** Phase 2 start — subscription или one-time request к Colliers Monica Koesnovagril (Bali contact) или Knight Frank Indonesia (PT Willson Properti Advisindo) за latest cap rate data.
- **Trigger for reconsideration:** Phase 2 Income Approach implementation start

---

## Q-OPEN-12: Bata coefficient variance by banjar

- **Status:** open — needs Ilya's field knowledge
- **Priority:** low (только для edge cases в parsing size)
- **Source:** Regex spec `sizes.py`, 1 bata ≈ 12-14 m²
- **Context:** Балийский bata — традиционная единица площади, НЕстандартизирована. Варьируется 12-14 m² между banjars (subdistricts). MVP hardcodes 13 m² как mid-point. Но для точности нужна per-area калибровка — например, Canggu-banjar может быть 12.5, Ubud-banjar — 13.5.
- **Validation method:** Ilya собирает data points от local contacts (brokers в Canggu/Ubud/Seminyak): «какой bata у вас в banjar X?». Заполняет таблицу per-banjar. Храним в `_lookup_evaluation_constants.bata_coefficient_by_banjar`.
- **Trigger for reconsideration:** Ilya готов опросить contacts; OR первый листинг с размером в bata приходит в narrative с явным wrong interval

---

## Q-OPEN-13: expat_exit_penalty_pct per area calibration

- **Status:** open assumption
- **Priority:** medium (влияет на normalize_tenure formula для foreign scenarios)
- **Source:** `sales-comparison-logic.md v1.1 §8`, numerical example использует 0.07 для Berawa
- **Context:** L5 BOTH-logic выдаёт `expat_exit_penalty_pct` per area × scenario. Для `foreign_investor_str_via_pma` в Berawa используется 0.07 (assumption). Реальный penalty = насколько тоньше buyer pool для foreign exit относительно local-only exit. Зависит от: % expat-агентов в районе, days_on_market разница foreign-owned vs local-owned, price concession на closing.
- **Validation method:** Phase 2+ — когда в properties накопится 50+ sold listings с tenure_type history, посчитать actual delta price foreign-resale vs local-resale per area.
- **Trigger for reconsideration:** 50+ sold transactions in BD with resale data; OR broker-consensus poll in Bali expat community

---

## Q-OPEN-14: Transaction economics block (taxes + closing costs)

- **Status:** deferred to Phase 2 (separate block, NOT in Phase A compound normalization)
- **Priority:** high для production валидации (влияет на реальный вход/выход денег)
- **Source:** Ilya's clarification 2026-04-19, ADR-016 scope note
- **Context:** Phase A compound formula (§8) включает только **compliance overhead** на PT PMA. Реальные налоги, которые покупатель/продавец платят по сделке, это **отдельный экономический блок**, не часть normalization:

  | Налог / расход | Природа | Ставка / диапазон | Сторона | Триггер |
  |---|---|---|---|---|
  | **BPHTB** (Bea Perolehan Hak atas Tanah dan Bangunan) | transfer tax | 5% от NJOP (assessed value), с вычетом NJOPTKP | покупатель | при передаче права |
  | **PPh** final (Pajak Penghasilan) | seller income tax | 2.5% от transaction value | продавец | при продаже |
  | **PPN** (Pajak Pertambahan Nilai) | VAT | 11% | покупатель | при покупке от developer/PKP |
  | **PBB** (Pajak Bumi dan Bangunan) | annual property tax | 0.1-0.3% NJOP | владелец | ежегодно |
  | Notary fees | closing | 0.5-1% от value | обычно покупатель | при закрытии |
  | PPAT fees (land deed) | closing | ~1% | покупатель | при передаче права |
  | Agent commission | closing | 2-5% | обычно продавец | при закрытии |

  Для leasehold: BPHTB не применяется (это не transfer права собственности), но PPh на доход продавца от lease есть.

- **Why NOT in compound normalization:**
  1. Normalization = приведение comp к subject на level "стоимости актива". Налоги = деньги, уходящие из кармана, это transaction-level.
  2. Налоги зависят от многих факторов: is developer/individual seller, is freehold/leasehold, local tax rates (могут меняться RPJMN).
  3. Смешивание compliance + taxes делает formula непрозрачной и некалибруемой.

- **Proposed Phase 2 architecture:**
  - New skill `compute_transaction_economics` (EVL-STAT-XX в Phase 2 numbering)
  - Inputs: subject.price, tenure, listing_subtype, scenario, seller_type (individual/developer/PKP)
  - Outputs: structured breakdown {bphtb_idr, pph_idr, ppn_idr, pbb_annual_idr, notary_fees, ppat_fees, agent_commission} + total_buyer_cost + total_seller_proceeds
  - Separate narrative section S_TRANSACTION_ECONOMICS
- **Validation method:** когда Phase 2 начнётся — опросить tax consultant / Philo Dellano / Disa на точные текущие ставки + edge cases.
- **Trigger for reconsideration:** Phase 2 start

---

## Q-OPEN-15: Zoning accuracy with/without pin coordinates

- **Status:** open, ready for probe-level data collection
- **Priority:** medium (blocks Phase 2 RTRW integration, but not Phase A)
- **Source:** ChatGPT analysis 2026-04-20 + Claude Code pin-probe 2026-04-20
- **Context:** EVL-CLS-003 сейчас использует только `area_defaults` gazetteer + LLM hint-check в description. Rumah123 detail-pages дают GPS-координаты, но с **переменной точностью**:
  - Part I: реальный pin (~1m precision, например `-8.54504, 115.11996` — 5 decimals)
  - Part II: area-centroid (~11km precision, например `-8.8, 115.23333` — 1-2 decimals)
  - Дифференциатор: число decimals в `latitude` (≥3 → real pin; ≤2 → centroid, бесполезно как text)
- **Hypothesis:** адекватная `listing_lat/lng` с precision≥3 decimals → reverse-geocode → `specific_area` с confidence=high, zone lookup точнее чем text-based. Для precision-centroid координат смысла нет — возвращаемся к area_defaults.
- **Probe findings (2026-04-20):**
  - GPS extractable via plain regex from `"geo":{"@type":"GeoCoordinates","latitude":X,"longitude":Y}` JSON-LD
  - **No JS execution needed** (curl_cffi достаточно)
  - CF блокирует после 2-3 detail-requests подряд — нужен ≥15s rate-limit
- **Validation method:**
  1. Собрать detail-pages для ~20 листингов (rate-limit 20s, 2 retry, 1 час wall time)
  2. Извлечь `listing_lat, listing_lng, lat_decimals` → разметить `location_source ∈ {pin_precise, pin_centroid, text_only}`
  3. Для `pin_precise` → запустить EVL-CLS-003 с координатами в prompt + сравнить с text-only baseline
  4. Измерить: agreement с human-labeled ground truth на contested (Grade C) cases
- **Trigger for reconsideration:** Q-OPEN-05 (API keys Day 3) сделан + подписка Алексея активна + Phase A closed → implement detail-fetcher + ADR-023 accept
- **Expected impact:** 10-30% reduction в Grade-C (contested) cases для CLS-003; больший impact для Tabanan (coast vs subak), Canggu/Kerobokan boundary, Ubud/Penestanan

---

## Q-OPEN-16: Multi-source scraping strategy (Rumah123 + Lamudi + Fazwaz triangle)

- **Status:** open, probe 2026-04-20 validated 3 non-fragile sources
- **Priority:** high — unlocks agent clustering + price spread detection
- **Source:** Multi-board probe 2026-04-20, Ilia insight (agents have listing packages)
- **Context:** Rumah123 alone insufficient for:
  - agent-phone extraction (detail-pages CF-blocked)
  - price-spread detection (single source = no spread)
  - cross-platform agent portfolio
  3 viable sources identified: Rumah123 (IDR volume + zoning hints), Lamudi (IDR + agent phones on detail), Fazwaz (USD + GPS on list-page). 99.co + Dotproperty CF-walled (rejected per ADR-015 no-Playwright rule).
- **Validation method:**
  1. Phase A.5: add Lamudi scraper (canonically identical URL pattern), shadow parallel to Rumah123
  2. Measure: % listings with phone extractable, agent clustering density, price variance same-listing
  3. If evidence supports value → add Fazwaz as third leg
- **Trigger for reconsideration:** Phase A baseline v2 closed + canon review с Алексеем

---

## Q-OPEN-17: Agent database as monetization foundation vs enrichment

- **Status:** strategic direction set (monetization), technical pattern open (JSONB vs 5-й table)
- **Priority:** medium for MVP, high for Phase 2 business model
- **Source:** Ilia broker insight 2026-04-20 + ChatGPT strategic analysis
- **Context:** Agents → 5 монетизационных pathways (SaaS, lead-gen, co-marketing, reports, B2B API). Для этого нужны агент-поля (CRM status, tier, behavior tags, external profiles). Полный набор в `docs/alexey-reference/research/agent-monetization-strategy-2026-04-20.md`.
  - **Option A (canon-safe):** `sources._lookup_agents JSONB` — preserves 4-table canon. All fields as nested JSON, GIN-indexed.
  - **Option B (canon-breaking):** separate `agents` table as 5th canonical table. Cleaner queries, better performance at scale, but requires Alexey sign-off.
- **Validation method:**
  1. Phase A.5: implement Option A (JSONB) — functional identical для MVP
  2. Phase B: measure query performance at scale (expected 500-2000 agents initial, 10K+ mature)
  3. Phase 2: present evidence to Alexey → decide stay JSONB or migrate to Option B
- **Privacy constraint:** public-data only, deletion rights honored, no third-party sale, no negative public attribution (draft ADR-027)
- **Trigger for reconsideration:** Lamudi data stream live + ≥100 agents extracted + query performance measurable

---

## How to update this file

- **Вопрос закрывается** → переместить в `decisions-log.md` как новый ADR, здесь оставить ссылку «resolved in ADR-NNN, date».
- **Новый вопрос возникает** → следующий номер Q-OPEN-NN, заполнить все поля.
- **Status меняется** → обновить inline.
- **Trigger сработал** → промаркировать «TRIGGER FIRED, reconsider now».
