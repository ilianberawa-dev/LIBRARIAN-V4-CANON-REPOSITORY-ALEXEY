---
name: autolauncher-architecture
version: 1.0
status: IMPLEMENTATION_SPEC (Stage 1-2 infra, Ilya decision 2026-04-22)
owner: librarian
author: librarian-v3
date: 2026-04-22
decision_ref: vault/shared/decisions/2026-04-22-scale-up-architecture.md (git 018c95c)
implementation_lead: librarian-v4+
canon_refs:
  - role_invariants.launcher_mcp_bootstrap
  - role_invariants.mcp_session_start_sequence
  - role_invariants.project_key_convention
  - role_invariants.one_role_one_chat
  - decision_2026_04_21_mcp_agent_mail
scope: Stage 1 (Tailscale + agents.yaml + mesh-boot) + Stage 2 (watcher + dashboard)
---

# autolauncher-architecture — implementation spec для scale-up 4→20+ агентов

## TL;DR (30 sec)

Илья принял 2026-04-22 архитектурное решение о scale-up mesh'а с 4 активных
ролей до 20+. Реализация в 4 этапа. Librarian ведёт **Stages 1-2** (infra
код): **Stage 1** — Tailscale replace SSH tunnel + `agents.yaml` registry +
`mesh-boot.ps1` (Windows Terminal multi-tab spawn). **Stage 2** — `watcher.ps1`
(context% monitoring) + `dashboard.ps1` (TUI/HTML health view). Stages 3-4
(role protocols, canon v0.5) ведёт школа, но infra координируется с
librarian через MCP thread `infra-updates`.

## Когда применять

При старте любой работы по spawn'у 5+ агента. До 4 агентов — ручной запуск
через `claude-session.ps1` + отдельные Windows Terminal tabs остаётся
workable. При 5+ — без agents.yaml/mesh-boot bookkeeping теряется (какая
роль в какой tab, какой model используется, какая версия, какой
MCP registration token).

## Не-цели

- **НЕ заменяет** MCP Agent Mail — autolauncher это spawn-time
  инструмент, messaging после spawn — MCP. См. `mcp-agent-mail-setup.md`.
- **НЕ делает rotation автоматически** — context% trigger + actual handoff
  остаются user-initiated (canon `one_role_one_chat`).
- **НЕ cross-platform** — Windows-only для Phase 1. Mac/Linux — Phase 2.

---

## 1. Scope distribution (4-stage scale-up)

| Stage | Owner | Content | Librarian scope? |
|-------|-------|---------|------------------|
| 1 | librarian + Ilya | Tailscale + agents.yaml + mesh-boot.ps1 | ✅ primary |
| 2 | librarian | watcher.ps1 + dashboard.ps1 | ✅ primary |
| 3 | school | launcher_mcp_bootstrap_v2 + rotation_protocol | coordinate only |
| 4 | school | canon v0.5 bump (orchestrator_protocol + AP-7) | coordinate only |

Librarian **НЕ** меняет канон сам — координирует через MCP thread
`infra-updates` с school-v3 и вносит предложения (школа decides bump).

---

## 2. Stage 1 — Tailscale migration

### Why Tailscale (not SSH `-L`, not autossh)

- SSH `-L` fragility — 10+ disconnects за session (observed 2026-04-22).
- autossh лечит keepalive но не решает multi-device (Windows ноут + Mac +
  phone Ильи).
- Tailscale = WireGuard mesh VPN, free tier 100 devices, zero public
  surface, встроенный TLS, auto-reconnect, MagicDNS (hostname resolution).
- Migration-friendly: при переезде Aeza → другой VPS Tailscale сам
  обновляет routing.

### Install — Aeza (server side)

```bash
ssh -i ~/.ssh/aeza_ed25519 root@193.233.128.21 '
# Добавляем репозиторий + ключ
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/24.04/noble.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/24.04/noble.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

apt-get update
apt-get install -y tailscale

# Auth (one-time, показывает URL для approval через браузер Ильи)
tailscale up --hostname=aeza-realty --ssh

# Проверка
tailscale status
tailscale ip -4  # Tailscale IP (100.x.x.x)
'
```

