# Handoff: parser-rumah123-v2 → parser-rumah123-v3

**Статус:** **FINALIZED** 2026-04-21 ~23:55 WITA (session closing перед Ильиным `mv "Новая папка" C:\work`; re-stamped per librarian-v2 brief).
**От:** parser-rumah123-v2 → parser-rumah123-v3 (активный handoff).
**Предшественник (v2) закрывается:** prepared handoff + inbox close-ACK + обе background процесса автономны на Aeza.
**Canon version при финализации:** 0.3 (last_updated 2026-04-21T20:30+08:00).

---

## 🚨 MUST READ on start — обязательные документы

### Market data references (scope-caveat critical)

1. **`realty-portal/snapshots/market_data/farsight_canggu_2025/README.md`** — CRITICAL SCOPE CAVEAT: FARSight данные применимы **ТОЛЬКО** к узкому premium STR сегменту (villa под управлением PMC). НЕ применять ко всей базе.
2. **`realty-portal/snapshots/market_data/farsight_canggu_2025/extracted_data.json`** — structured цифры (5 BR × 2 года).
3. **`realty-portal/snapshots/market_data/farsight_canggu_2025/farsight_deep_scrape.json`** — 80-page deep scrape farsight24.com с 8 ROI/yield claims из их blog (B25 Villas Complex: 79% occupancy, ROI 20.7%).
4. **Supabase** `public.market_benchmarks` WHERE `source_caveat='narrow_premium_str'` — 10 строк.

Почему MUST READ: Илья явно запретил применять FARSight на всю выборку («FARSight управляет виллами в сегменте выше среднего в short-term rentals — это не ляжет на всю выборку»). Подтверждено в разрыве 79% FARSight-managed occupancy vs 66% market aggregate.

### Canonical read (через launch_manifest + canon_training)

- `docs/school/launch_manifest.json` → секция `roles.parser-rumah123-v3` (полный bootstrap план)
- `docs/school/canon_training.yaml` (version check: 0.3, changelog последние 3 bump)
- `docs/school/handoff/parser-rumah123_v3.md` (этот файл)
- `docs/school/handoff/parser-rumah123_v3.json` (machine-readable state)
- `docs/school/mailbox/outbox_to_parser.md` (A1-A3 approvals + задачи 5-6)
- `docs/school/mailbox/inbox_from_parser.md` — свежий close-ACK блок от v2 (23:50)
- `docs/school/skills/heartbeat-parser.md` — мой A1 draft, ждёт school ревизию 4 вопросов

---

## Current state (2026-04-21 23:50 закрытие v2)

### Closed (не переделывать)

**Approvals Pack #1 (school-v1 outbox, закрыт 17:10 WITA):**
- **A2 LiteLLM fallback removal** — DONE. Код fail-loud (`os.environ[key]` в `normalize_listings.py`, `fetch_details.py`, а также `rumah123/run.py` — пропатчен в 23:10 с `DATABASE_URL` → `REALTY_DB_DSN` после обнаружения bug во время pilot). Wrapper `scripts/run_with_env.sh` + `.env` с `REALTY_DB_DSN="host=172.18.0.13 port=5432 user=postgres password=${POSTGRES_PASSWORD} dbname=postgres"` (expand через `set -a; source`).
- **A3 Sonnet 4.5 + Kimi K2 + fallbacks** — DONE. 10 моделей в LiteLLM, `claude-sonnet-4-5-20250929` работает, `kimi-k2` через Groq rate-limited → fallback на `deepseek-chat` отрабатывает автоматом. `/opt/realty-portal/lightrag/litellm_config.yaml` обновлён.
- **A1 heartbeat redesign DESIGN** — DONE (докум.). `docs/school/skills/heartbeat-parser.md` ~270 строк, 2-layer модель, 4 вопроса к школе. **Ждёт ревизию школы + heartbeat-common.md от librarian-v3 для имплементации.**

