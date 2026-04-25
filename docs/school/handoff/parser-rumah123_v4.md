# Handoff: parser-rumah123-v3 → parser-rumah123-v4

**Статус:** **FINALIZED** 2026-04-22 14:35 WITA (organized exit, NOT emergency).
**От:** parser-rumah123-v3 → parser-rumah123-v4 (активный handoff).
**Trigger:** MCP client registration timing finding — school-v2 поймала ту же проблему в 14:30. Claude Code MCP client инициализируется однократно при старте сессии, tunnel up после старта не подхватывается без `/mcp reconnect`. Канонический путь для разблокировки = handoff к свежей сессии у которой tunnel уже up на момент open.
**Canon version при финализации:** 0.4 (last_updated 2026-04-22T12:30+08:00).
**Predecessor (v3) closed clean:** ACK + exit_closure + handoff_v4 написаны. v3 не успел сделать MCP register/contact/send из-за timing bug, но всё carry-over в v4.

---

## 🚨 MUST READ on start — обязательные документы

### Market data references (scope-caveat critical) — без изменений с v3

1. **`realty-portal/snapshots/market_data/farsight_canggu_2025/README.md`** — CRITICAL SCOPE CAVEAT: FARSight данные применимы **ТОЛЬКО** к узкому premium STR сегменту (villa под управлением PMC). НЕ применять ко всей базе.
2. **`realty-portal/snapshots/market_data/farsight_canggu_2025/extracted_data.json`** — structured цифры (5 BR × 2 года).
3. **`realty-portal/snapshots/market_data/farsight_canggu_2025/farsight_deep_scrape.json`** — 80-page deep scrape farsight24.com с 8 ROI/yield claims.
4. **Supabase** `public.market_benchmarks` WHERE `source_caveat='narrow_premium_str'` — 10 строк.

### Canonical read (через launch_manifest + canon_training)

- `docs/school/launch_manifest.json` → секция `roles_to_launch.parser-rumah123-v3` (план bootstrap, актуален и для v4)
- `docs/school/canon_training.yaml` (version check: **0.4**, changelog последние 3 bump). NEW в 0.4: `mcp_api_usage` (gotchas из POC), `launcher_mcp_bootstrap`, `mcp_session_start_sequence`, `canon_version_check_on_turn_start`, `role_inbox_exit_closure`, `project_key_convention` и др.
- `docs/school/handoff/parser-rumah123_v4.md` (этот файл)
- `docs/school/handoff/parser-rumah123_v3.md` (контекст предыдущей попытки bootstrap)
- `docs/school/mailbox/outbox_to_parser.md` (директивы school)
- `docs/school/mailbox/inbox_from_parser.md` — свежий exit-блок v3 (14:35) + start-ACK v3 (12:45)
- `docs/school/skills/heartbeat-parser.md` — A1 draft v0.1, ждёт school ревизию 4 вопросов (carry-over с v2)
- `docs/school/canon_backlog.md` (если существует) — там school-v2 14:30 finding по MCP timing

---

## Current state (2026-04-22 14:35 — v3 закрытие)

### Что v3 НЕ успел сделать из-за MCP tools timing bug

**MCP bootstrap (launcher_mcp_bootstrap из canon v0.4) — все 4 шага НЕ выполнены:**

1. ❌ `ensure_project(human_key='/opt/realty-portal/docs/school')` — не вызван (MCP tool не загружен)
2. ❌ `register_agent(program='claude-code', model='claude-sonnet-4-6', name='parser-rumah123-v3')` — не вызван
3. ❌ `request_contact(to='librarian-v3')` + `request_contact(to='school-v2')` — не вызваны
4. ❌ `mcp_session_start_sequence` 4 шага (presence_ping / fetch_inbox / mark_read loop / send_message) — не выполнены
5. ❌ `send_message(to='school-v2', thread_id='parser-v3-to-school', subject='[PARSER-V3 ONLINE]', ...)` — не отправлен через MCP (только файловый ACK в inbox)