Илья одобряет auth URL в браузере; хост появляется в
`https://login.tailscale.com/admin/machines`.

### Install — Windows (client side)

```powershell
# Chocolatey (preferred) or direct installer
choco install tailscale -y

# Либо вручную: https://tailscale.com/download/windows
# После install — Tailscale menu-bar → Login → same account что и Aeza
```

После auth: `tailscale status` показывает `aeza-realty` с IP 100.x.x.x.

### `.mcp.json` migration

**До (SSH tunnel):**

```json
{
  "mcpServers": {
    "mcp-agent-mail": {
      "type": "http",
      "url": "http://localhost:8765/api/",
      "headers": {"Authorization": "Bearer ${MCP_AGENT_MAIL_BEARER}"}
    }
  }
}
```

**После (Tailscale):**

```json
{
  "mcpServers": {
    "mcp-agent-mail": {
      "type": "http",
      "url": "http://aeza-realty.tail-XXXX.ts.net:8765/api/",
      "headers": {"Authorization": "Bearer ${MCP_AGENT_MAIL_BEARER}"}
    }
  }
}
```

`tail-XXXX.ts.net` — tailnet name из Tailscale admin console. Bearer token
остаётся (defence-in-depth: Tailscale ACL + bearer).

### Aeza listen address — bind на Tailscale interface

```bash
# /opt/mcp_agent_mail/.env — было:
# HTTP_HOST=127.0.0.1

# Стало (Tailscale mode):
HTTP_HOST=0.0.0.0  # listen on all interfaces — Tailscale ACL блокирует non-mesh
# Или лучше — bind ТОЛЬКО на Tailscale interface:
HTTP_HOST=100.x.x.x  # конкретный Tailscale IP сервера
```

**Recommendation:** `100.x.x.x` (specific IP) — даже при misconfig Tailscale
firewall пакет физически не дойдёт с public interface.

### W5 removal — что убираем

**W5** — пятый SSH `-L` forward для MCP Agent Mail в `claude-session.ps1`:

```powershell
# БЫЛО — убираем port 8765 из tunnel:
$tunnel = Start-Process ssh -ArgumentList "-N", "-L", "8000:127.0.0.1:8000", `
  "-L", "9621:127.0.0.1:9621", "-L", "8765:127.0.0.1:8765", $server ...

# СТАЛО — 8765 больше не нужен (Tailscale DNS resolves):
$tunnel = Start-Process ssh -ArgumentList "-N", "-L", "8000:127.0.0.1:8000", `
  "-L", "9621:127.0.0.1:9621", $server ...
```

Supabase (:8000) и LightRAG (:9621) **пока остаются на SSH `-L`** — Phase 1
Tailscale-migration только для MCP Agent Mail. Supabase/LightRAG мигрируют
Phase 2 (требует security review — Supabase content может быть более
sensitive).

### Rollback plan

Если Tailscale недоступен (outage, auth issue):

1. Раскомментировать W5 в `claude-session.ps1`.
2. Revert `.mcp.json` URL на `http://localhost:8765/api/`.
3. `HTTP_HOST=127.0.0.1` в `/opt/mcp_agent_mail/.env` + `systemctl restart`.

Сохранить обе версии `.mcp.json` в `docs/school/mcp-client/` —
`librarian.mcp.json` (current/Tailscale) + `librarian.ssh-tunnel.mcp.json`
(fallback).

---

## 3. Stage 1 — `agents.yaml` schema

Central registry всех ролей в mesh'е. Location: `C:\work\realty-portal\agents.yaml`.

### Full schema

