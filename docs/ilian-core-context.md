# Core Context — Bali Realty Evaluator (cold-start reference)

**Purpose:** этот файл читается **первым** при открытии новой AI-сессии или онбординге нового человека. Даёт 95% контекста за 10 минут.

---

## Кто и что

**Owner:** Илья. Брокер недвижимости 20+ лет (Дубай / Сочи / Бали), сейчас живёт на Бали в Canggu/Berawa. Учредитель **PT Royal Palace Address** (KBLI 68111 — real estate investment / development / analysis). Технический новичок, общается по-русски. Основной инвестиционный фокус: **land development** + **flip rumah→villa** + **STR via PT PMA**.

**Что строим:** Bali Realty Evaluator — система для оценки объявлений недвижимости Бали. Парсит Rumah123 → нормализует в структурированные поля → валидирует → оценивает через Sales Comparison → выдаёт advisory-отчёт брокеру («мы считаем объект переоценён на 25% для сценария foreign_investor_str_via_pma, confidence medium…»).

**Не что строим:** не Zillow-precision. Не full legal DD. Не Income-approach (rental yield) в MVP. Цель — **грубая сетка стоимости + диагностические красные флаги** для обоснования broker advisory клиенту.

---

## Где находимся

**Phase A (architecture) — CLOSED 2026-04-19.**
Финализированы: `tool-architecture.md v1.0`, `sales-comparison-logic.md v1.0` → обновляются до v1.1 в Day 1.

**Day 1 (in progress):** 3 storage artifacts + v1.1 docs + `gen_skills_v1_from_logic.py` → 16 черновых SKILL.md.

**Day 2 (pending):** Ilya читает и правит.

**Day 3+ (pending):** triangulation battery через 4 бесплатных LLM (Claude Opus + Gemini 2.5 Pro + DeepSeek R1 + Groq Llama 3.3) — калибровка 3 LLM-скиллов; SQL/unit/rule tests для остальных.

**Day 11+ (pending):** production код пишется **с уже откалиброванными промптами**.

---

## Инфраструктура

**VPS:** Aeza, Вена (EU), IP 193.233.128.21, 2 vCPU / 8 GB RAM (апгрейдено с 4 GB) / 60 GB диск, Ubuntu 24.04. Root-пароль Ilya хранит локально.

**Стек на сервере (17 контейнеров, префикс `realty_*`):**

| Сервис | Роль | Состояние |
|---|---|---|
| supabase-* (13 контейнеров) | БД + Auth + Storage + Studio + Kong + Pooler + Realtime + Analytics + Edge Functions + Vector | все healthy |
| realty_lightrag | RAG для domain knowledge Бали | up (не используется в Phase A) |
| realty_litellm | LLM gateway (Anthropic ключ настроен, добавляются Gemini/DeepSeek/Groq в Day 3) | up |
| realty_ollama | embeddings (all-minilm) | up |
| realty_openclaw | SaaS skill engine (`anthropic/claude-haiku-4-5-20251001`) | up, видит 5 stub-skills, готов к 16 |

**БД:** Supabase self-hosted с канон-4 таблицами (raw_listings, properties, market_snapshots, sources). После миграций 0002-0004: properties = 73 колонки, 4 lookup-записи в sources, 3 helper-функции (`get_area_default`, `is_known_area`, `is_market_gap_fresh`), полный словарь red_flags (~80 маркеров).

**Scraper:** Rumah123 через `curl_cffi impersonate=chrome120` (обходит Cloudflare IUAM). 100% fill rate verified на 20 карточках. OLX dropped (Akamai Bot Manager, curl_cffi не проходит).

**doctor.sh:** 19/19 passed.

---

## Advisors (внешний контур Ilya)