**Root cause:** SSH tunnel localhost:8765 поднят Ильёй ПОСЛЕ старта parser-v3 сессии. Claude Code MCP client инициализирует список deferred tools однократно при старте — `/mcp reconnect` нужен для пере-инициализации, но это user-side команда. Сессия v3 жила без MCP tools весь lifetime.

**Mitigation для v4:** при старте новой сессии tunnel уже должен быть up → MCP client подхватит `mcp-agent-mail` сервер и tools появятся в deferred list автоматически с первого turn'а.

### Closed (carry-over, не переделывать)

**Approvals Pack #1 (school-v1 outbox 17:10) — все DONE:**
- **A2 LiteLLM fallback removal** — DONE. Fail-loud `os.environ[key]` в `normalize_listings.py`, `fetch_details.py`, `rumah123/run.py`. Wrapper `scripts/run_with_env.sh` + `.env` с `REALTY_DB_DSN`.
- **A3 Sonnet 4.5 + Kimi K2 + 10 моделей** — DONE. `/opt/realty-portal/lightrag/litellm_config.yaml`, fallbacks validated live (groq-llama → deepseek, kimi-k2 → deepseek).
- **A1 heartbeat redesign DESIGN** — DONE (`docs/school/skills/heartbeat-parser.md` v0.1, ~270 строк, 2-layer модель, 4 вопроса school). Ждёт ревизию + heartbeat-common.md от librarian-v3 для имплементации.

**Proactive P1 (17:45 WITA) — DONE:**
- seller_type UPSERT fix → 311/422 coverage (74%).
- STR/LTR classification: ALTER TABLE + `rental_suitability` text + score smallint + index.
- Baselines v3, v4 в `realty-portal/snapshots/`.

**Phase 1 Pilot (19:45-23:50) — CLOSED clean v2:**
- Lamudi scraper `scrapers/lamudi/run.py` — 60/60 fetch OK (CF-friendly, vs Rumah123 17% block).
- Multi-source orchestrator `orchestrator.sh` — 7-stage flow, source-aware fetch_details.
- Final metrics: **482 properties** (422 rumah + 60 lamudi), 66 short-term 2BR Berawa, 44 broker phone clusters, $5.44 LLM spend cumulative.

**Market trends (22:00 WITA) — DONE:**
- FARSight "Statistics of Canggu" PDF в `snapshots/market_data/farsight_canggu_2025/`.
- `public.market_benchmarks` table — 10 строк, `source_caveat='narrow_premium_str'`.

### Open / Blocked (carry-over для v4)

**Ждёт школьной ревизии / approve:**
1. `heartbeat-parser.md` 4 вопроса (SHORT/BREAK/LONG/CF_COOLDOWN constants; bash-loop vs async; pg-advisory vs flock; notify priority).
2. Задача 5 `tenure_inference_skill` (MED) — LightRAG-powered для 39%→15% unknown tenure.
3. Задача 6 FX rate skill (LOW) — IDR_PER_USD=16000 hardcoded → daily refresh.
4. Задача 7 secrets rotation (Postgres pwd + GITHUB_PAT + LITELLM master в .env.bak.* засветились в plaintext).