```yaml
version: 1.0
last_updated: 2026-04-22T14:00+08:00

agents:
  librarian-v3:
    role: librarian
    version: v3
    launcher_file: docs/school/launchers/librarian_v3.md
    window_title: "librarian-v3 (infra lead)"
    color: "#4A90E2"              # blue — infra ops
    max_context_pct: 50           # trigger handoff at 50% (canon v0.4)
    auto_rotate: false            # manual handoff only
    depends_on: []                # no prereqs
    startup_order: 10             # запускается 10-м
    model: claude-opus-4-7        # architectural work → Opus
    working_directory: C:\work\realty-portal
    mcp_profile: librarian        # → .mcp.json selector (future)
    registration_token_ref: handoff/librarian_v3.md#secrets

  school-v3:
    role: school
    version: v3
    launcher_file: docs/school/launchers/school_v3.md
    window_title: "school-v3 (orchestrator)"
    color: "#E24A90"              # magenta — orchestration
    max_context_pct: 50
    auto_rotate: false
    depends_on: [librarian-v3]    # school нуждается в librarian'е для canon questions
    startup_order: 20
    model: claude-opus-4-7
    working_directory: C:\work\realty-portal
    mcp_profile: school
    registration_token_ref: handoff/school_v3.md#secrets

  parser-rumah123-v3:
    role: parser
    version: v3
    launcher_file: docs/school/launchers/parser_rumah123_v3.md
    window_title: "parser-rumah123-v3"
    color: "#50C878"              # emerald — data extraction
    max_context_pct: 50
    auto_rotate: false
    depends_on: [librarian-v3]    # blocked on heartbeat-common.md
    startup_order: 30
    model: claude-sonnet-4-6      # routine extraction → Sonnet
    working_directory: C:\work\realty-portal\scrapers
    mcp_profile: parser
    registration_token_ref: handoff/parser_rumah123_v3.md#secrets

  ai-helper-v2:
    role: ai-helper
    version: v2
    launcher_file: docs/school/launchers/ai-helper_v2.md
    window_title: "ai-helper-v2 (generic)"
    color: "#FFB347"              # amber — generic helper
    max_context_pct: 50
    auto_rotate: false
    depends_on: [librarian-v3]    # blocked on heartbeat-common.md
    startup_order: 40
    model: claude-sonnet-4-6
    working_directory: C:\work\realty-portal
    mcp_profile: ai-helper
    registration_token_ref: handoff/ai-helper_v2.md#secrets

# === Future agents (not yet spawned) ===
# secretary-v1:
#   role: secretary
#   ... requires AP-7 set_contact_policy(contacts_only, allowlist=[ilya-overseer])
#   startup_order: 100             # запускается после всей infra готова
```

### Field semantics

| Field | Required | Purpose |
|-------|----------|---------|
| `role` | ✅ | category (librarian/school/parser/secretary/ai-helper) |
| `version` | ✅ | `v<N>` per canon `one_role_one_chat` |
| `launcher_file` | ✅ | markdown с bootstrap section (canon `launcher_mcp_bootstrap`) |
| `window_title` | ✅ | Windows Terminal tab label |
| `color` | optional | hex color для tab accent (dashboard visual) |
| `max_context_pct` | ✅ | handoff trigger (canon v0.4: 50) |
| `auto_rotate` | ✅ | Stage 3+: automatic handoff generate on threshold |
| `depends_on` | ✅ | список agent names; startup ждёт их `presence` ping |
| `startup_order` | ✅ | integer; lower = earlier spawn |
| `model` | ✅ | `claude-opus-4-7` / `claude-sonnet-4-6` / `claude-haiku-4-5` |
| `working_directory` | ✅ | Windows absolute path; Claude Code CWD |
| `mcp_profile` | optional | selector для future per-role `.mcp.json` |
| `registration_token_ref` | ✅ | где хранится MCP registration token |

### Validation rules

- `startup_order` unique per agent
- `depends_on` must reference existing agents или пусто
- `depends_on` не допускает циклов (DAG only)
- `working_directory` exists
- `launcher_file` exists
- `registration_token_ref` format: `path#anchor` OR `env:VAR_NAME`

---

## 4. Stage 1 — `mesh-boot.ps1` skeleton

Location: `C:\work\realty-portal\scripts\mesh-boot.ps1`.

### Commands

