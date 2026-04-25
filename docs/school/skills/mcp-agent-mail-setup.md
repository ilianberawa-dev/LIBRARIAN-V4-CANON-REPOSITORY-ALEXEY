---
name: mcp-agent-mail-setup
version: 1.1
status: PRODUCTION (POC T1-T10 green 2026-04-22)
owner: school
author: librarian-v3
date: 2026-04-22
last_tested: 2026-04-22
poc_result: T1-T10_10_of_10_PASS
canon_refs:
  - role_invariants.mcp_session_start_sequence
  - role_invariants.mcp_api_usage
  - role_invariants.thread_id_naming_conventions
  - role_invariants.launcher_mcp_bootstrap
  - role_invariants.project_key_convention
  - role_invariants.decision_2026_04_21_mcp_agent_mail
  - mailbox_reliability_invariants.I-1..I-10
  - principles_alexey.7_offline_first
source: https://github.com/Dicklesworthstone/mcp_agent_mail
---

# mcp-agent-mail-setup — установка, конфигурация и эксплуатация MCP Agent Mail

## TL;DR (30 sec)

Async inter-agent mailbox для Claude Code сессий. FastMCP HTTP сервер на Aeza
(`127.0.0.1:8765`), доступ через SSH tunnel + Bearer token, хранение в SQLite
WAL + FTS5 + git daily commit. Заменяет file-based `docs/school/mailbox/*.md`
на ops-слое (knowledge-слой остаётся файлами). Валидировано POC T1-T10 — 10/10
PASS 2026-04-22.

---

## 1. Overview

### Что это

MCP Agent Mail ([Dicklesworthstone/mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail), v0.3.2) —
FastMCP-based mailbox для мульти-агентных систем. Нативно покрывает:

- Identities (registered agents с `registration_token`)
- Inbox/outbox threads (thread_id namespace)
- FTS5 full-text search по всей истории
- File-leases (advisory file reservations)
- Contact policy (manual approval / auto / allowlist)
- Human Overseer Web UI на `/mail` (Илья пишет high-importance через браузер)
- Git daily commit + Ed25519 signed archive для аудита

### Зачем

Решает 4 anti-pattern из канона v0.4:

| AP | Проблема | Как решает |
|----|----------|------------|
| AP-1 | File-based mailbox без file-watcher → пропуски сообщений | push-based delivery + ack_required |
| AP-2 | School-bottleneck (всё через школу) | contact_policy=auto для routine role-to-role |
| I-5 | Re-readability: любое сообщение searchable | FTS5 + git + export |
| I-10 | Observability в одной точке для Ильи | Human Overseer UI |

### Архитектура: Aeza protected folder mode

```
┌─────────────────────────────┐           ┌──────────────────────────────┐
│ Илья Windows ноут           │           │ Aeza VPS 193.233.128.21      │
│                             │           │                              │
│ claude.exe (MCP client)     │           │ mcp-agent-mail.service       │
│   ↓ type: http              │           │   FastMCP :8765 (127.0.0.1)  │
│   url: localhost:8765/api/  │◄──SSH────►│   SQLite WAL + FTS5          │
│   Authorization: Bearer     │   tunnel  │   /opt/mcp_agent_mail/       │
│                             │           │                              │
│ claude-session.ps1:         │           │ NO Caddy, NO public domain   │
│   ssh -L 8765:127.0.0.1:8765│           │ SSH key = single auth layer  │
│   pulls MCP_AGENT_MAIL_BEARER│          │                              │
└─────────────────────────────┘           └──────────────────────────────┘
```

**Почему именно так** (решение 2026-04-21 22:15):

- **Без домена** — zero attack surface, zero DNS config, cost $0 (vs $1-9/год).
- **localhost-only bind** (`HTTP_HOST=127.0.0.1`) — FastMCP физически не слушает на external interfaces.
- **SSH tunnel = auth layer** — доступ получает только владелец SSH ключа.
- **Bearer token — defence-in-depth** — на случай если localhost бёрднется по ошибке.
- **Canon #7 offline_first** соблюдён строже чем с Caddy+domain.
- **Migration-friendly** — переезд на азиатский VPS = только host в SSH команде меняется.

---

## 2. Prerequisites

### Aeza VPS

- Ubuntu 24.04 LTS (24.04.1+ протестирован)
- SSH доступ root-ом по Ed25519 ключу (`~/.ssh/aeza_ed25519`)
- 7 GB+ RAM (1 GB для MCP, остальное для Supabase/LightRAG/tg-export)
- 20 GB+ свободного диска на `/` (SQLite + git repo + archive backups)
- Open outbound 443 (для curl|bash установки uv, pip)
- **Нет** публичного HTTPS — всё идёт через SSH tunnel

### Windows клиент

- Claude Code CLI (desktop или terminal, MCP HTTP transport supported)
- PowerShell 5.1+ или 7+ (для `claude-session.ps1`)
- OpenSSH client (`ssh.exe` в PATH)
- Тот же Ed25519 ключ в `~/.ssh/aeza_ed25519`

### Project layout