**Proactive P1 (17:45 WITA):**
- **seller_type UPSERT fix** — bug был: колонка отсутствовала в INSERT. Fix + smart merge (не даём Haiku затереть `agent→unknown`). Full refresh 310 detail records → seller_type 1/422 → 311/422 (74% coverage).
- **STR/LTR classification** — ALTER TABLE + `rental_suitability` text + `rental_suitability_score` smallint + index. SQL-heuristic backfill + Haiku-extraction (обновлён SYSTEM_PROMPT + UPSERT smart-merge).
- **baselines v3 и v4** в `realty-portal/snapshots/2026-04-21-v3/` и `-v4/`.

**Quick-win Ile (17:45):** `snapshots/2026-04-21-v4/2br_short_term_berawa.csv` — 28 short-term 2BR в зоне.

**Phase 1 Pilot (19:45-23:50):**
- Lamudi scraper `scrapers/lamudi/run.py` — 150 строк, 5 validated slugs. Path `/jual/bali/badung/{slug}/rumah/vila/2-kamar-tidur/`.
- `fetch_details.py` теперь source-aware (SOURCE_CONFIG, `--source-name` arg для rumah123_bali/lamudi_bali).
- `orchestrator.sh` — 7-stage multi-source flow (Stage 1-2 DONE, Stage 3 упал на DATABASE_URL bug в rumah123/run.py, пропатчен, но pilot не продолжил через orchestrator — доделал manually).
- **Lamudi fetch 60/60 OK, 0 blocked, 0 errors** — Lamudi CF-friendly (vs Rumah123 17% stable-block rate в v1).
- Normalize на 52 Lamudi done + 8 ещё крутится автономно в 23:50 closure.

**Market trends (22:00 WITA):**
- FARSight "Statistics of Canggu" PDF сохранён в `snapshots/market_data/farsight_canggu_2025/` (PDF + README + extracted JSON + deep-scrape JSON).
- `public.market_benchmarks` table создана — 10 строк FARSight Canggu 2024+2025, `source_caveat='narrow_premium_str'`.
- 3 места фиксации scope-caveat: README + SQL column + MUST READ в этом handoff.

### Pilot final metrics (23:55, normalize завершился)

```
Total properties:          482 (422 rumah123 + 60 lamudi)
Raw listings:              482 (all processed, 0 pending)
LLM spend cumulative:      $5.44 / 900 Haiku calls (pilot delta vs 22:45 baseline: +54 calls, +$0.33)
Lamudi fetch success:      60/60 OK (100%, 0 CF-blocks vs Rumah123 17% stable-block rate)
Farsight deep scrape:      80 pages visited, 0 PDF/XLS, 8 ROI/yield marketing claims
Rental_suitability dist:   short_term 250 / mixed 110 / long_term 118 / unknown 4
                           — доля short_term выросла с 196/422 (46%) → 250/482 (52%) после Lamudi integration:
                             Lamudi 2-kamar-tidur villa path = почти все STR premium listings
                             (54/60 Lamudi классифицированы short_term — 90%, high confidence)
```

### Open / Blocked

**Ждёт школьной ревизии / approve:**
1. **heartbeat-parser.md draft** — 4 вопроса школе (константы SHORT/BREAK/LONG/CF_COOLDOWN/DISTRACTION; bash-loop vs async; pg-advisory vs flock; notify-приоритет).
2. **Задача 5 tenure_inference_skill** (MED) — LightRAG-powered inference для 39%→15% unknown tenure.
3. **Задача 6 FX rate skill** (LOW) — IDR_PER_USD=16000 hardcoded → daily refresh.
4. **Задача 7 secrets rotation** (я инициировал в inbox) — Postgres pwd + GITHUB_PAT + LITELLM master засветились в plaintext. После эксперимента.

**Waiting on librarian-v3:**
- **`heartbeat-common.md`** skill (общая база для всех ролей) — parser-v3 **не начинает A1 имплементацию до поставки** от librarian. Канон #4 skills_over_agents + #3 simple_nodes: имеет смысл unified heartbeat-common перед parser-specific.