```powershell
.\scripts\mesh-boot.ps1 boot              # spawn all agents per agents.yaml
.\scripts\mesh-boot.ps1 add <agent_name>  # spawn single agent
.\scripts\mesh-boot.ps1 restart <agent>   # kill + respawn
.\scripts\mesh-boot.ps1 status            # list running agents + windows
.\scripts\mesh-boot.ps1 kill-all          # kill all CC windows from mesh
```

### Skeleton (v1 POC)

```powershell
# scripts/mesh-boot.ps1
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet("boot", "add", "restart", "status", "kill-all")]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$AgentName
)

$ErrorActionPreference = "Stop"
$AgentsYaml = "C:\work\realty-portal\agents.yaml"

# Require powershell-yaml module for parsing
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module powershell-yaml -Force -Scope CurrentUser
}
Import-Module powershell-yaml

$Registry = (Get-Content $AgentsYaml -Raw | ConvertFrom-Yaml).agents

function Spawn-Agent {
    param($Name, $Spec)

    Write-Host "→ Spawning $Name (role=$($Spec.role), model=$($Spec.model))"

    # Ждём пока все deps будут online (presence ping в MCP)
    foreach ($dep in $Spec.depends_on) {
        Wait-For-Presence -AgentName $dep -TimeoutSec 120
    }

    # Windows Terminal new tab с нужным профилем
    # wt.exe spec: https://learn.microsoft.com/en-us/windows/terminal/command-line
    $claudeCmd = "claude --model $($Spec.model)"
    $wtArgs = @(
        "new-tab",
        "--title", "`"$($Spec.window_title)`"",
        "--tabColor", $Spec.color,
        "--startingDirectory", $Spec.working_directory,
        "powershell", "-NoExit", "-Command", $claudeCmd
    )
    Start-Process wt.exe -ArgumentList $wtArgs

    # Log spawn event
    Add-Content -Path "C:\work\realty-portal\logs\mesh-boot.log" -Value `
        "$(Get-Date -Format o) SPAWN $Name pid=$($proc.Id)"
}

function Wait-For-Presence {
    param($AgentName, $TimeoutSec = 120)
    # TODO Stage 2: implement via MCP fetch_inbox polling на presence thread
    # Placeholder — Stage 1 skip check, assume startup_order is enough
    Write-Host "  (Stage 1: skip presence check for $AgentName)"
}

function Get-Running-Agents {
    # Parse wt windows by title matching our window_title convention
    # TODO: use Windows Terminal API если есть, или Get-Process | where WindowTitle
    Get-Process | Where-Object { $_.MainWindowTitle -match "^(librarian|school|parser|ai-helper|secretary)-v\d" }
}

switch ($Command) {
    "boot" {
        $ordered = $Registry.GetEnumerator() | Sort-Object { $_.Value.startup_order }
        foreach ($entry in $ordered) {
            Spawn-Agent -Name $entry.Key -Spec $entry.Value
            Start-Sleep -Seconds 3  # небольшая пауза между spawn'ами
        }
    }
    "add" {
        if (-not $AgentName) { throw "Usage: mesh-boot add <agent_name>" }
        Spawn-Agent -Name $AgentName -Spec $Registry[$AgentName]
    }
    "restart" {
        if (-not $AgentName) { throw "Usage: mesh-boot restart <agent_name>" }
        # TODO Stage 2: найти window, послать handoff signal, убить, заспавнить
        Get-Running-Agents | Where-Object { $_.MainWindowTitle -match $AgentName } | Stop-Process
        Start-Sleep 2
        Spawn-Agent -Name $AgentName -Spec $Registry[$AgentName]
    }
    "status" {
        Write-Host "Running agents:"
        Get-Running-Agents | Format-Table Id, MainWindowTitle -AutoSize
    }
    "kill-all" {
        $confirm = Read-Host "Kill all CC mesh windows? (y/N)"
        if ($confirm -eq "y") {
            Get-Running-Agents | Stop-Process -Force
            Write-Host "All mesh windows killed."
        }
    }
}
```

### Open design questions