- `/opt/mcp_agent_mail/` — install dir (не трогается руками, только через uv)
- `/opt/realty-portal/.env` — хранит `MCP_AGENT_MAIL_BEARER` (chmod 600)
- `C:\work\realty-portal\docs\school\` — школьные файлы, Windows ноут Ильи

---

## 3. Install — 12 шагов (~65 мин)

### Step 0 — SSH baseline

```bash
ssh -i ~/.ssh/aeza_ed25519 root@193.233.128.21 'uname -a && df -h / && free -m'
```

Убедиться: Ubuntu 24.04, диск ≥20 GB свободно, RAM ≥7 GB.

### Step 0a — NEW-9 MCP client compatibility pre-test (15 min, throw-away)

**Зачем:** до `curl|bash` установки реального MCP — валидируем что Claude Code
умеет подключаться к remote MCP через SSH tunnel + Bearer header. Иначе
12 шагов в никуда.

```bash
# На Aeza: минимальный echo MCP на :8766 с bearer auth
ssh root@193.233.128.21 'python3 -m pip install --user fastmcp'
# Скопировать echo_mcp.py (FastMCP tool: echo(text) -> text) + systemd unit :8766
# На Windows: .mcp.json с localhost:8766 + bearer. Тест: claude mcp list.
# Если echo работает → клиент совместим → rm echo_mcp, переходим к Step 1.
```

Валидация (2026-04-21 evening): echo на :8766 вернул 200 на правильный bearer
и 401 на wrong — Claude Code HTTP transport работает.

### Step 1 — uv install

```bash
ssh root@193.233.128.21 'curl -LsSf https://astral.sh/uv/install.sh | sh'
# uv лежит в /root/.local/bin/uv
```

### Step 2 — Python 3.14 via uv

```bash
ssh root@193.233.128.21 '/root/.local/bin/uv python install 3.14'
```

### Step 3 — clone mcp_agent_mail

```bash
ssh root@193.233.128.21 'cd /opt && git clone https://github.com/Dicklesworthstone/mcp_agent_mail.git'
```

### Step 4 — uv sync (resolve deps, no install — resolve-on-run)

```bash
ssh root@193.233.128.21 'cd /opt/mcp_agent_mail && /root/.local/bin/uv sync'
```

**Важно (NEW-5):** systemd unit ниже использует `uv run --directory` — это
resolve-on-run, не install-ahead. При апгрейде: `cd /opt/mcp_agent_mail &&
git pull && uv sync && systemctl restart mcp-agent-mail`.

### Step 5 — `.env` с секретами (chmod 600)

```bash
# Сгенерировать bearer token (32 hex = 128 бит энтропии)
BEARER=$(python3 -c 'import secrets; print(secrets.token_hex(32))')

# На Aeza
ssh root@193.233.128.21 "cat > /opt/mcp_agent_mail/.env << EOF
HTTP_PORT=8765
HTTP_HOST=127.0.0.1
HTTP_BEARER_TOKEN=$BEARER
DATABASE_URL=sqlite+aiosqlite:////opt/mcp_agent_mail/storage.sqlite3
STORAGE_ROOT=/opt/mcp_agent_mail/git_mailbox_repo
GIT_AUTHOR_NAME=mcp-agent-mail
EOF
chmod 600 /opt/mcp_agent_mail/.env"

# Appened в /opt/realty-portal/.env для клиента:
ssh root@193.233.128.21 "echo 'MCP_AGENT_MAIL_BEARER=$BEARER' >> /opt/realty-portal/.env
echo 'MCP_AGENT_MAIL_URL=http://127.0.0.1:8765' >> /opt/realty-portal/.env"
```

**Важно:** `--bind` CLI флаг НЕ существует в mcp_agent_mail installer. Localhost
binding только через `HTTP_HOST=127.0.0.1` в `.env`. `HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true`
остаётся default (SSH tunnel = auth layer, localhost bypass by design).

### Step 6 — systemd unit

```ini
# /etc/systemd/system/mcp-agent-mail.service
[Unit]
Description=MCP Agent Mail FastMCP (localhost only)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mcp_agent_mail
EnvironmentFile=/opt/mcp_agent_mail/.env
Environment=PATH=/root/.local/bin:/usr/bin:/bin
ExecStart=/root/.local/bin/uv run --directory /opt/mcp_agent_mail python -m mcp_agent_mail
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
ssh root@193.233.128.21 'systemctl daemon-reload && systemctl enable --now mcp-agent-mail'
```

### Step 7 — health check

```bash
ssh root@193.233.128.21 'systemctl is-active mcp-agent-mail && ss -tlnp | grep 8765'
# Ожидается: active + LISTEN 127.0.0.1:8765
```

### Step 8 — client side (Windows): `.mcp.json` + `claude-session.ps1`

**`.mcp.json`** в корне проекта (`C:\work\realty-portal\.mcp.json`):

```json
{
  "mcpServers": {
    "mcp-agent-mail": {
      "type": "http",
      "url": "http://localhost:8765/api/",
      "headers": {
        "Authorization": "Bearer ${MCP_AGENT_MAIL_BEARER}"
      }
    }
  }
}
```

**`claude-session.ps1`** — добавить port 8765 в tunnel + pull
`MCP_AGENT_MAIL_BEARER` из `/opt/realty-portal/.env`:

```powershell
# pull env
$envBlock = ssh $server 'grep -E "^(ANON_KEY|SERVICE_ROLE_KEY|LIGHTRAG_API_KEY|MCP_API_KEY|MCP_AGENT_MAIL_BEARER)=" /opt/realty-portal/.env'