**Waiting on Ильи:**
- Пример «тормоза парсера» (A4 из outbox #1) — OPEN.
- TG push-токен в `.tg_push.env` — для Layer 1 notify.
- Решение по 99.co extraction (Playwright vs API reverse) — blocker для Phase 2 full sweep.
- Approval канонного обновления `canon_training.yaml` для market_data MUST READ (запрошено школой в inbox 22:45).

---

## Blocked_on / Waiting

| Блокер | На что | Разблокирует |
|---|---|---|
| school ревизия heartbeat-parser.md | A1 implementation | school-v2 (после MCP POC green) |
| librarian-v3 heartbeat-common.md | унифицированный heartbeat skill | librarian-v3 P1 (после POC green) |
| MCP Agent Mail Phase 2 rollout | parser-v3 регистрация в MCP | librarian-v3 Phase 1 POC success |
| A4 пример тормоза | calibration heartbeat constants | Илья |
| 99.co extraction решение | Phase 2 full sweep | Илья + Playwright research |
| canon_training.yaml update | MUST READ для market_data формализовать | school-v2 |
| Задача 7 secrets rotation | безопасность long-term | school-v2 approve формат ротации |

---

## Path migration note

**Parser сам не делает sed-replace** — он работает на **Aeza `/opt/realty-portal/`**, paths на сервере не меняются.

**НО** в моих handoff-references и в `realty-portal/snapshots/**` могут быть упоминания `C:\Users\97152\Новая папка` / `C:/work`. librarian-v3 в первом turn **step 4** своего checklist'а выполнит global sed-replace (28 файлов) — это покроет все parser-v3 references.

**После mv Ilya → C:\work**:
- Локальный project root: `C:\work\realty-portal\`
- Aeza project root: `/opt/realty-portal/` (без изменений)
- SSH key path: `C:\Users\97152\.ssh\aeza_ed25519` — **вне project root**, не требует обновления (manifest это подтверждает)

**parser-v3 в first-turn НЕ делает sed-replace** — полагается на librarian-v3 completion.

---

## MCP Agent Mail Phase 2 rollout

Текущий mailbox — файлы в `docs/school/mailbox/` (canon 0.3, `role_invariants.mailbox_transport_model`).

**Phase 1 POC** — librarian-v3 делает после Ilya «старт POC» (manifest: 12 шагов ~65 мин, localhost:8765 + SSH tunnel + bearer). Идёт **без parser**.

**Phase 2 — parser-v3 регистрация в MCP** (после POC T1-T10 green):
1. parser-v3 регистрируется identity в MCP Agent Mail с `agent_id=parser-rumah123-v3`.
2. Переход с file-mailbox → MCP threads для cross-role communication.
3. File-mailbox остаётся archive-only.
4. IU3 multi-model gateway (LiteLLM) — exposed через MCP tool для других ролей (текущий access через direct HTTP остаётся back-compat).

**parser-v3 дожидается школьного signal «Phase 2 rollout start»**, не регистрируется сам.

---

## IU3 multi-model gateway — parser как temporary owner

Canon 0.3 `infrastructure_units.IU3_multi_model_gateway`: parser — **первый consumer, но не owner долгосрочно**. После MCP POC gateway расширяется на shared-access модель для всех ролей.

**Что на parser пока лежит (до shared-access):**
- `/opt/realty-portal/lightrag/litellm_config.yaml` — monolithic config 10 моделей (Haiku / Sonnet 4.5 / Kimi K2 / deepseek / gpt-4o-mini / gemini-flash / groq-llama / qwen-turbo / grok-fast / grok-max).
- `LITELLM_MASTER_KEY` в `/opt/realty-portal/.env` (shared master key для всех консумеров пока).
- `realty_litellm` Docker контейнер.
- Fallbacks YAML rule (groq-llama → deepseek-chat, kimi-k2 → deepseek-chat, qwen-turbo) — validated live.

**Что делает v3 при запросах от других ролей:**
- Если школа/librarian спрашивает триангуляцию — выдать endpoint `http://172.18.0.6:4000/v1/chat/completions` + bearer (через shared access).
- НЕ хардкодить квоты — LiteLLM admin UI это сделает после MCP Phase 2.
- Мониторить `public.llm_usage_log` для биллинга per-consumer (после того как другие роли начнут slept).

**Exit strategy:** когда появится **IU-team** или librarian-v<N> возьмёт IU3 под свой домен — parser отдаёт ownership. Сейчас parser — просто первый hoster.

---

## First-turn checklist для parser-rumah123-v3

После активации v3 (либо сразу после librarian-v3 POC green, либо когда Илья зашлёт новый outbox в `outbox_to_parser.md`):

1. **Read launch_manifest** (секция `roles.parser-rumah123-v3`).
2. **Check canon version**: `head -3 docs/school/canon_training.yaml` → ожидается 0.3 или 0.4 (если POC green уже прошёл). При mismatch с моим `last_read_canon_version=0.3` — re-read full canon.
3. **Check Aeza scrapers alive**:
   ```bash
   ssh root@193.233.128.21 'pgrep -af "night_monitor|2h_reporter" || echo NONE'
   ssh root@193.233.128.21 'docker ps --filter name=realty_litellm --format "{{.Status}}"'
   ssh root@193.233.128.21 'docker exec supabase-db psql -U postgres -d postgres -c "SELECT COUNT(*) FROM public.properties"'
   ```
4. **Read this handoff + .json** (полный state).
5. **Read outbox_to_parser.md** — если есть новый блок после 2026-04-21 17:00 (APPROVAL PACK от school-v1) — обработать. Если нет — ничего.
6. **Read inbox_from_parser.md** — свой close-ACK блок от v2 (23:50).
7. **Read heartbeat-parser.md draft** — быть готовым на school-ревизию 4 вопросов.
8. **Read market_data/farsight_canggu_2025/README.md** — scope-caveat, не нарушать.
9. **Write ACK block в inbox_from_parser.md** (TO_SCHOOL + TO_SUCCESSOR sections) — "parser-v3 started, canon 0.X read, waiting school ACK / heartbeat-common.md / POC Phase 2 signal".
10. **Stay в waiting mode** до explicit signal от школы (Phase 2 start / heartbeat-common.md delivered / новый outbox).

### Что парсер-v3 делает СРАЗУ без waiting

- Мониторинг Aeza background: `night_monitor.sh` и `2h_reporter.sh` живы — они автономны, но parser-v3 владелец.
- Проверка `public.market_benchmarks` — 10 строк на месте (сверка `COUNT(*)=10`).
- Проверка Supabase properties count ≥ 474 (474 или больше, если normalize finishing докатил последние 8).

### Что парсер-v3 НЕ делает в first-turn

- НЕ запускает scraper runs.
- НЕ пересчитывает yield / implied_rent / cross-segment analytics.
- НЕ трогает /opt/tg-export/** (librarian domain).
- НЕ ротирует ключи / не трогает .env.
- НЕ регистрируется в MCP сам — ждёт signal от школы.
- НЕ имплементирует A1 heartbeat до heartbeat-common.md от librarian.

---

## Do NOT do (специфично после v2)

- Не применять FARSight ADR/occupancy **ко всей базе** — только к premium STR subset (`rental_suitability='short_term' AND price_idr > quartile_75_per_area`). Без approve Ильи даже subset не применять.
- Не пересчитывать `implied_yield` на 474 без subset-фильтра.
- Не запускать новый массовый scrape Rumah123 до heartbeat imp — human-rhythm фиксированный sleep, риск CF-блока.
- **НЕ покупать AirDNA** без явного approve Ильи. FARSight + наш scrape + Inside Airbnb dump (ещё не проверен) покрывают MVP.
- Не ротировать LITELLM_MASTER_KEY / Postgres pwd без Задачи 7 approve.
- Не убивать `night_monitor.sh` / `2h_reporter.sh` на Aeza.
- Не трогать `realty_litellm` container без согласования с другими ролями (IU3 shared).

---

## Технические routes (актуально на момент v3 start)

```
SSH:                 root@193.233.128.21 via C:\work\.ssh\aeza_ed25519 (после mv) или C:\Users\97152\.ssh\aeza_ed25519 (SSH key вне project root — manifest отмечает НЕ mvt)
Postgres (host):     172.18.0.13:5432 user=postgres  (pass в /opt/realty-portal/.env POSTGRES_PASSWORD)
LiteLLM (host):      http://172.18.0.6:4000 + Bearer $LITELLM_MASTER_KEY
LiteLLM admin UI:    http://172.18.0.6:4000/ui (пароль не проверялся, default admin/<master_key>)
Docker-net alias:    http://realty_litellm:4000
Supabase-db exec:    docker exec supabase-db psql -U postgres -d postgres
Project root (Aeza): /opt/realty-portal/
Project root (local, после mv): C:\work\realty-portal\
Logs (Aeza):         /var/log/realty/{heartbeat.log, 2h_reports.log}
                     /tmp/{refresh_v4.log, lamudi_remainder.log, orchestrator_pilot.log, farsight_deep.log}
Recovery playbook:   /opt/realty-portal/RECOVERY.md
.env backups:        /opt/realty-portal/.env.bak.{1776665607, 20260421-1757, 20260421-a2fix}
```

### Credentials map

- `REALTY_DB_DSN` (Postgres DSN для host-Python) — в `.env`, через `${POSTGRES_PASSWORD}` expand
- `LITELLM_MASTER_KEY` — в `.env` (единственный источник, никаких fallback в коде после A2)
- `ANTHROPIC_API_KEY` — в `.env` (для Sonnet 4.5 + Haiku через LiteLLM)
- `GROQ_API_KEY` — в `.env` (Kimi K2 + Llama)
- `DASHSCOPE_API_KEY` — в `.env` (Qwen)
- `XAI_API_KEY` — в `.env` (Grok)
- `OPENAI_API_KEY` — в `.env` (gpt-4o-mini)
- `GEMINI_API_KEY` — в `.env` (Gemini Flash)
- `DEEPSEEK_API_KEY` — в `.env` (DeepSeek V3)

**Известно засвеченные в plaintext (Задача 7 pending):**
- Postgres password `J6iK0lEa7xBNedh1fPyGOasd_2yGieiW` был в коде до A2 patch. В .env.bak.* на Aeza.
- `GITHUB_PAT` в `.env` (засветился в моём stdout при grep tail команде в A2).

---

## TO_SUCCESSOR queue (P-ordered)

**P0 — сразу после school signal:**
- Ревизия school 4 вопросов по heartbeat-parser.md → approve-decide implementation parameters.
- Получение heartbeat-common.md от librarian-v3 → использовать как база для heartbeat-parser impl.

**P1 — после P0 closure:**
- Heartbeat implementation (A1 full) — ~4-6 ч по дизайну. 3 worker loops + Layer 1 watchdog + `_status.json` + singleton pg-advisory-lock.
- Retry CF-blocked 70 URLs в raw_listings (после heartbeat ready).

**P2 — после heartbeat ready:**
- Задача 5 tenure_inference_skill (LightRAG-powered): 4 часа дизайн + impl.
- Phase 2 Lamudi full sweep (остальные 408 2BR villa).
- 99.co integration (после решения Ильи по Playwright vs API).

**P3 — backlog:**
- Задача 6 FX rate skill (2 ч).
- Задача 7 secrets rotation (1-2 ч, нужен approval формата).
- Singleton lock на fetch_details (20 мин).
- LiteLLM `fallbacks:` расширение (10 мин).
- Quarterly refresh FARSight PDF request к Ilya.

---

## Context budget v3

Старт v3 (после read manifest + canon 0.3 + handoff_v3 + outbox + inbox + heartbeat-parser + market_data/README + launch_manifest) — оцениваю в **35-40%** контекста на момент первого turn'a.

До handoff v4 запас ~**30-35%**. При POC Phase 2 rollout + Phase 2 sweep — v4 вероятно потребуется.

---

## HANDOFF_NEEDED флаг

На момент финализации: **TRUE** (v2 закрывается по directive Ильи перед `mv "Новая папка" C:\work`).

**Session-close reason:** Ilya mv operation, нужен clean state перед переездом path.

---

## Related files (reference, не re-read каждый turn)

- `realty-portal/scripts/orchestrator.sh` — 7-stage pipeline
- `realty-portal/scripts/run_with_env.sh` — canonical env-wrapper (canon #6)
- `realty-portal/scrapers/lamudi/run.py` — Lamudi scraper (60/60 validated CF-friendly)
- `realty-portal/scrapers/rumah123/{run.py, fetch_details.py}` — после A2 fallback removal + source-aware
- `realty-portal/scripts/normalize_listings.py` — Haiku normalizer с rental_suitability + seller_type smart-merge
- `realty-portal/snapshots/2026-04-21-v4/2br_short_term_berawa.csv` — последний hand-deliverable Ilya
- `realty-portal/snapshots/market_data/farsight_canggu_2025/*` — 4 файла (PDF + README + 2 JSON)

---

**Conclusion**: v2 закрывается чисто. Все ключевые закрытия (A1/A2/A3/STR-LTR/pilot/market_data) документированы. v3 стартует с полным state + MUST READ секциями + 3 waiting-блокерами (school ревизия, librarian skill, MCP Phase 2). 2 background процесса на Aeza автономны (night_monitor + 2h_reporter + ещё normalize доедает последние 8 Lamudi).

---

## amendments (2026-04-22 17:55) — Session closeout parser-rumah123-v3

**MCP bootstrap completed** (2026-04-22, canon v0.4 launcher_mcp_bootstrap):

```
agent_id:           parser-rumah123-v3 (MCP id=7)
registration_token: P69OgMh8v1C1RPxHIxX84AAcCWqvxZM-f9lyiAPf1Qo
project_key:        /opt/realty-portal/docs/school (id=1)
contacts:
  ↔ school-v3     approved (expires 2026-05-22)
  → librarian-v3  pending → welcome received (auto-delivery works)
msgs_sent:   [PARSER-V3 ONLINE] id=22, [PRESENCE] id=23, [ACK]×2 id=34,35
msgs_read:   [WELCOME] id=24 (school-v3), [WELCOME-FROM-LIBRARIAN] id=25 (librarian-v3)
```

**Mesh state**: 4-way complete (librarian-v3, school-v3, parser-rumah123-v3, ai-helper-v2). Contacts approved bidirectionally (AP-7 FINDING — default contact_policy='open').

**Cross-session memory dump** (hybrid-memory vault, separate FS от Windows):
- Backup: `backup-20260422-095137-realty-portal-mesh-complete-20260422.md` (15 KB)
- Digest: `memory-digest-20260422-095142.md` (17 KB, 294 lines)
- Compact: `memory-compact-20260422-095142.md` (11 KB)
- Git: commit `4a7051b` на branch `claude/parser-v3-launcher-bootstrap-DKNwr`
- Contains: 6 realty-portal findings (AP-7 open policy, Tailscale decision, SSH heredoc lesson, Custom API bypass, mark_read bug, mesh context)

**TO_SUCCESSOR blocked_on**:
- `[P0]` heartbeat-common.md от librarian-v3 (watch: `librarian-to-parser` thread)
- `[P0]` heartbeat-parser 4-question review от school-v3 (watch: `school-to-parser` thread)
- `[P1]` A1 heartbeat impl после P0 closure (~4-6h per `skills/heartbeat-parser.md`)
- `[P1]` CF-blocked 70 URLs retry в raw_listings
- `[P2]` Phase 2 Lamudi full sweep (408 remaining 2BR villa)
- `[P3]` Задачи 5/6/7 (tenure_inference, FX rate, secrets rotation)