**Waiting on librarian-v3:**
- `heartbeat-common.md` skill — общая база для всех ролей. parser **не начинает A1 имплементацию до поставки** (канон #4 skills_over_agents + #3 simple_nodes).

**Waiting on Ильи:**
- Пример «тормоза парсера» (A4 outbox #1) — OPEN.
- TG push-токен `.tg_push.env` — для Layer 1 notify.
- 99.co extraction (Playwright vs API reverse) — blocker для Phase 2 full sweep.

---

## First-turn checklist для parser-rumah123-v4

**При старте v4 (tunnel up уже на момент open сессии):**

1. **Verify MCP tools available:** проверить что `mcp__mcp_agent_mail__*` (или подобное имя) видно в deferred tools list. Если НЕТ — спросить Илью `/mcp` reconnect (та же проблема что у v3 — рано стартовали).
2. **Read launch_manifest** (секция `roles_to_launch.parser-rumah123-v3` — для v4 актуальна, переименовать identity в register_agent).
3. **Check canon version**: `head -3 docs/school/canon_training.yaml` → ожидается **0.4** (или выше если school успела bump). При mismatch с `last_read_canon_version=0.4` — re-read full canon.
4. **Check Aeza scrapers alive:**
   ```bash
   ssh root@193.233.128.21 'pgrep -af "night_monitor|2h_reporter" || echo NONE'
   ssh root@193.233.128.21 'docker ps --filter name=realty_litellm --format "{{.Status}}"'
   ssh root@193.233.128.21 'docker exec supabase-db psql -U postgres -d postgres -c "SELECT COUNT(*) FROM public.properties"'
   ```
5. **Read this handoff (v4) + handoff_v3 + parser_v3.json** — полный state.
6. **Read outbox_to_parser.md** — новые блоки после 14:35 14.04.2026.
7. **Read inbox_from_parser.md** — exit-блок v3 (14:35) + start-ACK v3 (12:45).
8. **Read heartbeat-parser.md draft** — быть готовым на school-ревизию 4 вопросов.
9. **Read canon_backlog.md (если есть)** — school-v2 finding 14:30 по MCP timing.
10. **MCP bootstrap (launcher_mcp_bootstrap из canon v0.4):**
    ```
    ensure_project(human_key='/opt/realty-portal/docs/school')
    register_agent(program='claude-code', model='claude-sonnet-4-6', name='parser-rumah123-v4')
    request_contact(to='librarian-v3')
    request_contact(to='school-v2')
    # mcp_session_start_sequence:
    send_message(to=['school-v2'], subject='[PRESENCE]', thread_id='presence', importance='low', ack_required=false)
    msgs = fetch_inbox(agent_name='parser-rumah123-v4', limit=50)
    # for each msg in msgs['structuredContent']['result']: mark_message_read(message_id=m['id'])
    send_message(to='school-v2', thread_id='parser-v4-to-school', subject='[PARSER-V4 ONLINE]', body='parser-v4 bootstrapped via MCP, canon v0.4 read, contacts requested, ready for directives', ack_required=false)
    ```
11. **Write ACK в inbox_from_parser.md** с фактическим `agent_id` (полученным от register_agent), `last_read_canon_version=0.4`, `contacts_requested=[school-v2, librarian-v3]`, `current_state` carry-over из этого handoff.
12. **Stay в waiting** до signal: school-v2 directive / heartbeat-common.md от librarian / новый outbox / Ilya «старт».

### Что v4 делает СРАЗУ без waiting

- Мониторинг Aeza background: `night_monitor.sh`, `2h_reporter.sh` живы (автономны, parser owner).
- Проверка `public.market_benchmarks COUNT(*)=10`.
- Проверка Supabase properties count ≥ 482.

### Что v4 НЕ делает в first-turn

- НЕ запускает scraper runs.
- НЕ пересчитывает yield / implied_rent / cross-segment analytics.
- НЕ трогает /opt/tg-export/** (librarian domain).
- НЕ ротирует ключи / не трогает .env.
- НЕ имплементирует A1 heartbeat до heartbeat-common.md от librarian.

---

## MCP Agent Mail Phase 2 rollout — теперь активен для v4

Tunnel up на момент v4 start → Phase 2 рассчитывается **выполненным** для parser-v4 (vs v3 которая не дошла до register).

**Что v4 делает:**
1. register_agent (см. checklist шаг 10).
2. Переход с file-mailbox → MCP threads для cross-role communication.
3. File-mailbox остаётся archive-only (canon v0.4 `mailbox_transport_model` actualized).
4. IU3 multi-model gateway (LiteLLM) — exposed через MCP tool для других ролей (LATER, не в first-turn).

---

## IU3 multi-model gateway — parser temporary owner (carry-over с v3)

Canon 0.4 `infrastructure_units.IU3_multi_model_gateway`: parser — **первый consumer, не owner долгосрочно**.

**Что на parser лежит (до shared-access):**
- `/opt/realty-portal/lightrag/litellm_config.yaml` — 10 моделей.
- `LITELLM_MASTER_KEY` в `/opt/realty-portal/.env` (shared master key).
- `realty_litellm` Docker контейнер.
- Fallbacks YAML rule validated live.

**Exit strategy:** когда появится IU-team или librarian-v<N> возьмёт IU3 — parser отдаёт ownership.

---

## Path migration note

**Parser сам не делает sed-replace** — работает на Aeza `/opt/realty-portal/`, paths сервера не меняются.

**После Ilya mv → C:\work**:
- Локальный project root: `C:\work\realty-portal\` (актуален с v3 start)
- Aeza project root: `/opt/realty-portal/` (без изменений)
- SSH key: `C:\Users\97152\.ssh\aeza_ed25519` (вне project root, без изменений)

---

## Do NOT do (специфично после v3, без изменений)

- Не применять FARSight ADR/occupancy ко всей базе (только premium STR subset).
- Не пересчитывать `implied_yield` на 482 без subset-фильтра.
- Не запускать новый массовый scrape Rumah123 до heartbeat imp.
- НЕ покупать AirDNA без явного approve Ильи.
- Не ротировать LITELLM_MASTER_KEY / Postgres pwd без Задачи 7 approve.
- Не убивать `night_monitor.sh` / `2h_reporter.sh` на Aeza.
- Не трогать `realty_litellm` container без согласования с другими ролями.

---

## Технические routes (актуально на момент v4 start)

```
SSH:                 root@193.233.128.21 via C:\Users\97152\.ssh\aeza_ed25519
SSH tunnel MCP:      ssh -L 8765:127.0.0.1:8765 root@193.233.128.21 (УЖЕ UP при v4 start)
MCP Agent Mail:      http://localhost:8765/api/ + Bearer ${MCP_AGENT_MAIL_BEARER}
MCP project_key:     /opt/realty-portal/docs/school (Linux-absolute, NEW-1 mitigation)
Postgres (host):     172.18.0.13:5432 user=postgres
LiteLLM (host):      http://172.18.0.6:4000 + Bearer ${LITELLM_MASTER_KEY}
LiteLLM admin UI:    http://172.18.0.6:4000/ui
Docker-net alias:    http://realty_litellm:4000
Supabase-db exec:    docker exec supabase-db psql -U postgres -d postgres
Project root (Aeza): /opt/realty-portal/
Project root (local):C:\work\realty-portal\
Logs (Aeza):         /var/log/realty/{heartbeat.log, 2h_reports.log}
                     /tmp/{refresh_v4.log, lamudi_remainder.log, orchestrator_pilot.log, farsight_deep.log}
Recovery playbook:   /opt/realty-portal/RECOVERY.md
.env backups:        /opt/realty-portal/.env.bak.{1776665607, 20260421-1757, 20260421-a2fix}
```

### Credentials map (без изменений с v3)

- `REALTY_DB_DSN` — в `.env`, через `${POSTGRES_PASSWORD}` expand
- `LITELLM_MASTER_KEY` — в `.env` (единственный источник)
- `ANTHROPIC_API_KEY`, `GROQ_API_KEY`, `DASHSCOPE_API_KEY`, `XAI_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `DEEPSEEK_API_KEY` — в `.env`
- `MCP_AGENT_MAIL_BEARER` — в `.env` (для MCP client auth)

**Известно засвеченные в plaintext (Задача 7 pending):**
- Postgres pwd `J6iK0lEa7xBNedh1fPyGOasd_2yGieiW` (был в коде до A2, в .env.bak.* на Aeza)
- `GITHUB_PAT` (в `.env`, засветился при grep tail в A2)

---

## TO_SUCCESSOR queue parser-v4 (P-ordered)

**P0 — first turn:**
- MCP bootstrap (см. first-turn checklist шаг 10) — register / contacts / presence / fetch / send `[PARSER-V4 ONLINE]`.
- ACK в inbox_from_parser.md с фактическим agent_id.
- Verify Aeza background loops alive.

**P1 — после P0 closure (signal от school):**
- Ревизия school 4 вопросов по `heartbeat-parser.md` → approve implementation parameters.
- Получение `heartbeat-common.md` от librarian-v3 → база для heartbeat-parser impl.

**P2 — после P1:**
- Heartbeat implementation (A1 full) — 4-6 ч (heartbeat.sh + 3 worker loops + Layer 1 watchdog + `_status.json` + singleton pg-advisory-lock).
- Retry CF-blocked 70 URLs в raw_listings.

**P3 — после heartbeat ready:**
- Задача 5 `tenure_inference_skill` (LightRAG-powered): 4 ч дизайн + impl.
- Phase 2 Lamudi full sweep (остальные ~408 2BR villa).
- 99.co integration (после решения Ильи Playwright vs API).

**P4 — backlog:**
- Задача 6 FX rate skill (2 ч).
- Задача 7 secrets rotation (1-2 ч).
- Singleton lock на fetch_details (20 мин).
- LiteLLM `fallbacks:` расширение (10 мин).
- Quarterly refresh FARSight PDF.

---

## Context budget v4

Старт v4 (после read manifest + canon 0.4 + handoff_v4 + handoff_v3 + outbox + inbox + heartbeat-parser + canon_backlog + market_data/README + MCP bootstrap) — оцениваю в **40-45%** контекста на момент первого turn'a (выше v3 из-за чтения handoff_v3 + canon_backlog для контекста MCP timing finding).

До handoff v5 запас ~**25-30%**. При Phase 2 Lamudi full sweep (~408 URL) + heartbeat impl — v5 вероятно потребуется.

---

## HANDOFF_NEEDED флаг

На момент финализации v3 → v4: **TRUE** (organized exit, не emergency).

**Session-close reason:** MCP client registration timing bug — tunnel up после старта v3 сессии не подхватился без `/mcp reconnect`. Канонический разблок = свежая сессия v4 у которой tunnel up на момент open.

---

## Related files (reference, не re-read каждый turn)

- `realty-portal/scripts/orchestrator.sh` — 7-stage pipeline
- `realty-portal/scripts/run_with_env.sh` — canonical env-wrapper (canon #6)
- `realty-portal/scrapers/lamudi/run.py` — Lamudi scraper (60/60 validated CF-friendly)
- `realty-portal/scrapers/rumah123/{run.py, fetch_details.py}` — после A2 fallback removal + source-aware
- `realty-portal/scripts/normalize_listings.py` — Haiku normalizer с rental_suitability + seller_type smart-merge
- `realty-portal/snapshots/2026-04-21-v5/2br_short_term_berawa_v5.csv` — последний hand-deliverable Ilya (66 records)
- `realty-portal/snapshots/market_data/farsight_canggu_2025/*` — 4 файла (PDF + README + 2 JSON)

---

**Conclusion**: v3 закрывается чисто organized exit. MCP bootstrap не выполнен из-за client timing bug (tunnel up после старта сессии). Все file-based операции (canon read, handoff read, inbox ACK, exit_closure) выполнены. v4 стартует с tunnel уже up → MCP tools появятся в deferred list автоматически → bootstrap пройдёт штатно. Carry-over: A1 design ready, A2/A3 done, pilot 482 закрыт, 2 background loops Aeza автономны.
