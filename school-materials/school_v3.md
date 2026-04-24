# Handoff: school-v3 session snapshot

**Дата:** 2026-04-22 ~17:40 WITA
**От:** school-v3 (canon orchestrator, claude-sonnet-4-6, MCP id=6)
**Кому:** school-v4 (следующая сессия)
**Триггер:** session close по команде Ильи

**Canon version:** 0.4 (bumped этой же сессией school-v2 ранее сегодня)
**last_read_canon_version:** 0.4 ✅

---

## Mesh state snapshot — 2026-04-22 session_end

### Зарегистрированные агенты в MCP (project_key=/opt/realty-portal/docs/school)

| name | id | status |
|------|----|--------|
| librarian-v3 | 1 | active |
| school-v2 | 2 | retired (replaced by school-v3) |
| librarian-v2-archived | 3 | archived |
| school-v3 | 6 | **active (ты)** |
| parser-rumah123-v3 | 7 | active |
| ai-helper-v2 | 8 | active |

Токены в `~/.claude/projects/C--work-realty-portal/memory/mcp_agent_mail_state.md`.

### Contacts — 4-way mesh complete, all bidirectionally approved

| pair | expires |
|------|---------|
| librarian-v3 ↔ school-v2 | 2026-05-22 |
| librarian-v3 ↔ librarian-v2 | 2026-05-22 |
| librarian-v3 ↔ parser-rumah123-v3 | 2026-05-22 |
| librarian-v3 ↔ ai-helper-v2 | 2026-05-22 |
| parser-rumah123-v3 ↔ school-v3 | 2026-05-22 |
| ai-helper-v2 ↔ school-v3 | 2026-05-22 |

### Thread registry (активные threads с контентом)

| thread_id | участники | last msg id |
|-----------|-----------|-------------|
| `presence` | all | 28 |
| `canon-updates` | librarian-v3 ↔ school-v3 | 19 |
| `librarian-v3-to-school` | librarian-v3 → school-v2 | 6 |
| `librarian-v2-to-successor` | librarian-v2 → librarian-v3 | 5 |
| `librarian-to-parser` | librarian-v3 → parser-v3 | 25 |
| `parser-v3-to-school` | parser-v3 → school-v3 | 22 |
| `school-to-parser` | school-v3 → parser-v3 [WELCOME] | 24 |
| `librarian-to-ai-helper` | librarian-v3 → ai-helper-v2 | 31 |
| `ai-helper-to-school` | ai-helper-v2 → school-v3 | 29 |
| `school-to-ai-helper` | school-v3 → ai-helper-v2 [WELCOME] | 30 |

---

## I-9 handoff_safety — VALIDATED ✅

school-v3 выполнила production I-9 test: подхватила exit_closure school-v2, нашла canon-ack id=16 в school-v2 inbox, mark_message_read(16), отправила [CANON ACK RECEIVED] id=19 → librarian-v3. Bidirectional MCP verified.

---

## Completed this session

- ✅ Bootstrap: health_check → ensure_project → register_agent(school-v3, id=6) → request_contact → presence
- ✅ I-9 backward MCP test: PASS (id=16 read, id=19 sent)
- ✅ parser-rumah123-v3 approved + welcomed (id=24, thread=school-to-parser)
- ✅ ai-helper-v2 approved + welcomed (id=30, thread=school-to-ai-helper)
- ✅ canon_backlog.md: 4 новых FINDING + 1 DECISION CANDIDATE записаны
- ✅ dispatch_queue.md: [MCP BIDIRECTIONAL VERIFIED] блок записан

---

## Pending директивы от Ильи (очередь для school-v4)

### P0
- **canon v0.5 RFC** — обработать все FINDINGs из `canon_backlog.md`:
  - AP-7 open policy (secretary-v1 blocker)
  - mark_message_read persistence bug (MCP server investigation)
  - SSH heredoc trap (skills/mcp-agent-mail-setup.md fix)
  - launcher_mcp_bootstrap v2 (step 0 preflight + unset API_KEY)
  - Tailscale decision (pending Ilya approval)
- **librarian-v3 pending contacts** — librarian должен одобрить school-v3, parser-v3, ai-helper-v2 при следующем turn'е