1. **Profile per-role `.mcp.json`** — сейчас один `.mcp.json` в корне
   работает для всех ролей. При per-role profiles (только `secretary` не
   видит `realty-lightrag` для безопасности) — нужен CC flag или per-CWD
   mechanism. **Research TODO:** проверить поддерживает ли CC `--mcp-config
   <path>` CLI flag.
2. **Bootstrap timing** — когда новый chat стартовал, когда он успел
   прочитать canon + сделать `mcp_session_start_sequence`? Нужен signal
   «я готов». **Решение:** polling MCP `fetch_inbox` на `presence` thread —
   если агент запостил presence ping своим `register_token`, он online.
3. **Error recovery** — `wt.exe` spawn не возвращает handle на spawned
   CC session. При crash мы узнаём через watcher.ps1 (Stage 2).

---

## 5. Stage 2 — `watcher.ps1` concept

Непрерывный мониторинг health ролей. Реагирует на:

- Context% приближается к `max_context_pct` → trigger handoff generation
- Agent molchит >X минут (no presence ping) → flag stale
- MCP Agent Mail server unreachable → alarm via TG push

### Context% monitoring — the hard part

**Проблема:** CC не exposes текущий context percent через CLI / file /
stdout по состоянию 2026-04-22.

**Research TODO (librarian-v4):**

1. Проверить `claude --help` + `/status` parser output — есть ли machine-
   readable поле?
2. Проверить CC logs (`~/.claude/logs/*.jsonl`) — возможно logged there.
3. Проверить `/status` hook в settings.json — возможно hook может писать
   context% в файл при каждом turn'е.
4. Fallback: PR против CC если функции нет (`claude --print-context-pct`).

### Skeleton (v1 when research complete)

```powershell
# scripts/watcher.ps1 — запускать в отдельной PS session:
# .\scripts\watcher.ps1 &

while ($true) {
    foreach ($agent in Get-Running-Agents) {
        $ctxPct = Get-ContextPct -AgentName $agent.Name  # ← research TODO
        $maxPct = $Registry[$agent.Name].max_context_pct

        if ($ctxPct -ge $maxPct) {
            if ($Registry[$agent.Name].auto_rotate) {
                # Stage 3: автоматический handoff + spawn v(N+1)
                Initiate-Handoff -AgentName $agent.Name
            } else {
                # Stage 2: alert only
                Send-Alert -Agent $agent.Name -Message "context $ctxPct% >= $maxPct%"
            }
        }

        # Health check via MCP presence
        $lastPresence = Get-LastPresence -AgentName $agent.Name
        if ((Get-Date) - $lastPresence -gt [TimeSpan]::FromMinutes(30)) {
            Send-Alert -Agent $agent.Name -Message "silent >30min"
        }
    }

    Start-Sleep -Seconds 60  # check every minute
}
```

---

## 6. Stage 2 — `dashboard.ps1` concept

Two interfaces:

### Option A: TUI (terminal-based)

```
┌────────────────────────────────────────────────────────────┐
│ Realty-Portal Mesh — 2026-04-22 14:30                      │
├────────────────────────────────────────────────────────────┤
│ Agent               │ Ctx % │ Status   │ Last msg │ Model  │
├─────────────────────┼───────┼──────────┼──────────┼────────┤
│ librarian-v3        │  42%  │ online   │ 30s ago  │ opus   │
│ school-v3           │  18%  │ online   │ 2m ago   │ opus   │
│ parser-rumah123-v3  │  65%  │ ⚠ NEAR  │ 12s ago  │ sonnet │
│ ai-helper-v2        │   5%  │ online   │ 1m ago   │ sonnet │
├────────────────────────────────────────────────────────────┤
│ MCP Agent Mail: active │ Tailscale: up │ threads: 9        │
└────────────────────────────────────────────────────────────┘
[q] quit  [r] refresh  [h] handoff selected
```

Реализация: PowerShell + Spectre.Console NuGet package (TUI rendering).

### Option B: HTML static page

