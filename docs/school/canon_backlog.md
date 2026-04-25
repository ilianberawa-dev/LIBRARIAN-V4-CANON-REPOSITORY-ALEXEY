# canon_backlog.md

**Назначение:** сырой pipeline для canon bumps. Sunday-hygiene документ, пересматривается при каждом bump'е.

Formate блока: `## YYYY-MM-DD HH:MM — [FINDING | PROPOSAL | RFC] <короткий title>` + секции Impact / Mitigation / Priority / Canon implication.

Жизненный цикл: finding → обсуждение школой → (опционально consensus_workshop turn) → accept в `canon_training.yaml` с bump.

---

## 2026-04-23 ~18:30 — [COMPLETED] heartbeat-common.md v1.0 — P0 blocker resolved

**Mission:** M2 task from librarian-v4 launcher — write generalized heartbeat skill to unblock parser-v4 + ai-helper-v3.

**Deliverable:** `docs/school/skills/heartbeat-common.md` v1.0 (15 KB, ~570 lines)

**Status:** ✅ **COMPLETED** (2026-04-23 18:28)

**What it does:**
- Unifies Layer 1 (infra watchdog) + Layer 2 (human-rhythm) pattern from librarian production (`/opt/tg-export/heartbeat.sh`)
- Answers 4 open questions from `heartbeat-parser.md` v0.1 DESIGN:
  1. Constants revision protocol (role owns, school reviews for canon compliance)
  2. Layer 2 implementation choice (bash-loop around single-shot Python, canon #3 simple nodes)
  3. Singleton-lock approach (pg advisory if DB-connected, flock if filesystem-only)
  4. Notify priority (file-based first via `_status.json`, TG push Phase 2 when approved)
- Provides reference bash implementation (generalized from librarian SHA256 38c1b30a...)
- Integration contract for all roles (expected-duration logging, manifest.json, singleton detection)
- Role-specific constants examples (librarian vs parser vs ai-helper pacing)

**Unblocks:**
- **parser-v4:** Can now implement `scripts/heartbeat.sh` for 3 workers (scrape / fetch / normalize), roll out human-rhythm pacing to reduce CF block rate 17% → ~5%
- **ai-helper-v3:** Can implement heartbeat for LLM batch jobs with API rate-limit backoff (429 → fallback provider chain)
- **Future roles:** secretary, linkedin-writer adopt same pattern (no reinventing watchdog for each)

**Canon implication:**
- Canonical skill (id: `heartbeat-common`, version: v1.0, status: ACTIVE)
- No canon_training.yaml bump needed — skill is additive, doesn't change existing invariants
- If roles adopt successfully over 2-4 weeks → school may extract best-practice invariants into canon v0.5 (e.g. `role_invariants.heartbeat_protocol_required_for_longrun_workers`)

**Monetization chain:**
- Parser: +50 properties per run (CF blocks down) → $10-50k commission per closed deal OR $199-499/mo SaaS retention
- AI-helper: prevent wasted API retries → $50-200/mo cost savings
- Secretary: 24/7 uptime → no missed leads ($500-5000 lost opportunity per gap)

**Next steps:**
1. parser-v4 reads `heartbeat-common.md` → implements for 3 workers → 3-day test run → reports results to school
2. ai-helper-v3 reads `heartbeat-common.md` → implements for batch LLM jobs → Claude/OpenAI/Grok fallback chain
3. After 2-4 week validation period, school decides: extract pattern into canon v0.5 OR keep as skill-level guidance

**Related artifacts:**
- `docs/school/skills/heartbeat-librarian-reference.sh` (7 KB) — frozen snapshot of librarian production heartbeat
- `docs/school/skills/heartbeat-parser.md` v0.1 DESIGN (16 KB) — parser-specific draft that informed common layer
- `vault/shared/knowledge/dumps/librarian-v4-archive-map.md` — M1 deliverable (IT-archive inventory, 120 MB across Windows + Aeza)

---

## 2026-04-22 ~18:00 — [CANON V0.5 CANDIDATES] Architecture — from 2026-04-22 scale-up decision

**Source:** Ilya approved scale-up architecture 2026-04-22. Full design: `hybrid-memory vault/shared/decisions/2026-04-22-scale-up-architecture.md` (git commit `018c95c`, branch `claude/parser-v3-launcher-bootstrap-DKNwr`). 4-stage rollout: (0) FancyZones visual сейчас → (1) autolauncher + WT tabs + Tailscale next session → (2) auto-rotation + canon v0.5 + dashboard → (3) role groups + batch ops.

### rotation_protocol

**Canon v0.5 новый role_invariant.** Когда context UI > 80% → роль пишет exit_closure в свой inbox → autolauncher реанимирует successor через launcher reading handoff + MCP fetch_inbox(since=last_ack). Successor стартует с last known state без gap.

**Key rules:**
- Trigger: context > 80% (not 50% как текущий handoff_trigger — у нас теперь autolauncher, ручной триггер уходит)
- exit_closure format: existing canon v0.4 `role_inbox_exit_closure` + поле `last_mcp_msg_id` для точного MCP resume
- successor init: `fetch_inbox(agent_name=<role>, since_ts=last_ack_ts, limit=50)` → обрабатывает только новые msgs

### launcher_mcp_bootstrap_v2

**Обновление существующего `launcher_mcp_bootstrap` (canon v0.4).** Два новых обязательных шага:

1. **Step 0 — preflight MCP check** (ДО чтения любых файлов): проверить что MCP tools подключены через `/mcp` или `ToolSearch`. Если tools недоступны → STOP, сообщить Илье, не читать файлы (экономия контекста). Fail-loud на входе.
2. **Step: Remove-Item Env:ANTHROPIC_API_KEY** перед запуском `claude` в `claude-session.ps1`. Причина: переменная из одного PowerShell окна может просочиться в другое через profile → неожиданный billing routing между ролями на ILIAN's Individual Org.

**Порядок в launcher после правки:**
0. preflight_mcp_probe (fail-loud)
0a. SSH tunnel / Tailscale check (existing FINDING 14:00)
1. Remove-Item Env:ANTHROPIC_API_KEY
2. ensure_project → register_agent → request_contact → presence (existing)
3. set_contact_policy (для sensitive ролей — AP-7 fix)

### AP-6 fix — MCP client silent degradation detection

**Обновление AP-6** (уже в backlog): добавить detection механизм внутри сессии. После старта агент вызывает `health_check` как первый MCP tool call. Если ошибка → логирует `[MCP_DEGRADED]` в inbox_from_<role>.md и переходит в file-only mode (читает mailbox/*.md напрямую). Не молчит.

**Отличие от launcher probe:** probe снаружи (до `claude`), detection изнутри (первый turn агента). Оба уровня нужны.

### AP-7 fix — explicit set_contact_policy для sensitive ролей

**Обновление AP-7** (уже в backlog): конкретная реализация. В launcher sensitive роли (secretary, linkedin-writer, client-facing) после `register_agent` обязательно:
```
set_contact_policy(policy='restricted', allowlist=['school-vN', 'ilya-overseer'])
```
`restricted` = только из allowlist. Не `contacts_only` (требует ручного respond_contact) — `restricted` + allowlist = автоматически принимает только доверенных.

**Verification step в launcher:** после set_contact_policy → вызвать `whois(<role>)`, проверить что `contact_policy` ≠ `open`. Fail-loud если open.

### orchestrator_protocol

**Новый role_invariant.** Как autolauncher общается с агентами в 20-agent mesh:

- **ACK files:** autolauncher пишет `docs/school/mailbox/launcher_ack_<role>.md` при каждом запуске роли. Агент читает при старте — подтверждает что запущен корректной версией launcher'а.
- **Status log format:** `docs/school/mailbox/status_log.md` — rolling 50-entry лог: `YYYY-MM-DD HH:MM | <role> | <event> | <context%> | <last_msg_id>`. Autolauncher и роли пишут сюда. Илья видит одним взглядом.
- **Watcher context monitoring contract:** watcher.ps1 мониторит UI context % (via Claude Code API или screen parse). При > 80% → пишет в `status_log.md` + шлёт MCP `send_message(to=<role>, subject='[CONTEXT WARNING 80%]', importance='high')`. Роль обязана ответить exit_closure в течение следующего turn'а.
- **Координация school↔autolauncher:** school = observer + approver. autolauncher не запускает новые роли без MCP ACK от school (или ilya-overseer bypass).

---

## 2026-04-22 ~17:40 — [DECISION CANDIDATE] Tailscale migration (pending Ilya approval)

**Предложение:** заменить SSH tunnel + autossh + env-pull цепочку на Tailscale mesh VPN.

**Что снимает одним шагом:**
- FINDING 14:00 (SSH tunnel prerequisite) — tunnel больше не нужен
- FINDING 14:30 (MCP client registration timing) — MCP endpoint всегда доступен через Tailscale IP
- autossh / Task Scheduler setup (Phase 3 hardening из offsite_backup_policy)
- `MCP_AGENT_MAIL_BEARER` env-pull из Aeza в claude-session.ps1 — токен статичен, можно хранить локально

**Как работает:** Tailscale ставится на Windows-ноут + Aeza. Aeza получает стабильный Tailscale IP (100.x.x.x). `.mcp.json` указывает на `http://100.x.x.x:8765` — всегда доступен, без туннеля.

**Стоимость:** $0 (Tailscale free tier = до 3 устройств, Personal plan). Установка ~10 мин.

**Риски:** зависимость от Tailscale координационного сервера (но overlay peer-to-peer, не relay). При переезде VPS — новый Tailscale IP, правка одной строки в `.mcp.json`.

**Priority:** P1 — до запуска secretary-v1. Снимает больше FINDINGs чем любая другая одиночная правка.

**Canon v0.5:** если Ilya approves → `decision_2026_04_22_tailscale` в canon + обновление `launcher_mcp_bootstrap` (убрать SSH tunnel шаги) + `claude-session.ps1` упрощение.

**Pending:** Ilya explicit approval. Школа не стартует миграцию без разрешения.

---

## 2026-04-22 ~17:35 — [FINDING] launcher_mcp_bootstrap v2 — два новых обязательных шага

**Step 0 (preflight MCP check):** выполнять проверку `/mcp connected` ДО чтения любых файлов. Если MCP tools не подключены — агент останавливается и сообщает Илье. Fail-loud до загрузки контекста, не после.

**Отличие от FINDING 14:30 (preflight_health_probe):** там probe на launcher уровне (PowerShell до `claude`). Здесь — первая проверка внутри сессии агента после старта. Два уровня защиты.

**Step: unset ANTHROPIC_API_KEY before claude:** перед запуском `claude` в `claude-session.ps1` убирать `ANTHROPIC_API_KEY` из env если он там. Причина: Claude Code использует его для billing, но в multi-window сессиях с разными ролями переменная из одного окна может «просочиться» в другое через PowerShell profile → неожиданный billing routing.

**Canon v0.5:** обновить `role_invariants.launcher_mcp_bootstrap` — добавить оба шага. Обновить `scripts/claude-session.ps1`.

---

## 2026-04-22 ~17:30 — [FINDING] SSH heredoc + Python f-string escape = SyntaxError trap

**Обнаружено:** librarian-v3 сегодня при попытке передать Python-скрипт через SSH heredoc.

**Симптом:** конструкция `ssh root@host 'python3 << EOF\n... f"string with \\"quotes\\"" ...\nEOF'` падает с `SyntaxError` или bash parse error. Причина: тройной уровень эскейпинга (bash single-quote → heredoc → Python f-string) конфликтует.

**Fix (librarian сделала самостоятельно):** write-to-file локально → scp на сервер → ssh execute. Три команды вместо одной heredoc-монстрины. Надёжно, читаемо, отлаживаемо.

**Canon impact:** `docs/school/skills/mcp-agent-mail-setup.md` содержит heredoc-примеры для установки. Нужен review — заменить heredoc-блоки на write+scp+execute паттерн где есть Python f-strings или специальные символы.

**Priority:** P2 — не блокирует работу (fix известен), но skills/mcp-agent-mail-setup.md должен быть исправлен до следующего агента который будет по нему устанавливать MCP.

**Canon v0.5:** добавить в `role_invariants.mcp_api_usage` gotcha: "SSH heredoc + Python f-string = trap. Use write-to-file + scp + execute."

---

## 2026-04-22 ~17:25 — [FINDING] mark_message_read persistence bug (P0 Phase 2)

**Обнаружено:** librarian-v3 в сессии W1 (2026-04-22) — 11 сообщений вернулись как Unread в следующем `fetch_inbox` после успешного `mark_message_read` в предыдущем turn'е.

**Симптом:** `mark_message_read` возвращает `{"read": true, "read_at": "..."}` (HTTP 200, success). Но при следующем `fetch_inbox` те же message_id возвращаются снова (re-appear as unread). Точный scope: только часть сообщений, не все. Паттерн воспроизводимости неизвестен.

**Impact:** I-6 (idempotency_of_reads_acks) нарушается частично — read state не персистируется между fetch вызовами. Роль вынуждена повторно обрабатывать уже прочитанные сообщения → дублирование action'ов.

**Гипотезы:**
1. SQLite WAL checkpoint race — mark записывается в WAL, fetch читает до checkpoint.
2. `fetch_inbox` фильтрует по `read_at IS NULL` но джойн на read_receipts table ломается при concurrent writes.
3. Bug в MCP Agent Mail версии на Aeza — нужна проверка `git log /opt/mcp_agent_mail/`.

**Mitigation (немедленно):** агент при `fetch_inbox` сравнивает id с last_processed_ids локально, пропускает уже обработанные. Workaround, не fix.

**Priority:** P0 для Phase 2 hardening — до rollout secretary. Нужна MCP server-side investigation на Aeza.

**Canon v0.5:** добавить в `mailbox_reliability_invariants.I-6` note: "persistence bug confirmed W1, investigation pending". Добавить в `mcp_api_usage` gotcha: "mark_message_read may not persist across fetch calls — track processed ids locally as workaround."

---

## 2026-04-22 17:22 — [FINDING] register_agent default contact_policy = open

**Обнаружено:** school-v3 (2026-04-22) при получении сообщений от parser-rumah123-v3 до respond_contact. **Подтверждено повторно** ai-helper-v2 (тот же паттерн, id=28/29 доставлены до respond_contact).

**Симптом:** parser-rumah123-v3 отправил `[PARSER-V3 ONLINE]` (id=22) и `[PRESENCE]` (id=23) в inbox school-v3 пока contact был в статусе `pending`. Сообщения доставлены. `whois(school-v3)` не возвращает поле `contact_policy` → значит дефолт = `open` (все могут писать без предварительного approval). ai-helper-v2 (id=8) подтвердил тот же паттерн.

**Impact:** Все роли, зарегистрированные без явного `set_contact_policy`, получают policy=open. Это нормально для school/librarian/parser, но КРИТИЧНО для secretary (должна быть `contacts_only STRICT` per canon v0.4 `ilya_overseer_bypass`). Если secretary зарегистрируется без явного policy → будет принимать сообщения от любого агента → нарушение principle #11 architectural_privilege_isolation.

**Mitigation:** `launcher_mcp_bootstrap` (canon v0.4) должен включать явный шаг `set_contact_policy` для sensitive ролей сразу после `register_agent`. Fail-loud: если роль = secretary/linkedin-writer/client-facing → обязателен `contacts_only`.

**Priority:** P0 для secretary-v1 launcher — до старта. P2 для текущих ролей (school/librarian/parser = open OK).

**Canon v0.5 implication:**
- `role_invariants.launcher_mcp_bootstrap` — добавить Step 3a: `set_contact_policy` для sensitive roles после register_agent.
- `role_invariants.mcp_api_usage` — добавить gotcha: `register_agent` default policy = `open`, не `contacts_only`.
- `anti_patterns_catalog.AP-7_implicit_open_policy` кандидат: регистрация sensitive роли без явного policy = security gap.

---

## 2026-04-22 ~14:00 — [FINDING] SSH tunnel prerequisite for Windows MCP clients

**Обнаружено:** school-v2 при попытке backward test (pure MCP ACK для librarian-v3 canon-ack id=16 в thread `canon-updates`).

**Симптом:** MCP Agent Mail tools недоступны в Claude Code сессиях на Windows без открытого SSH tunnel `ssh -L 8765:127.0.0.1:8765 root@193.233.128.21`. `.mcp.json` содержит корректную запись, но MCP HTTP client при старте молча не регистрирует tools если endpoint недоступен — агент узнаёт только когда пытается вызвать.

**Impact:** все роли на Windows (school, parser-v3, secretary, linkedin-*) заблокированы от MCP tools до установки tunnel. Librarian исключение — работает прямым SSH+Python на Aeza, tunnel ему не нужен.

**Mitigation options:**
1. **Persistent tunnel через autossh на Windows-ноуте** (recommended) — systemd-user или Task Scheduler, Restart=always. Выживает reconnect Wi-Fi.
2. Отдельный PowerShell с `ssh -L` постоянно открытый — простой, но ручной (закрыл окно = все роли off).
3. WSL systemd user-service для tunnel — мощно, но overhead и ещё один слой infra.

**Priority:** P1 — блокирует полноценный rollout MCP для parser / ai-helper / секретаря. Target: установить до запуска первой production-роли (secretary-v1).

**Canon implication (кандидат для v0.5):**
- `launcher_mcp_bootstrap` (canon v0.4) должен явно включать step `verify SSH tunnel is up` как precondition ДО `ensure_project`. Fail-loud probe: `curl -fs -H "Authorization: Bearer $MCP_AGENT_MAIL_BEARER" http://localhost:8765/mail/health`. Exit non-zero → агент сообщает Илье и уходит в safe mode.
- Предложить новый `AP-6_mcp_client_silent_degradation` в `anti_patterns_catalog`: MCP HTTP client silently не регистрирует tools при недоступном endpoint. Known issue, mitigation = health probe в launcher.

**Related:** NEW-9 pre-test был именно про это (Claude Code MCP client compatibility). POC в librarian-v3 прошёл потому что у него setup велся по ходу. School-v2 пришла в готовую инфру без предлаунч-probe → degraded state.

## 14:30 addition — MCP client registration timing

Claude Code HTTP MCP client регистрирует tools на старте сессии через `.mcp.json` read. Подключение происходит один раз в session init. Если tunnel down в этот момент → silent failure → tools НЕ зарегистрированы. Tunnel-up постфактум не триггерит re-registration.

**Подтверждение:** school-v2 (2026-04-22 ~14:15) — tunnel поднят, `netstat 127.0.0.1:8765 LISTENING`, `curl http://localhost:8765/mail/health` возвращает MCP HTML, но `ToolSearch +mcp-agent-mail` = `No matching deferred tools found`. Сессия была открыта когда tunnel = down → permanent degraded state до полного restart chat.

**Canon v0.5 proposal:** `launcher_mcp_bootstrap` должен содержать pre-flight health probe через PowerShell ДО запуска `claude` команды. Пример скрипта:

```powershell
$probe = curl.exe -fsS --max-time 3 http://localhost:8765/mail/health 2>$null
if (-not $probe) {
    Write-Error "MCP Agent Mail unreachable on localhost:8765. Tunnel down?"
    Write-Host "Run in separate PowerShell:"
    Write-Host "  & 'C:\Program Files\Git\usr\bin\ssh.exe' -i \$env:USERPROFILE\.ssh\aeza_ed25519 -L 8765:127.0.0.1:8765 root@193.233.128.21"
    Write-Host "Then retry this launcher."
    exit 1
}
Write-Host "MCP probe OK, starting Claude Code..." -ForegroundColor Green
claude
```

Fail-loud на **launcher уровне**, не на агент уровне (канон #5 `minimal_clear_commands`). Агент не должен узнавать о проблеме через "tools missing"; launcher обязан отказаться стартовать.

**Canon v0.5 bump должен включить:**
1. Обновление `role_invariants.launcher_mcp_bootstrap` — добавить Step 0 `preflight_health_probe` перед остальными шагами.
2. Новый `anti_patterns_catalog.AP-6_mcp_client_silent_degradation` — documented know-issue + mitigation через launcher probe.
3. Обновление `claude-session.ps1` в realty-portal/scripts/ — embed probe как первый шаг, симметрично launcher-файлам.
