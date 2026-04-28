# Personal AI Assistant - Version History

## v1.0 - MVP to Sales (2026-04-24)

**Status:** Initial release  
**Creator:** librarian-v4  
**File:** `v1.0-mvp-to-sales.md`

### What's included:
- ✅ 4-phase development roadmap (MVP → Self-Use → Parser/Content → Client Sales)
- ✅ Architecture diagram (Memory + Skills + MCP)
- ✅ 11 Alexey's canonical principles with implementation examples
- ✅ Technical stack (Claude Code, MCP servers, APIs)
- ✅ Proactive thinking engine (cron-based)
- ✅ Skills library (basic + advanced)
- ✅ Metrics for each phase
- ✅ Pricing model ($49-299/month)
- ✅ Architectural checklist (pre-release validation)

### Canonical principles applied:
1. Portability - Docker compose up = works
2. Minimal integration code - n8n/MCP over custom
3. Simple nodes - one task per script
4. Skills over agents - grow through skills not agents
5. Minimal clear commands - imperative, fail-loud
6. Single secret vault - all keys in .env
7. Offline first - own server, cloud only when needed
8. Validate before automate - month trial before automation
9. Human rhythm API - random pauses, not regular intervals
10. Content factory model - parse → filter → rebuild → autopublish
11. Architectural privilege isolation - security via architecture

### Size:
- 767 lines
- ~27KB
- 768 строк контента

### Target audience:
- Solopreneurs building personal AI assistant
- Developers wanting to monetize AI assistant ($49-299/mo)
- Anyone following Alexey's canonical approach

---

## Planned updates:

### v1.1 - WhatsApp Integration (planned)
- [ ] Add WhatsApp MCP server setup
- [ ] WhatsApp-specific skills
- [ ] Multi-messenger management

### v1.2 - Enterprise Features (planned)
- [ ] Team collaboration skills
- [ ] Role-based access control
- [ ] Audit logging

### v2.0 - Client Onboarding Automation (planned)
- [ ] Automated setup scripts
- [ ] Client dashboard
- [ ] SaaS billing integration

---

**Latest version:** v1.2 (post re-audit, full features, 3-tier orchestration)
**Last updated:** 2026-04-25

---

## v1.2 — Full features + 3-tier orchestration (2026-04-25)

**Status:** ACTIVE — replaces v1.1 for MVP scope
**Files:**
- `INSTALLATION-PLAN.md` — детальный план 8 этапов с SQL schema, acceptance criteria
- `FOREMAN-PROMPT.md` — промпт для прораба (Level -1)
- `INSTALLER-TEMPLATE.md` — шаблон промпта работягам (Level -2)

### Что вернули после re-audit (потерянные функции в v1.1)

- ✅ **Brief Compiler** новый Этап 3.5 (3 раза/день grouped briefs)
- ✅ **Silero TTS активный** в Этапе 4 (не заглушка)
- ✅ **Incremental backfill** voice command "Backfill X" в Этапе 5
- ✅ **SQLite daily backup** в Этапе 6

### 3-tier orchestration model

- L0 Архитектор — Claude Code Max
- L-1 Прораб — Claude Code Max (новый чат)
- L-2 Работяги — Claude Code Max (новые чаты, по одному на этап)
- Production runtime — Anthropic API (отдельный key)

**Все 3 уровня dev (L0/L-1/L-2) идут под одной подпиской Claude Code Max владельца** ($100/мес flat). Только runtime драфтов в production использует API tokens (~$22/мес cap).

### Server переоптимизация

- VPS: UpCloud Premium $26 (2/4/50 NVMe MaxIOPS) SGP1
- Backup: Week plan $5.20
- Total infra: $31.20/мес

### Time / budget

- MVP: 13-16 дней работы (Этап 0 + 7 этапов)
- Production budget: ~$51.70/мес (infra $31.20 + Sonnet API $20 + Grok STT $0.50)
- Dev workflow: $100/мес Claude Code Max (одна подписка)

---

## v1.1 — MVP Simplified (2026-04-24)

**Status:** ACTIVE — replaces v1.0 for MVP self-use scope
**Files:**
- `v1.1-mvp-simplified.md` — main TZ (6 stages, 10-12 days)
- `AUDIT-2026-04-24.md` — audit trail, 8 findings
- `START-NEW-CHAT-DEV.md` — startup prompt for new chat

### What changed vs v1.0

**Removed from MVP (moved to Phase 2+ with trigger conditions):**
- LiteLLM proxy → native Anthropic SDK
- Multi-model cascade (Qwen+Sonnet) → Sonnet-only with prompt caching
- RAG/embeddings → SQLite FTS5
- Full 3-year history ingest → incremental + on-demand
- Automatic learning loop → manual first 2 weeks
- Silero TTS → Phase 2 (trigger: 5+ button uses)
- PWA → Phase 2 (trigger: "TG screen too small")
- 15 voice intent types → 3 core intents
- Parser paid groups → Phase 3
- 15 stages → 6 stages

**Why (canon compliance):**
- Before audit: 7/11 principles at risk
- After audit: 1/11 (only #7 Offline First as conscious trade-off on Claude cloud)

**Budget:**
- Was planned: $15-25/mo with cascade
- Now: ~$20/mo Sonnet-only with prompt caching
- Hard cap: $22/mo

**Reliability:** risk sum dropped ~70% at same MVP functionality.

### Audited against

- `kanon/alexey-11-principles.md` — 12 principles
- `kanon/simplicity-first-principle.md` — Principle #0
- `kanon/alexey-consultation-2026-04-24-agent-canon.md` — author's canon
- Industry benchmarks: Superhuman, Shortwave, Sanebox, Gmail Smart Reply, Lindy, Mem.ai

### Orchestration model

- Architect (Claude chat) decomposes tasks
- Claude Code chats execute per-stage
- Owner provides access + reviews
- Each stage has acceptance criteria
- Nothing added without trigger condition (#8 Validate Before Automate)