| Роль | Кто | Где используется в системе |
|---|---|---|
| Legal (property law Индонезия) | **Philo Dellano / PNB Law Firm** | routing target в EVL-LEG-014 (red_flags high-severity → narrative рекомендует «передать в PNB до задатков») |
| Accountant / PT PMA compliance | **Disa / Delta Pro** | калибровка `pma_overhead_pct` (Q-OPEN-10): Disa выдаёт annual cost sheet PT Royal Palace Address → effective % считаем |
| Legal bot (automated) | **Индологос bot** (Ilya's existing product) | co-routing с PNB в narrative — быстрая проверка документов перед походом к юристу |

Система **не дублирует** этих advisors. Наша задача — правильно идентифицировать ситуации, требующие их вмешательства (ADR-004 legal external contour).

---

## 4-tool pipeline (канон tool-architecture.md v1.1)

```
sources  →  SCRAPER  →  raw_listings
                            ↓  (status=pending)
                        NORMALIZER  →  properties
                                            ↓  (normalization_status=complete|partial|failed)
                                        VALIDATOR  →  properties
                                                         ↓  (validation_status=ok|warn|fail)
                                                     EVALUATOR  →  properties
                                                                      (evaluation_status=ok|uncalibrated|failed)
                                                                      narrative_* fields
```

Каждый инструмент cron-независим, идемпотентен, читает **только статус предыдущего**. Self-healing через invalidation при обновлении lookups.

---

## 16 скиллов Evaluator (sales-comparison-logic.md v1.1)

| Catalog ID | Name | Calibration type |
|---|---|---|
| EVL-CTX-001 | enrich_area_context | lookup |
| EVL-CLS-002 | classify_condition | llm_prompt |
| EVL-CLS-003 | classify_assumed_zoning | llm_prompt |
| EVL-NOR-004 | normalize_tenure_to_freehold_eq | deterministic_formula |
| EVL-COMP-005 | find_comps_land | sql_query |
| EVL-COMP-006 | find_comps_villa | sql_query |
| EVL-COMP-007 | find_comps_rumah | sql_query |
| EVL-COMP-008 | find_comps_apartment | sql_query |
| EVL-COMP-009 | find_comps_commercial | sql_query |
| EVL-STAT-010 | compute_price_interval | sql_query |
| EVL-STAT-011 | compute_z_score | sql_query |
| EVL-LIQ-012 | assess_liquidity_proxy | rule_based |
| EVL-VAL-013 | detect_validity_violations | rule_based |
| EVL-LEG-014 | route_legal_to_external | rule_based |
| EVL-NAR-015 | generate_advisory_narrative | llm_prompt |
| EVL-ORC-016 | evaluate_sales_comparison | orchestrator |

Breakdown: 3 llm_prompt (реальная triangulation) + 7 sql_query (diff result-sets) + 1 deterministic_formula (unit tests) + 3 rule_based (table-driven tests) + 1 lookup + 1 orchestrator.

---

## Ключевые архитектурные решения

Полный список в `decisions-log.md` (20 ADR). Самые важные для быстрого контекста:

- **ADR-003** — Zoning = soft-layer (не hard blocker). Карты Бали неточны, честнее показать assumption + consequences.
- **ADR-004** — Legal = external (Indologos bot + PNB Law Firm Philo Dellano). Наша система только флагит, не даёт verdict.
- **ADR-005** — Sales Comparison primary, Income/Cost = Phase 2 super-verification.
- **ADR-008** — Diagnostic narrative principle: narrative — отчёт, не marketing. Каждая секция раскрывает intermediate pipeline results для калибровки.
- **ADR-011** — Tenure × Zone strictly multiplicative (не additive). Формула compound в `sales-comparison-logic.md §8`.
- **ADR-013** — Z-score через MAD (robust), не standard deviation. Outlier-proof для помойного ведра.
- **ADR-017** — 9-значный listing_subtype enum (land/villa/rumah/apartment/4×commercial/ambiguous). Villa и rumah — разные рынки, не смешиваем comp-pools.
- **ADR-019** — Calibration type per skill (6 типов). Triangulation только где есть judgment.

---

## Сценарии покупателя MVP

Только 2 — остальные Phase 2+.

1. **`foreign_investor_str_via_pma`** — default. Foreign покупатель через PT PMA, STR на Airbnb/Booking. Pink-zone preferred.
2. **`land_for_development`** — Ilya's core business. Buy land → build villa/complex → sell или operate. Residual Land Value formula.

---

## 27 районов Бали (закрытый gazetteer)

Canggu, Berawa, Pererenan, Umalas, Kerobokan, Seminyak, Legian, Kuta, Sanur, Denpasar, Ubud, Penestanan, Mas, Uluwatu, Jimbaran, Nusa Dua, Pecatu, Bingin, Padang Padang, Tabanan, Cemagi, Seseh, Tanah Lot, Lovina, Amed, Ubuk, Sidemen.

Хранится в `sources._lookup_area_defaults` + `_lookup_bali_gazetteer`. Per-area defaults: zoning, FAR, KDB, social_bucket, subak_risk, parent_district.

---

## Стиль работы с Ilya

- **Русский** для объяснений, **English** для кода
- **Business-like, no fluff** — прямой ответ, главная мысль выделена
- **3-4 шага с подтверждением** — не 30 шагов без контрольных точек
- **Bash-команды всегда с explicit контекстом** где запускать
- **Anti-hallucination** обязателен — flagь estimates vs facts
- **Прогресс-бар по этапам в каждом ответе** для многоэтапных задач
- **Без эмодзи** (кроме явного запроса)
- **Файлы не создаём без разрешения**, output в чат if possible

---

## Cold-start guide для нового AI

1. Прочитай этот файл
2. Прочитай `decisions-log.md` (~10 минут)
3. Прочитай `open-questions.md` (~2 минуты)
4. Если работа конкретно с Evaluator — прочитай `sales-comparison-logic.md v1.1`
5. Если работа с pipeline в целом — прочитай `tool-architecture.md v1.1`
6. Если работа с кодом — смотри `realty-portal/skills/EVL-*/SKILL.md` + `realty-portal/scrapers/rumah123/run.py`
7. Если работа с БД — `docker exec supabase-db psql -U postgres -d postgres -c "\d public.properties"` (73 колонки)

---

## Нерешённое на уровне пользователя

1. **Revoke GitHub PAT** `ghp_REDACTED_COMPROMISED` — был в старом репо, считается скомпрометированным.
2. **Ротация Anthropic API key** — текущий временный, перед продом заменить.
3. **Отправка Алексею** `tool-architecture.md v1.0` + `sales-comparison-logic.md v1.0` на approval (не блокирует Day 1-5, но нужно до продовой деплой).
4. **Регистрация API keys для triangulation** (Day 3): Gemini (free), DeepSeek ($5 free credits), Groq (free).