# tunnel
$tunnel = Start-Process ssh -ArgumentList "-N", "-L", "8000:127.0.0.1:8000", "-L", "9621:127.0.0.1:9621", "-L", "8765:127.0.0.1:8765", $server -PassThru -WindowStyle Hidden

# cleanup
"ANON_KEY","SERVICE_ROLE_KEY","LIGHTRAG_API_KEY","MCP_API_KEY","MCP_AGENT_MAIL_BEARER" | ForEach-Object {
    [Environment]::SetEnvironmentVariable($_, $null, "Process")
}
```

### Step 9 — ensure_project + register agents + migrate key threads

```python
# Python client (работает и из SSH сессии на Aeza, и из Claude Code via MCP)
tool("ensure_project", {"human_key": "/opt/realty-portal/docs/school"})
# → id=1

tool("register_agent", {
    "project_key": "/opt/realty-portal/docs/school",
    "program": "claude-code",
    "model": "claude-sonnet-4-6",
    "name": "librarian-v3",
    "task_description": "Librarian role v3"
})
# → registration_token (храним, он нужен на send_message)
```

После register — мigrировать 3-5 ключевых inbox-блоков в threads:

- `presence` — periodic heartbeat
- `<role>-to-successor` — handoff archival
- `<role>-to-school` — startup ACKs
- `canon-updates` — school broadcasts при bump

### Step 10 — contact approval handshake

```python
# Первый send_message fails с "Contact approval required" и авто-создаёт pending
tool("request_contact", {
    "project_key": "/opt/realty-portal/docs/school",
    "from_agent": "librarian-v3",
    "to_agent": "school-v2",
    "registration_token": LIBRARIAN_V3_TOKEN
})
# Ответ approves — нужен registration_token адресата
tool("respond_contact", {
    "project_key": "/opt/realty-portal/docs/school",
    "to_agent": "school-v2",
    "from_agent": "librarian-v3",
    "accept": True,
    "registration_token": SCHOOL_V2_TOKEN  # токен адресата!
})
```

Bidirectional — повторить request+respond в обратную сторону если нужен
two-way channel.

### Step 11 — первое реальное сообщение

```python
tool("send_message", {
    "project_key": "/opt/realty-portal/docs/school",
    "sender_name": "librarian-v3",
    "sender_token": LIBRARIAN_V3_TOKEN,
    "to": ["school-v2"],
    "subject": "[PRESENCE] librarian-v3 active",
    "body_md": "## Presence ping\n\nlibrarian-v3 online.",
    "thread_id": "presence",
    "importance": "low",
    "ack_required": False
})
```

### Step 12 — T1-T10 acceptance tests

См. `docs/school/tests/mailbox_reliability_v1.md` + секция 5 ниже.

---

## 4. API gotchas (critical — расходится с readme MCP Agent Mail)

### `ensure_project` — `human_key`, НЕ `project_key`

```python
# ПРАВИЛЬНО
tool("ensure_project", {"human_key": "/opt/realty-portal/docs/school"})

# НЕПРАВИЛЬНО (validation error)
tool("ensure_project", {"project_key": "/opt/realty-portal/docs/school"})
```

Все остальные tool'ы принимают `project_key` — только `ensure_project` выбивается.

### `fetch_inbox` — `structuredContent.result[]`, НЕ `.messages[]`

```python
r = tool("fetch_inbox", {
    "project_key": "/opt/realty-portal/docs/school",
    "agent_name": "librarian-v3",
    "registration_token": TOKEN,
    "limit": 50
})
messages = r["result"]["structuredContent"]["result"]  # not .messages
```

**Default limit=20.** Для полной истории всегда `limit≥50`.

Фильтр `urgent_only: bool` — `unread_only` не существует.

### `mark_message_read` — single `message_id: int`

```python
# ПРАВИЛЬНО
tool("mark_message_read", {
    "project_key": "/opt/realty-portal/docs/school",
    "agent_name": "librarian-v3",
    "message_id": 42,  # single int!
    "registration_token": TOKEN
})

# НЕПРАВИЛЬНО
tool("mark_read", {"message_ids": [42, 43]})  # нет такого tool, нет такого поля
```

Правильное имя tool'а — `mark_message_read`, не `mark_read`. Один вызов на
одно сообщение — пройти по inbox циклом.

### `register_agent` — `program` + `model` + `name`

```python
# ПРАВИЛЬНО
tool("register_agent", {
    "project_key": "/opt/realty-portal/docs/school",
    "program": "claude-code",
    "model": "claude-sonnet-4-6",  # или claude-opus-4-7
    "name": "librarian-v3",
    "task_description": "optional"
})

