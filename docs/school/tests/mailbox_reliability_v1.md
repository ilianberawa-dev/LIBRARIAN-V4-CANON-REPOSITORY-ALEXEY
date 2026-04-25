# MCP Agent Mail — Mailbox Reliability T1-T10

**Date:** 2026-04-22  
**Server:** Aeza 193.233.128.21 (`/opt/mcp_agent_mail`)  
**Version:** mcp-agent-mail 0.3.2 (FastMCP, SQLite+WAL)  
**Project key:** `/opt/realty-portal/docs/school`  
**Agents registered:** librarian-v3 (id=1), school-v2 (id=2), librarian-v2 (id=3, archived)

---

## Results

| Test | Description | Result | Detail |
|------|-------------|--------|--------|
| T1 | systemd service active | **PASS** | `systemctl is-active` → `active` |
| T2 | health_check + localhost auth bypass | **PASS** | `{"status":"ok","environment":"development"}` — SSH tunnel is auth layer; localhost connections bypass bearer by design |
| T3 | ensure_project idempotent (human_key) | **PASS** | id=1 on both calls — `human_key` param (not `project_key`) |
| T4 | register_agent returns token | **PASS** | New agent registered, 43-char token returned |
| T5 | contact request + approve bidirectional | **PASS** | `approved=True`, expires 30 days |
| T6 | send_message delivered | **PASS** | msg_id=12, count=1 |
| T7 | fetch_inbox shows sent message | **PASS** | `structuredContent.result[]` (not `.messages[]`) |
| T8 | mark_message_read | **PASS** | `{"message_id":12,"read":true}` |
| T9 | thread coherence — 2 msgs same thread_id | **PASS** | Both messages returned under `t9-coherence` |
| T10 | persistence after `systemctl restart` | **PASS** | presence msg (id=2) survives restart; use `limit≥50` to see older messages |

**10/10 PASS**

---

## API notes (discovered during testing)

| Tool | Correct param | Wrong param tried |
|------|---------------|-------------------|
| `ensure_project` | `human_key` | `project_key` |
| `fetch_inbox` | result in `structuredContent.result[]` | `structuredContent.messages[]` |
| `fetch_inbox` | filter: `urgent_only` | `unread_only` (doesn't exist) |
| `mark_message_read` | single `message_id: int` | `mark_read` / `message_ids: []` |
| `register_agent` | `program`, `model`, `name` | `agent_name`, `description` |
| `respond_contact` | `registration_token` for target agent | — |

## Design constraints confirmed

1. **Contact approval required** before first message between any two agents. Auto-pending request is created on failed send; approve with `respond_contact` + target agent's `registration_token`.
2. **Recipients must be registered** before `send_message`. Error: "local recipients X are not registered".
3. **Localhost bypass** (`HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true` by default): all connections from 127.0.0.1 skip bearer auth. External auth is enforced via SSH tunnel — no unauthenticated path to port 8765 from outside.
4. **project_key on Linux** must be Linux-absolute path. `C:\work\...` fails `Path.is_absolute()` on Linux. Canonical key: `/opt/realty-portal/docs/school`.
5. **fetch_inbox limit**: default=20. For full history use `limit=50+`.

## Threads created during POC

| thread_id | Participants | Messages |
|-----------|-------------|---------|
| `presence` | librarian-v3 → school-v2 | id=2 |
| `librarian-v2-to-successor` | librarian-v2 → librarian-v3 | id=5 (archived handoff) |
| `librarian-v3-to-school` | librarian-v3 → school-v2 | id=6 (startup ACK) |
| `t6-acceptance` | test-t4c → librarian-v3 | test messages |
| `t9-coherence` | librarian-v3 → school-v2 | 2 thread msgs |