### P1
- **heartbeat-common.md** — librarian-v3 blocked на school approval. parser heartbeat-parser.md draft готов. Unblock = директива librarian'у.
- **Phase 2 parser Lamudi** — 408 props, Ilya trigger pending
- **multi-model triangulation** — когда parser-v3 закроет A3 (LiteLLM endpoint)

### P2 (autolauncher design — через tech library, не сегодня)
- Концепт autolauncher: school инициирует запуск роли через MCP без ручного copy-paste Ильи. Илья будет делать через tech library. Требует research.

### P3
- Phase 0 librarian finish: транскрипты 164/165 + skills-a-to-ya.md 2/3 остаток
- secretary-v1 старт (ждёт MCP Phase 2 + AP-7 fix)
- LinkedIn parser/writer roadmap

---

## Architecture queue (from 2026-04-22 decision)

**Design doc:** `hybrid-memory vault/shared/decisions/2026-04-22-scale-up-architecture.md` (git `018c95c`, branch `claude/parser-v3-launcher-bootstrap-DKNwr`)

**4-stage rollout:**
- **Этап 0 (сейчас):** FancyZones visual layout — визуальная организация окон
- **Этап 1 (next session):** autolauncher + Windows Terminal tabs + Tailscale
- **Этап 2:** auto-rotation + canon v0.5 + dashboard
- **Этап 3:** role groups + batch ops → 20-agent mesh

**Canon v0.5 candidates (все в canon_backlog.md):**

| candidate | priority | description |
|-----------|----------|-------------|
| `rotation_protocol` | P0 | exit_closure @ >80% context, autolauncher reanimates successor via MCP |
| `launcher_mcp_bootstrap_v2` | P0 | step 0 preflight probe + Remove-Item Env:ANTHROPIC_API_KEY |
| `AP-6 fix` | P1 | MCP silent degradation: health_check first turn → [MCP_DEGRADED] file-only fallback |
| `AP-7 fix` | P0 | set_contact_policy('restricted') explicit в launcher для sensitive roles |
| `orchestrator_protocol` | P1 | ACK files + status_log.md + watcher.ps1 contract + school↔autolauncher ACK |

**MCP sent:** [ARCHITECTURE DECISION] → librarian-v3, thread=canon-updates, ack_required=true (msg delivered this session)

**Librarian implementation queue (Этап 1):** Tailscale migration + mesh-boot.ps1 + agents.yaml schema + watcher.ps1 context monitoring. Coordinate с school-v4 before starting.

---

## Cross-session memory dump 2026-04-22 реквизиты

Hybrid-memory vault (separate FS от Windows):
- Backup: `backup-20260422-095137-realty-portal-mesh-complete-20260422.md` (15 KB)
- Digest: `memory-digest-20260422-095142.md` (17 KB, 294 lines)
- Compact: `memory-compact-20260422-095142.md` (11 KB)
- Git: commit `4a7051b` на branch `claude/parser-v3-launcher-bootstrap-DKNwr`
- Contains: 6 новых memories + 22 исторических entries
- Access: запросить у Ильи копию/scp/git sync при необходимости

---

## Session UUIDs на 2026-04-22

librarian-v3    : 6865a62f-a051-4b63-938e-3c753efb96fc
school-v3       : 2a112b93-7547-4c9f-8588-463e7f4e5c5c
parser-v3       : 655e4058-...
ai-helper-v2    : 85ad618b-...
(school-v2 DEPRECATED: 8469df9d-...)

---

## Session cost

- Burst: ~$29.64
- Top-up: $25
- Balance: ~$20 на ILIAN's Individual Org

---

## Как стартовать school-v4

1. Убедиться что SSH tunnel up (или Tailscale если approved): `curl http://localhost:8765/mail/health`
2. Прочитать `canon_training.yaml` head-3, проверить version (ожидаем 0.4 или 0.5 если bumped)
3. Прочитать этот handoff
4. `mcp_session_start_sequence`: ensure_project → register_agent(school-v4) → request_contact(librarian-v3) → presence → fetch_inbox
5. `school_global_scan`: `ls -lat docs/school/{mailbox,handoff,skills}/`
6. Обработать inbox: librarian-v3 ответил на pending contacts? parser/ai-helper новые директивы?

**Контекст-загрузка:** ~25-30% после bootstrap + этого handoff.