# НЕПРАВИЛЬНО
tool("register_agent", {"agent_name": "...", "description": "..."})
# → validation error: program + model missing, agent_name + description unexpected
```

### `request_contact` ПЕРЕД первым `send_message`

```python
# send_message к agent без контакта → pending request авто-создан, сообщение НЕ доставлено
# Нужен явный handshake:
tool("request_contact", {"from_agent": "A", "to_agent": "B", "registration_token": A_TOKEN})
tool("respond_contact", {"to_agent": "B", "from_agent": "A", "accept": True, "registration_token": B_TOKEN})
# Только теперь send_message работает.
```

**Получатель должен быть зарегистрирован** (`register_agent`) до попытки
установить контакт. Ошибка: `"local recipients X are not registered"`.

### `project_key` — Linux-absolute path

**NEW-10 (discovered 2026-04-22):** `Path('C:\\work\\...').is_absolute()` на
Linux возвращает `False`. MCP сервер живёт на Aeza → нужен его локальный путь.

```python
# ПРАВИЛЬНО
project_key = "/opt/realty-portal/docs/school"

# НЕПРАВИЛЬНО (SQLite FTS equality fails)
project_key = "C:\\work\\realty-portal\\docs\\school"
```

Canonical value: `/opt/realty-portal/docs/school`.

### `send_message` — `body_md` + `sender_token`, НЕ `body` + `registration_token`

```python
# ПРАВИЛЬНО
tool("send_message", {
    "project_key": "/opt/realty-portal/docs/school",
    "sender_name": "librarian-v3",
    "sender_token": TOKEN,  # это "sender_token", не "registration_token" в этом контексте
    "to": ["school-v2"],
    "subject": "...",
    "body_md": "...",  # markdown body, не plain "body"
    "thread_id": "presence",
    "importance": "low",
    "ack_required": False
})
```

---

## 5. Acceptance tests T1-T10

POC result 2026-04-22: **10/10 PASS**. Полный детейл —
`docs/school/tests/mailbox_reliability_v1.md`.

| ID | Что проверяет | SLO invariant | Метод |
|----|---------------|---------------|-------|
| T1 | systemd service active | I-1 at_least_once | `systemctl is-active mcp-agent-mail` → `active` |
| T2 | health_check + localhost bypass | I-10 observability | `tool("health_check")` → `{"status":"ok"}` |
| T3 | ensure_project idempotent | I-3 atomic_writes | 2 call'а с тем же `human_key` → тот же `id` |
| T4 | register_agent returns token | I-1 baseline | Проверить `registration_token` в ответе (43 chars) |
| T5 | contact request+approve | I-2 eventual consistency | `request_contact` + `respond_contact` → `approved=True` |
| T6 | send_message delivered | I-1 at_least_once | `count=1` + message_id в deliveries |
| T7 | fetch_inbox shows msg | I-4 total_ordering | Сообщение из T6 находится в `structuredContent.result[]` |
| T8 | mark_message_read | I-6 idempotency | `{"read":true,"read_at":"..."}` |
| T9 | thread coherence | I-4 + I-7 | 2 msg в одном thread_id → оба visible |
| T10 | persistence after restart | I-3 atomic + I-7 offline | `systemctl restart` + fetch → old messages survive |

### Как прогонять

```bash
# На Aeza (где сервер):
scp tests/at_full.py root@aeza:/tmp/ && ssh root@aeza 'python3 /tmp/at_full.py'

# Script pattern — в docs/school/tests/ (Python urllib + bearer token из .env)
# Результат: print(\"T1:[PASS/FAIL] ... | detail\") для каждого теста
```

Канонный script-шаблон — см. `mailbox_reliability_v1.md`. При смене схемы API
(после upgrade mcp_agent_mail) — перегонять T1-T10 + дополнять mismatches в
`role_invariants.mcp_api_usage`.

---

## 6. Canon integration (обязательные invariants для всех ролей)

Согласно canon v0.4 — каждая роль в проекте, использующая MCP Agent Mail,
обязана соблюдать:

### `mcp_session_start_sequence` (4 шага в начале user-turn)

```python
# 1. presence ping
tool("send_message", {
    "to": ["school-v2"],
    "subject": "[PRESENCE]",
    "thread_id": "presence",
    "importance": "low",
    "ack_required": False,
    # ... sender creds
})

# 2. fetch_inbox
r = tool("fetch_inbox", {"agent_name": ROLE_NAME, "limit": 50, ...})
msgs = r["result"]["structuredContent"]["result"]

# 3. ack loop
for m in msgs:
    if not m.get("read_at"):
        tool("mark_message_read", {"message_id": m["id"], ...})

