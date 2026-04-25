---
version: 2.0
created_by: librarian-v4
created_at: 2026-04-23T18:30+08:00
recipient: librarian-v5
purpose: 400-word warm-start TL;DR если потребуется перезапуск или новая сессия
canon_version_when_written: 0.4
note: "librarian-v4 completed M1+M2 missions in single session (scout + heartbeat-common). Brief создан v4 как part of exit protocol."
---

# librarian-v4 warm-start brief

**Ты — librarian-v5, IU1 Infrastructure/Librarian. UI чат: TBD (launcher определит). Workspace: C:\work\realty-portal\**

## Что уже сделано v4 (2026-04-23)

**M1 (scout IT-archive) — ✅ COMPLETE:**
- Scanned 3 locations: Windows local (16 MB), Aeza remote (104 MB), Postgres (NOT running)
- **PRIMARY library index:** `docs/school/library_index.json` (362 KB, 151 posts, Windows — newer)
- **FULL media archive:** Aeza `/opt/tg-export/media/` (52 files, 65 MB — 19 ZIP, 4 PDF, 16 images, 13+ audio/video)
- **Transcripts:** 8 complete on Aeza (msg_13,15,136,137,144,147,164,165,170) — ~134 posts untranscribed
- **Deliverable:** `vault/shared/knowledge/dumps/librarian-v4-archive-map.md` — full inventory + gaps + recommendations

**M2 (heartbeat-common.md) — ✅ COMPLETE:**
- Wrote `docs/school/skills/heartbeat-common.md` v1.0 (15 KB, canonical skill)
- Unifies Layer 1 (infra watchdog) + Layer 2 (human-rhythm) from librarian production + parser design
- Answers 4 open questions: constants revision protocol, bash-loop vs long-running, pg advisory vs flock, file-based vs TG push
- **Unblocks:** parser-v4 (3 workers heartbeat) + ai-helper-v3 (LLM batch jobs) — P0 blocker resolved
- Canon_backlog updated (M2 completion documented)

**Infrastructure validated:**
- MCP Agent Mail: active on Aeza (systemd, 127.0.0.1:8765), Windows SSH tunnel NOT established (v4 used file-based fallback)
- File-based mailbox: `docs/school/mailbox/*.md` — works without MCP (canon fallback compliant)
- Aeza production heartbeat: `/opt/tg-export/heartbeat.sh` (SHA256 38c1b30a...) — canonical Layer 1 reference

## Текущий статус системы (2026-04-23)

**Canon version:** 0.4 (POC T1-T10 PASS by v3, bump applied 2026-04-22)

**Pending backlog (v5 может принять):**
- **LightRAG ingest:** Phase 0 transcripts 164/165 + skills-a-to-ya.md 2/3 remainder (pre-approved by school, waiting librarian capacity)
- **Library reconciliation:** Windows 151 posts vs Aeza 152 posts (1-post delta — investigate duplicate/filter)
- **Transcript backlog:** ~134 posts untranscribed (prioritize by L0-L7 curriculum level)
- **Media sync:** 41 files missing from Windows (52 Aeza - 11 Windows) — optional if offline access needed

**Parser + ai-helper next steps:**
- Parser-v4 reads heartbeat-common.md → implements for 3 workers → 3-day test → reports to school
- ai-helper-v3 reads heartbeat-common.md → implements for LLM batch jobs → Claude/OpenAI/Grok fallback chain
- School monitors 2-4 week validation → decides canon v0.5 extraction (role_invariants.heartbeat_protocol_required candidate)

## Ключевые архитектурные решения (canon v0.4 stable)

- **MCP Agent Mail:** Production on Aeza, localhost:8765 bind (no public surface, SSH tunnel required for Windows client)
- **Library source of truth:** Windows `docs/school/library_index.json` (362 KB, 151 posts) — processed by v2/v3, enhanced metadata
- **Heartbeat protocol:** Layer 1 cron watchdog + Layer 2 worker self-declared pauses (expected-duration logging, manifest.json atomic, `_status.json` snapshot)
- **Disaster recovery:** Two carriers (Aeza VPS + Windows local), manual sync control (not simultaneous edits per canon)

## Что НЕ делать (canon v0.4 obligations)

- НЕ самооценивай контекст (`context_measurement_rule` — source of truth = UI indicator у Ильи, спрашивай явно)
- НЕ редактируй `canon_training.yaml` (школа-only, librarian reads + proposes via canon_backlog)
- НЕ начинай новые задачи без проверки `outbox_to_librarian.md` + `dispatch_queue.md` (может быть новая директива школы)
- НЕ старт MCP operations без SSH tunnel probe (curl http://localhost:8765/healthz → 200 OK, иначе file-based fallback)

## Файлы для проверки при перезапуске

1. `docs/school/canon_training.yaml` → `version` (0.4 или выше, drift check)
2. `docs/school/warmstart/librarian_v4_brief.md` → этот файл (quick context)
3. `docs/school/handoff/librarian_v4.md` → full state dump (20 KB, M1+M2 details)
4. `docs/school/mailbox/outbox_to_librarian.md` → директивы школы (если есть новые)
5. `docs/school/mailbox/inbox_from_librarian.md` → последние 3-5 блоков (v4 exit closure check)
6. `vault/shared/knowledge/dumps/librarian-v4-archive-map.md` → IT-archive inventory (если работа с archive)

## Known issues для v5

1. **SSH tunnel:** MCP tools требуют tunnel UP перед `claude` start (tools register on init, not post-facto). Verify: `curl http://localhost:8765/healthz`. Alternative: file-based mailbox (v4 validated).
2. **Library discrepancy:** 151 vs 152 posts (Windows vs Aeza) — investigate 1-post delta.
3. **Postgres down:** `docker:realty-postgres` not running — if LightRAG ingest planned, start container first.
4. **Transcript backlog:** 134 posts (estimate) need Grok STT processing — prioritize by curriculum L0-L7 if tackling.

**~400 words.** Подробности: `handoff/librarian_v4.md` (13 разделов, 20 KB) + `canon_training.yaml` v0.4.
