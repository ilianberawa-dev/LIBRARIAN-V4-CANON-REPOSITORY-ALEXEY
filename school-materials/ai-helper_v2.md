# Handoff: ai-helper-v2

**Created:** 2026-04-22
**Role:** ai-helper-v2
**Model:** claude-sonnet-4-6
**Program:** claude-code

---

## Role + BU

**Role:** Generic AI assistant for Ilya — ad-hoc tasks, Supabase queries, LightRAG, file ops, any one-off requests not owned by a specialized role.

**BU:** None (cross-cutting helper, serves all BUs/IUs on demand).

**Edit scope allowed:** `C:\work\realty-portal\**` (anything Ilya asks)

**Edit scope denied:** Do not modify `docs/school/canon_training.yaml` without explicit school instruction. Do not touch Aeza infra config without Ilya confirmation.

---

## Read-on-start

1. `docs/school/canon_training.yaml` — full read, verify `version: 0.4`
2. `docs/school/handoff/ai-helper_v2.md` — this file
3. `docs/school/skills/mcp-agent-mail-setup.md` — API gotchas reference
4. `~/.claude/projects/C--work-realty-portal/memory/MEMORY.md` — memory index

---

## MCP State (filled at bootstrap)

- **registration_token:** `FI9WCYl8CUcyBigZBnM9clD3eJBMH2pvJOpHRAXdrwQ`
- **contacts_requested:** [school-v3, librarian-v3]
- **last_read_canon_version:** 0.4
- **domain:** generic ad-hoc assistance for Ilya

---

## TO_SUCCESSOR queue

*(empty — first bootstrap)*

---

## Cross-session dump reference 2026-04-22

Hybrid-memory vault (separate FS от Windows, чтение через copy/scp):
- Backup: vault/machine/backups/backup-20260422-095137-realty-portal-mesh-complete-20260422.md
- Digest: vault/machine/exports/memory-digest-20260422-095142.md
- Compact: vault/machine/exports/memory-compact-20260422-095142.md

Saved memories (realty-portal project):
- decision: SSH tunnel → Tailscale migration (pending Ilya approval)
- lesson: SSH heredoc + Python f-string escape trap (workaround: file+scp+execute)
- lesson: Custom API key prompt bypass (Remove-Item Env:ANTHROPIC_API_KEY)
- error: MCP mark_message_read not persisted across turns (P0 investigation)
- fact: AP-7 FINDING register_agent default contact_policy='open'
- context: realty-portal mesh state 2026-04-22 (4 agents complete)

---

## amendments

*(none yet)*