```powershell
# scripts/dashboard.ps1 html
# Генерирует C:\work\realty-portal\dashboard.html + запускает Start-Process
# на index.html. Обновляется каждые 30 сек (meta refresh).
```

HTML с JS fetch каждые 5 сек к мini HTTP endpoint (watcher.ps1 exposes
`/api/agents` on localhost port 9999).

**Recommendation:** Start с TUI (Option A) — меньше moving parts, zero
install overhead, работает в любой PS sessions.

---

## 7. Integration с existing artefacts

### claude-session.ps1 → mesh-boot.ps1 relationship

`claude-session.ps1` остаётся как **single-agent bootstrap** (одиночный
чат, manual workflow). `mesh-boot.ps1` = **multi-agent orchestration**
layer поверх. Они не конкурируют:

```
claude-session.ps1         mesh-boot.ps1
  ↓                          ↓
  single CC session          wt.exe new-tab × N
  manual SSH tunnel          Tailscale (already up)
  single .mcp.json           single .mcp.json (shared)
```

Миграция: после mesh-boot v1 готов, `claude-session.ps1` остаётся для
debug/single-session scenarios. Default Ilya flow становится mesh-boot.

### agents.yaml vs launch_manifest.json

| Artifact | Scope | Source of truth |
|----------|-------|-----------------|
| `launch_manifest.json` | Bootstrap сценарий НОВОЙ роли (first spawn) | школа пишет |
| `agents.yaml` | Registry всех АКТИВНЫХ ролей (ongoing ops) | librarian пишет |

`agents.yaml` может ссылаться на `launch_manifest.json.roles_to_launch.<role>`
через `launcher_file` field — единый source для bootstrap чеклиста.

---

## 8. Coordination с каноном (Stages 3-4 school scope)

Librarian предлагает следующие **canon v0.5 candidates** в thread `infra-updates`:

1. **`launcher_mcp_bootstrap_v2`** — расширить existing invariant: добавить
   agents.yaml registration step между `register_agent` и `request_contact`.
2. **`rotation_protocol`** — формализовать handoff trigger: при context%
   ≥ `max_context_pct` (из agents.yaml) → v(N) ОБЯЗАНА написать handoff
   до закрытия chat'а. Currently covered частично в `role_inbox_exit_closure`.
3. **`orchestrator_protocol`** — как автолаунчер взаимодействует с school:
   school одобряет новые роли в agents.yaml через MCP `[NEW ROLE REGISTRATION]`
   thread.
4. **`AP-7 open_policy_trust_by_default`** — formalize из сегодняшнего
   finding, enforce `set_contact_policy(contacts_only)` для client-facing
   ролей.

Librarian НЕ меняет canon_training.yaml сам. Все proposals идут через
school-v3 → consensus workshop → canon bump.

---

## 9. Execution queue (librarian-v4 onwards)

**Session N+1 (immediate):**

1. Tailscale install Aeza + Windows + auth
2. `.mcp.json` URL migration + W5 removal
3. Test MCP connection через Tailscale (curl health_check)
4. `agents.yaml` first write с 4 current agents
5. `mesh-boot.ps1` v1 (boot/add/status commands; restart/kill-all — v2)

**Session N+2:**

1. `launchers/*.md` extraction для 4 ролей (one-off, из handoff'ов)
2. `watcher.ps1` research фаза — как читать context% из CC
3. `watcher.ps1` v1 (без context% — только presence/MCP health)

**Session N+3:**

1. `dashboard.ps1` v1 (TUI option A)
2. `watcher.ps1` v2 (context% если research успешен)

**Session N+4 (school coordinates):**

1. canon v0.5 bump с 4 new invariants
2. `launcher_mcp_bootstrap_v2` rollout через CANON UPDATE thread

---

## Changelog

- **1.0** (2026-04-22, librarian-v3) — initial implementation spec.
  Scope = Stage 1-2 infra (librarian). Stages 3-4 (canon/role protocols)
  координируются через thread `infra-updates` но пишутся школой. Decision
  ref: `vault/shared/decisions/2026-04-22-scale-up-architecture.md` (git
  018c95c).