# 4. reply/act — ответ на новые directives если есть
```

### `mcp_api_usage` — параметры corrections (см. §4 выше)

### `thread_id_naming_conventions` — namespaces строго:

| thread_id pattern | Назначение |
|-------------------|------------|
| `<role>-to-school` | Отчёты/запросы от роли школе |
| `<role>-to-successor` | Handoff v(N) → v(N+1) |
| `research-<topic>-<subtopic>` | Research threads |
| `workshop-<topic>` | Consensus workshops |
| `handoff-<role>-v<N>-to-v<N+1>` | Handoff-specific |
| `presence` | Periodic heartbeat |
| `canon-updates` | School broadcast при canon bump |
| `delivery-slo-breaches` | Нарушения SLA |

Произвольные thread_id — нарушение канона (O(N²) complexity при поиске).

### `launcher_mcp_bootstrap` — каждый `docs/school/launcher_*.md` включает MCP секцию

См. §7 (шаблон ниже).

### `project_key_convention` — всегда `/opt/realty-portal/docs/school`

---

## 7. Launcher template для новых ролей

Канонный bootstrap-блок. Копировать в `docs/school/launcher_<role>.md` секцию
«первый turn» **дословно** (меняются только `<role>-vN`):

````markdown
## MCP Agent Mail bootstrap (выполнить ПЕРВЫМ в сессии)

### 1. SSH tunnel (Илья запускает `claude-session.ps1` — делает автоматически)

```powershell
ssh -L 8765:127.0.0.1:8765 root@193.233.128.21
```

Env var `MCP_AGENT_MAIL_BEARER` должен быть set в процессе Claude Code.

### 2. ensure_project (idempotent)

```python
tool("ensure_project", {"human_key": "/opt/realty-portal/docs/school"})
```

### 3. register_agent — ТОЛЬКО при первой сессии роли

```python
tool("register_agent", {
    "project_key": "/opt/realty-portal/docs/school",
    "program": "claude-code",
    "model": "claude-sonnet-4-6",    # или claude-opus-4-7
    "name": "<role>-vN",
    "task_description": "..."
})
# → registration_token — СОХРАНИ в handoff_<role>_vN.md (секция secrets)
```

**При наследовании от v(N-1) — НЕ вызывай register_agent.** Используй
registration_token из предыдущего handoff (token агента устойчив между
сессиями роли).

### 4. request_contact к адресатам (если contact_policy не `open`)

```python
for peer in ["school-v2", "librarian-v3", ...]:
    tool("request_contact", {
        "from_agent": "<role>-vN",
        "to_agent": peer,
        "registration_token": MY_TOKEN
    })
```

Peer принимает через `respond_contact` (один раз per pair, expires 30 дней).

### 5. mcp_session_start_sequence — 4 шага каждый user-turn

См. canon_training.yaml → `role_invariants.mcp_session_start_sequence`.
````

---

## 8. Troubleshooting

### Shell escaping через SSH (base64 workaround)

Heredoc Python через SSH ломается на Windows path с `\U`, `\w` (unicode
escape) и на Cyrillic quoting. Workaround: base64 encode локально, decode
на Aeza.

```bash
# Local (Windows Git Bash)
python3 -c "
import base64
script = r'''
import json
# ... Python код с литералами которые ломают shell ...
'''
print(base64.b64encode(script.encode()).decode())
" | ssh root@aeza 'python3 -c "import base64,sys; open(\"/tmp/s.py\",\"wb\").write(base64.b64decode(sys.stdin.read().strip()))" && python3 /tmp/s.py'
```

Или ещё проще: `Write` tool в Claude Code → `scp` → `ssh python3`.

### Bearer token rotation

```bash
# 1. Сгенерировать новый
NEW_BEARER=$(python3 -c 'import secrets; print(secrets.token_hex(32))')

# 2. Обновить на Aeza (server-side + client reference)
ssh root@aeza "sed -i 's|^HTTP_BEARER_TOKEN=.*|HTTP_BEARER_TOKEN=$NEW_BEARER|' /opt/mcp_agent_mail/.env
sed -i 's|^MCP_AGENT_MAIL_BEARER=.*|MCP_AGENT_MAIL_BEARER=$NEW_BEARER|' /opt/realty-portal/.env
systemctl restart mcp-agent-mail"

# 3. На Windows: claude-session.ps1 сам подтянет новый при следующем старте
# 4. Перезапустить все открытые Claude Code чаты
```

### Service restart (минимум даунтайма)

```bash
ssh root@aeza 'systemctl restart mcp-agent-mail'
# Обычно <2 сек. SQLite WAL гарантирует persistence (validated T10).
# Клиенты переподключаются автоматически при следующем tool call.
```

### «Contact approval required» на send_message

Нормальное поведение. При первом send к новому peer — server авто-создаёт
pending request. Решение: `respond_contact` с token адресата (см. §4).

### «local recipients X are not registered»

Адресат не зарегистрирован в этом `project_key`. Нужен `register_agent` до
первого `send_message`.

### `Path.is_absolute()` returns False на Linux для Windows path

NEW-10. Всегда используй `/opt/realty-portal/docs/school` как project_key,
никогда `C:\work\...`.

### Claude Code MCP client не видит сервер

1. Проверить tunnel: `ss -tlnp | grep 8765` на Windows (должен быть
   `127.0.0.1:8765` LISTEN).
2. Проверить env: `$env:MCP_AGENT_MAIL_BEARER` непустой.
3. Проверить сам сервер: `curl http://localhost:8765/api/health`
   (через tunnel — должен вернуть `{"status":"ok"}`).
4. `.mcp.json` — `type: "http"` (не `sse`, не `stdio`).

### logs

```bash
ssh root@aeza 'journalctl -u mcp-agent-mail -n 50 --no-pager'
# Или follow при active debug:
ssh root@aeza 'journalctl -u mcp-agent-mail -f'
```

---

## 9. Monitoring

### Health

```bash
ssh root@aeza '
echo "=== systemctl ==="
systemctl is-active mcp-agent-mail
systemctl status mcp-agent-mail --no-pager | head -10

echo "=== listening ports ==="
ss -tlnp | grep 8765

echo "=== disk ==="
du -sh /opt/mcp_agent_mail/storage.sqlite3 /opt/mcp_agent_mail/git_mailbox_repo

echo "=== memory ==="
ps -o rss= -C python3 | head
'
```

### Live tool call через curl (bypass Claude Code)

```bash
ssh root@aeza 'TOKEN=$(grep MCP_AGENT_MAIL_BEARER /opt/realty-portal/.env | cut -d= -f2)
curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"health_check\",\"arguments\":{}}}" \
  http://127.0.0.1:8765/api/ | python3 -m json.tool'
```

### Human Overseer UI

```
URL: http://localhost:8765/mail  (через SSH tunnel с Windows)
Доступ: bearer из /opt/realty-portal/.env
Назначение: Илья пишет high-importance напрямую ролям, минуя школу.
          Read-only мониторинг всех threads, unread count, ack status.
```

### Message count query

```python
# Сколько сообщений в проекте, по agent'ам:
# (SQL напрямую через sqlite3 на Aeza, быстрее чем через MCP)
ssh root@aeza 'sqlite3 /opt/mcp_agent_mail/storage.sqlite3 "
SELECT a.name, COUNT(m.id) AS msg_count
FROM agents a LEFT JOIN messages m ON m.sender_id = a.id
WHERE a.project_id = 1
GROUP BY a.name ORDER BY msg_count DESC;"'
```

---

## 10. Next steps / backlog

### Phase 2 hardening (after 1 week stable operation)

- [ ] **`offsite_backup_policy`** (canon v0.4) — daily `uv run ... cli archive
      save --label $(date +%F)` + scp на Windows-ноут + Backblaze B2 sync.
      Retention: 30 daily + 12 weekly + 6 monthly.
- [ ] **LiteLLM integration** (IU3_multi_model_gateway) — MCP tool для
      unified model routing (Claude/Gemini/Qwen/DeepSeek через один endpoint).
- [ ] **secretary-v1 registration** — первый client-facing agent, тестировать
      `ilya_overseer_bypass` + `architectural_privilege_isolation` (#11).
- [ ] **parser-rumah123-v2 MCP migration** — перевести с file-based на MCP.
      Handoff через `handoff-parser-rumah123-v2-to-v3` thread.

### Phase 3 automation

- [ ] **librarian-bot push to Telegram** — hook на `importance=urgent` +
      `ack_required=true` → TG push Илье через `@PROPERTYEVALUATOR_bot`.
      SLA: urgent <5 min, high <15 min (canon v0.4 `ilya_alert_sla`).
- [ ] **A2A agent.json for secretary** — при первом платящем клиенте SaaS.
- [ ] **Canon auto-broadcast skill** — при canon bump школа автоматически
      send'ит `[CANON UPDATE]` во все активные роли с `ack_required=true`
      (нативное I-8 enforcement).
- [ ] **File-reservation policy** — использовать `file_reservation_paths`
      для coordination когда две роли редактируют один docs/school/*.md.

### Canon drift — pending validation

- [ ] Проверить `ilya_overseer` bypass на secretary с `contact_policy=contacts_only`
      + allowlist ilya-overseer. Не протестировано в POC.
- [ ] T11: search_messages FTS latency на корпусе >1000 сообщений.
- [ ] T12: git daily commit hook — archive rotation работает (1 неделя).

### Known limits

- **No cross-project routing** — один MCP instance = один project_key.
  Multi-tenant (когда school-v2 + parser-v2 + future-secretary работают
  параллельно) — все в одном проекте `/opt/realty-portal/docs/school`.
- **No native push to Claude Code UI** — клиент узнаёт о новых сообщениях
  только при `fetch_inbox`. Push = MCP resource subscription, но Claude Code
  client-side поддержка не подтверждена (canon v0.4 проверит в POC Phase 2).
- **SQLite FTS5 Cyrillic tokenization** — дефолтный `unicode61` работает,
  но для production на 10k+ messages стоит тестировать `icu` tokenizer.

---

## Appendix A — agent registration token storage

**КРИТИЧНО:** `registration_token` агента — это long-lived credential (31 days
default expiry после последнего активного use, продлевается автоматически).

Храни в handoff файле роли (`docs/school/handoff/<role>_v<N>.md`) секция
`secrets:` — Ilya ноут, chmod не нужен т.к. весь диск encrypted. В git repo
(если `docs/school/` когда-то пойдёт в git) — `.gitignore` must cover
`**/handoff/secrets.md` или inline с явной пометкой `# REDACT BEFORE PUSH`.

Token lifecycle:

1. `register_agent` → token issued
2. Сохранить в handoff (v(N) creates) + memory (`mcp_agent_mail_state.md`)
3. v(N+1) inherits — НЕ вызывает `register_agent` повторно
4. Ротация: `deregister_agent` + `register_agent` заново (редко — только при
   leak suspicion)

---

## Appendix B — agent list as of 2026-04-22 POC

| Agent | Role | ID | Status |
|-------|------|----|----|
| librarian-v3 | Librarian current | 1 | active |
| school-v2 | School orchestrator current | 2 | active |
| librarian-v2 | Librarian archived | 3 | retired |

Contacts approved (bidirectional, expires 2026-05-22):
- librarian-v3 ↔ school-v2
- librarian-v3 ↔ librarian-v2

Active threads with content:
- `presence` (periodic heartbeats)
- `librarian-v2-to-successor` (archived handoff, msg id=5)
- `librarian-v3-to-school` (startup ACKs, msg id=6)
- `canon-updates` (canon v0.4 ACK, msg id=16)

---

## v1.1 update — Session 2026-04-22 lessons

Operational learnings from live use (librarian-v3 welcoming parser-rumah123-v3,
school-v3, ai-helper-v2 через MCP). Дополнения к §4 API gotchas и §8
troubleshooting.

### L-1. SSH + Python f-string heredoc с `\"` escape = SyntaxError

**Симптом:** heredoc Python через `ssh "python3 << EOF ... EOF"` ломается
когда внутри f-string есть `m[\"id\"]` или `m.get(\"subject\")` — bash
парсит `\"` как escape, передаёт Python-у сломанную строку.

```python
# ЛОМАЕТСЯ через SSH heredoc:
print(f"id={m[\"id\"]}")  # → SyntaxError: unexpected character after line continuation

# РАБОТАЕТ (через SSH heredoc):
print("id=" + str(m["id"]))  # string concat вместо f-string с quotes
```

**Canonical fix pattern (применён в этой сессии 3 раза успешно):**

```bash
# 1. Write Python script локально через Write tool
Write(file_path="C:/work/realty-portal/docs/school/tests/mcp_tasks.py", content=...)

# 2. scp на Aeza
scp -i ~/.ssh/aeza_ed25519 "C:/work/.../mcp_tasks.py" root@aeza:/tmp/

# 3. Выполнить и удалить локальную копию
ssh root@aeza 'python3 /tmp/mcp_tasks.py' && rm "C:/work/.../mcp_tasks.py"
```

Write → scp → execute. f-strings работают нативно, нет shell escaping, нет
unicode issues. Для одноразовых MCP operations — canonical pattern.

### L-2. Custom API key prompt bypass

**Симптом:** при старте `claude` появляется prompt "Use custom API key? (Y/n)"
из-за set env var `ANTHROPIC_API_KEY`, блокирует автоматизацию сессии.

```powershell
# Fix — clear env перед запуском:
Remove-Item Env:ANTHROPIC_API_KEY
claude --model sonnet
```

Добавить в `claude-session.ps1` перед `claude` call (если когда-либо
появляется ANTHROPIC_API_KEY в окружении). После очистки CC использует
**OAuth Max login** (токен хранится в `~/.claude/.credentials.json`,
auto-refresh) — не требует API key вообще.

### L-3. Model selection — ЯВНО `sonnet`, default = Opus 4.7 ($5/$25 per Mtok)

**Симптом:** `claude` без `--model` запускает **Opus 4.7** — $5/Mtok input,
$25/Mtok output. Sonnet 4.6 = $3/$15 (1.6x дешевле input, 1.7x дешевле output).
Haiku 4.5 = $1/$5 (5x дешевле). Для routine ops у librarian/parser/school
нужен Sonnet; Opus — только architectural work и canon bumps.

```bash
# Canonical start для рутинных ролей:
claude --model sonnet

# Opus только когда: architectural work, canon bump, strategist-opus tasks
claude --model opus
```

Обновить `claude-session.ps1` и все launcher_*.md:

```powershell
# было:
claude
# станет:
claude --model sonnet  # или параметризовать через $env:CLAUDE_MODEL
```

### L-4. `/status` noise: "Found invalid settings files: .mcp.json"

**Симптом:** `/status` в Claude Code UI показывает warning о `.mcp.json` —
npx wrapper парсит формат конфига, не понимает новый `type: "http"` entry,
выдаёт warning.

**Решение:** **игнорировать**. Это npx wrapper check, не реальная проблема.
MCP Agent Mail connection работает нормально — проверять через `/mcp` tool,
не через `/status`.

### L-5. `/mcp` > `/status` как primary diagnostic (первая команда при старте)

**Симптом:** `/status` показывает общее здоровье Claude Code но НЕ реальный
MCP connection state (connected/disconnected/tool count).

**Canonical diagnostic chain — `/mcp` ПЕРВАЯ команда при старте сессии** (до
любых tool calls):

1. `/mcp` — список всех MCP серверов + connection state + tool count
2. `/mcp <name>` — detail по конкретному серверу (status, tools exposed)
3. Tool call с server prefix — live-test (`mcp__agent_mail__health_check`)
4. `/status` — для debug Claude Code itself, НЕ MCP

### L-6. `mark_message_read` persistence bug — observed 2026-04-22

**Симптом:** 11 сообщений отмечены `mark_message_read` в turn N, но в turn
N+1 снова appears as unread после другого fetch_inbox.

**Voсspro:** Возможные причины (требует investigation):

1. `read_at` timestamp пишется в отдельную таблицу с lazy sync → проиграется
   после `systemctl restart mcp-agent-mail`.
2. `fetch_inbox` без explicit `unread_only=false` в новой сессии даёт
   stale view (query-time recalc).
3. `mark_message_read` требует explicit `ack` follow-up через
   `acknowledge_message` — documentation unclear.

**Workaround пока не fix:** при критических операциях — прогонять
`mark_message_read` повторно в начале каждой сессии (idempotent per I-6).

**Ticket:** Phase 2 investigation — открыть при migration на v1.2.

### L-7. SSH `-L` tunnel fragility — >10 disconnects за session

**Симптом:** `ssh -L 8765:127.0.0.1:8765` падает от idle timeout, network
blip, wifi roaming. Требует ручного reconnect → broken MCP connection →
все tool calls fail silent.

**Workarounds по приоритету:**

```bash
# Опция 1 (low effort): autossh с keepalive
autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
  -N -L 8765:127.0.0.1:8765 root@193.233.128.21

# Опция 2 (лучше long-term): Tailscale mesh VPN
# Aeza + Windows ноут в одной Tailscale net → прямой доступ к 100.x.x.x:8765
# Нет SSH tunnel вообще, нет public IP, встроенный WireGuard
# RFC pending Ilya decision 2026-04-22

# Опция 3 (сейчас): include autossh install в claude-session.ps1
# choco install autossh (или WSL)
```

**Recommendation:** Phase 2 migration на **Tailscale — предпочтительный
путь** (не autossh). Решает fragility + упрощает multi-device (Windows +
Mac + телефон Ильи в одной mesh) + встроенный WireGuard = TLS не нужен +
zero public surface. Autossh — fallback если Tailscale почему-то недоступен.

### L-8. BOM fix — confirmed critical для `.mcp.json`, `.yaml`, `.env`

**Симптом:** PowerShell 5.1 `Set-Content -Encoding UTF8` или `>` redirect
добавляет BOM → JSON/YAML parser ломается:

```
SyntaxError: Unexpected token '' in JSON at position 0
yaml.scanner.ScannerError: mapping values are not allowed
```

**Canonical fix pattern (уже применялся в Step 5 install + path migration):**

```bash
# Для новых файлов из PowerShell — через Python:
python3 -c "open(r'C:/path/file.json','w',encoding='utf-8',newline='').write('...')"

# Или PowerShell 7+ `-Encoding utf8NoBOM`:
Set-Content -Path file.json -Value $content -Encoding utf8NoBOM

# Read/rewrite (drop BOM):
python3 -c "
import pathlib
p = pathlib.Path(r'C:/path/file.json')
t = p.read_text(encoding='utf-8-sig')  # утилизирует BOM
p.write_text(t, encoding='utf-8', newline='')  # без BOM
"
```

**Особо критично для:** `.mcp.json` (Claude Code MCP client fails to connect
if file has BOM), `canon_training.yaml` (школа/роли fail при старте),
`launch_manifest.json` (bootstrap fails), **любых UTF-8 configs читаемых CC**
(settings.json, .claude/hooks/*.json, skill frontmatter YAML — все без BOM).

### Summary of v1.1 deltas

| Lesson | Applied to | Status |
|--------|-----------|--------|
| L-1 heredoc escape | §8 troubleshooting + this section | ✅ canonical Write→scp→exec pattern |
| L-2 API key prompt | claude-session.ps1 | 🔜 добавить `Remove-Item Env:ANTHROPIC_API_KEY` |
| L-3 model default | claude-session.ps1 + launchers | 🔜 `--model sonnet` обязательно |
| L-4 /status noise | §8 troubleshooting | ✅ ignore warning documented |
| L-5 /mcp primary | §8 troubleshooting | ✅ diagnostic chain documented |
| L-6 mark_read persistence | Phase 2 backlog | 🔍 investigation pending |
| L-7 tunnel fragility | Phase 2 backlog | 📋 Tailscale RFC pending Ilya |
| L-8 BOM criticality | §8 troubleshooting | ✅ canonical fix documented |

---

## Changelog

- **1.1** (2026-04-22, librarian-v3) — session lessons appended (L-1..L-8):
  heredoc escape, API key prompt, model default, /status noise, /mcp primary,
  mark_message_read persistence bug, SSH tunnel fragility (Tailscale RFC),
  BOM criticality. 10+ skill_corrections из JSON handoff pending finalize
  in v1.2 (Phase 2 skill review).

- **1.0** (2026-04-22, librarian-v3) — initial skill canonisation. POC T1-T10
  10/10 PASS. All gotchas from section 4 validated in live tests. Based on
  mcp_agent_mail v0.3.2 (Dicklesworthstone upstream).
