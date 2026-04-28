# Aeza Server — Complete Tree Map

**Server:** root@193.233.128.21 (Aeza VPS, Vienna EU)  
**OS:** Ubuntu 24.04  
**Resources:** 2 vCPU / 8GB RAM / 59GB disk (36GB used, 61%)  
**Created:** 2026-04-24  
**Purpose:** Full directory structure reference for AI agents

---

## 📊 Disk Usage Overview

| Directory | Size | Purpose |
|-----------|------|---------|
| `/opt/mcp_agent_mail` | 340 MB | MCP mail coordination layer for agents |
| `/opt/realty-portal` | 293 MB | Main Realty Portal project |
| `/opt/tg-export` | 104 MB | Telegram parser (Alexey's channel) |
| `/opt/containerd` | 12 KB | Docker runtime config |

**Total /opt:** ~737 MB

---

## 🐳 Docker Stack (17 containers, all `realty_*` prefix)

**Running services:**

| Container | Status | Ports | Purpose |
|-----------|--------|-------|---------|
| `realty_lightrag` | Up 9h | 127.0.0.1:9621→9621 | RAG memory (LightRAG) |
| `realty_litellm` | Up 9h | 4000 | LLM gateway (Anthropic/Gemini/DeepSeek/Groq) |
| `realty_openclaw` | Up 13h (healthy) | 127.0.0.1:18789→18789 | Skill execution engine |
| `realty_ollama` | Up 13h | 11434 | Embeddings (all-minilm) |
| `supabase-kong` | Up 13h (healthy) | 8000, 8443 | API gateway |
| `supabase-pooler` | Up 13h (healthy) | 5432, 6543 | PgBouncer connection pooler |
| `supabase-storage` | Up 13h (healthy) | 5000 | File storage API |
| `supabase-auth` | Up 13h (healthy) | - | GoTrue auth |
| `supabase-edge-functions` | Up 13h | - | Deno edge runtime |
| `supabase-studio` | Up 13h (healthy) | 3000 | Admin UI |
| `supabase-analytics` | Up 13h (healthy) | - | Logflare analytics |
| `supabase-meta` | Up 13h (healthy) | 8080 | Postgres metadata API |
| `realtime-dev.supabase-realtime` | Up 13h (healthy) | - | WebSocket realtime |
| `supabase-rest` | Up 13h | 3000 | PostgREST API |
| `supabase-db` | Up 13h (healthy) | 5432 | PostgreSQL 16 |
| `supabase-vector` | Up 13h (healthy) | - | pgvector extension |
| `supabase-imgproxy` | Up 13h (healthy) | 8080 | Image transformation |

**Docker images (top 10 by size):**

| Image | Tag | Size |
|-------|-----|------|
| `ollama/ollama` | latest | 10.1 GB |
| `ghcr.io/berriai/litellm` | main-latest | 5.6 GB |
| `ghcr.io/openclaw/openclaw` | latest | 3.54 GB |
| `ghcr.io/hkuds/lightrag` | latest | 2.34 GB |
| `supabase/studio` | 2026.04.08 | 1.58 GB |
| `supabase/storage-api` | v1.48.26 | 1.3 GB |
| `supabase/edge-runtime` | v1.71.2 | 1.11 GB |
| `supabase/logflare` | 1.36.1 | 900 MB |
| `supabase/realtime` | v2.76.5 | 629 MB |
| `supabase/postgres-meta` | v0.96.3 | 505 MB |

---

## 📂 /opt/tg-export (Telegram Parser)

**Size:** 104 MB  
**Purpose:** Parse Alexey Kolesov's Telegram channel  
**Proven uptime:** 7 days continuous (as of handoff 2026-04-24)

### Root Files

```
/opt/tg-export/
├── config.json5                    # Parser configuration
├── .env                            # API keys (TG_API_ID, XAI_API_KEY, BOT_TOKEN)
├── package.json                    # npm dependencies
├── library_index.json (273 KB)     # Full channel index (142 posts)
├── _status.json (295 B)            # Heartbeat state snapshot
├── announced.txt                   # New posts detected
├── ingested.txt                    # Posts ingested to LightRAG
├── p4_catalog.json (57 KB)         # P4 priority catalog
├── p4_whitelist.txt                # Manual P4 overrides
│
├── heartbeat.sh                    # Watchdog (auto-restart, log rotation)
├── heartbeat.log (54 KB)           # Heartbeat execution log
├── notify.sh                       # Telegram notifications every 2h
├── sync_channel.mjs                # Detect new posts + classify priority
├── sync.log (5.6 KB)               # Sync execution log
├── download.mjs                    # Priority download (P1-P4, human pacing)
├── download.log (11 KB)            # Download execution log
├── download.pid                    # Running process PID
├── enumerate_p4.mjs                # Re-prioritize posts to P4
├── transcribe.sh                   # Grok STT transcription
├── transcribe.log (66 KB)          # Transcribe execution log
├── transcribe.pid                  # Running process PID
├── ingest_transcripts.py           # Push transcripts → LightRAG
├── merge_transcripts.py            # Merge chunked transcripts
├── verify.sh                       # Health checks
└── verify.log (1.2 KB)             # Verification log
```

### Subdirectories

```
/opt/tg-export/
├── media/ (52 files)               # Downloaded media (mp4, wav, m4a, etc.)
├── transcripts/ (31 files)         # Grok STT transcripts (.transcript.txt + .json)
├── _chunks/                        # Chunked downloads for large files
├── _paperclip_unpacked/            # Unpacked archives from posts
│   ├── установка на сервер/
│   ├── установка локально/
│   └── __MACOSX/
├── _mcp_mail_eval/                 # Embedded git repo (MCP mail evaluation)
│   ├── src/, web/, deploy/, docs/, tests/, scripts/, examples/
│   ├── .claude/, .beads/, .codex/, .github/
│   └── third_party_docs/, screenshots/
└── node_modules/ (telegram, websocket, pako, debug, etc.)
```

### Proven Metrics (Production)

- **Uptime:** 7 days без ручного вмешательства
- **Downloads:** 52 files (P1: 27, P2: 7, P3: 16, P4: 2)
- **Transcripts:** 31 files, 7.18 hours audio
- **Grok STT cost:** $0.72
- **Auto-restarts:** 3 (all correct, 0 false positives)
- **Telegram notifications:** Every 2 hours

### Cron Jobs

```bash
*/10 * * * * bash /opt/tg-export/heartbeat.sh     # Every 10 min
0 */2 * * * bash /opt/tg-export/notify.sh         # Every 2 hours
```

---

## 📂 /opt/realty-portal (Main Project)

**Size:** 293 MB  
**Purpose:** Bali Real Estate Evaluator (MVP)  
**Phase:** Day 1 (architecture closed, skills generation in progress)

### Root Structure

```
/opt/realty-portal/
├── docker-compose.yml              # Network skeleton (realty_net)
├── .env (6.6 KB)                   # Env vars for all services
├── .env.example                    # Template
├── README.md                       # Project overview
├── RECOVERY.md                     # Disaster recovery guide
├── .mcp.json                       # MCP server config
└── .gitignore
```

### Subdirectories

```
/opt/realty-portal/
├── docs/                           # Documentation
│   ├── ilian-core-context.md       # Cold-start reference (read first!)
│   ├── architecture.md             # System architecture
│   ├── tool-architecture.md        # Tool design v1.0
│   ├── sales-comparison-logic.md   # Valuation logic v1.1
│   ├── indonesian-valuation-standards-reference.md
│   ├── decisions-log.md            # ADR (Architecture Decision Records)
│   ├── open-questions.md           # Pending questions
│   ├── secrets-policy.md           # Credential management
│   ├── server_inventory.md         # Server state tracking
│   ├── claude-code-mcp-setup.md    # MCP setup guide
│   └── school/                     # Canon training materials (empty)
│
├── skills/ (20 skills)             # Evaluation pipeline skills
│   ├── EVL-CTX-001/                # enrich_area_context
│   ├── EVL-CLS-002/                # classify_listing_subtype
│   ├── EVL-CLS-003/                # classify_condition
│   ├── EVL-NOR-004/                # normalize_address
│   ├── EVL-COMP-005/               # comp_filter
│   ├── EVL-COMP-006/               # comp_rank
│   ├── EVL-COMP-007/               # comp_adjust
│   ├── EVL-COMP-008/               # comp_weighted_average
│   ├── EVL-COMP-009/               # comp_confidence
│   ├── EVL-STAT-010/               # stats_spread
│   ├── EVL-STAT-011/               # stats_market_position
│   ├── EVL-LIQ-012/                # liquidity_score
│   ├── EVL-VAL-013/                # valuation_range
│   ├── EVL-LEG-014/                # legal_flags
│   ├── EVL-NAR-015/                # narrative_synthesis
│   ├── EVL-ORC-016/                # orchestrator
│   ├── normalize_listing/          # Utility: normalize raw scrape
│   ├── parse_listings_web/         # Utility: parse listing URLs
│   ├── search_properties/          # Utility: DB search
│   └── market_snapshot/            # Utility: latest market data
│
├── scrapers/                       # Web scrapers
│   ├── rumah123/ (Python)          # Main scraper (curl_cffi, Cloudflare bypass)
│   ├── olx_bali/ (dropped)         # Akamai blocked
│   ├── lamudi/
│   ├── balirealty/
│   └── .venv/                      # Python venv
│
├── frontend/                       # UI (placeholder)
│
├── scripts/                        # Utility scripts
│
├── lightrag/                       # LightRAG service config
│   ├── docker-compose.yml          # realty_lightrag + realty_litellm
│   ├── litellm_config.yaml         # LLM gateway config (Anthropic/Gemini/DeepSeek/Groq)
│   └── .env → /opt/realty-portal/.env
│
├── openclaw/                       # OpenClaw skill engine
│   └── docker-compose.yml          # realty_openclaw
│
├── supabase/                       # Supabase self-hosted stack
│   ├── docker-compose.override.yml
│   └── upstream/docker/            # 13 Supabase containers
│
├── backups/                        # DB backups
│
└── lightrag_docs/                  # LightRAG domain docs
```

### Database Schema (Supabase)

**Tables:**
- `raw_listings` — scraped data
- `properties` — normalized (73 columns)
- `market_snapshots` — area × tenure × subtype market data
- `sources` — scraper metadata (4 entries: rumah123, olx_bali, lamudi, balirealty)

**Helper functions:**
- `get_area_default(area)` — zone/FAR/KDB/social_bucket/subak_risk/parent_district
- `is_known_area(area)` → boolean
- `is_market_gap_fresh(area, tenure, subtype)` → boolean

**Red flags dictionary:** ~80 markers (legal, structural, environmental, market)

### Skills Architecture

**20 skills total:**
- **16 EVL-* skills:** evaluation pipeline (context → classify → normalize → comps → stats → liquidity → valuation → legal → narrative → orchestrate)
- **4 utility skills:** normalize_listing, parse_listings_web, search_properties, market_snapshot

**Skill format:** Each `/opt/realty-portal/skills/{skill_name}/` contains `SKILL.md` with:
- `name`, `description`, `catalog_id`, `revision`, `grade`, `phase`, `mission`
- `inputs`, `outputs`, `logic`, `calibration_type`, `source_doc`

**Orchestrator:** `EVL-ORC-016` — entry point, runs 15 skills in sequence.

### Scrapers

**Active:** `rumah123` (100% fill rate, curl_cffi impersonate chrome120)  
**Dropped:** `olx_bali` (Akamai Bot Manager, curl_cffi blocked)  
**Pending:** `lamudi`, `balirealty`

---

## 📂 /opt/mcp_agent_mail (MCP Mail Server)

**Size:** 340 MB  
**Purpose:** Mail-like coordination layer for coding agents  
**Status:** Under active development

### Root Structure

```
/opt/mcp_agent_mail/
├── README.md                       # Project overview
├── AGENTS.md (27 KB)               # Agent directory
├── AGENT_FRIENDLINESS_REPORT.md    # Agent UX analysis
├── CHANGELOG.md (45 KB)            # Version history
├── LICENSE
├── docker-compose.yml              # MCP server
├── Dockerfile
├── .dockerignore
├── .env (268 B)                    # Server config
├── .env.example
├── .envrc
├── compose.yaml
├── gh_og_share_image.png (190 KB)  # GitHub OG image
│
├── cline.mcp.json                  # Cline IDE config
├── codex.mcp.json                  # Codex config
├── cursor.mcp.json                 # Cursor IDE config
├── gemini.mcp.json                 # Gemini config
│
├── .claude/                        # Claude Code config
├── .beads/                         # Beads framework
├── .codex/                         # Codex framework
└── .git/                           # Git repo
```

### Subdirectories

```
/opt/mcp_agent_mail/
├── src/                            # Python source code
├── web/                            # Web UI
├── deploy/                         # Deployment scripts
├── docs/                           # Documentation
├── tests/                          # Test suite
├── scripts/                        # Utility scripts
├── examples/                       # Usage examples
├── third_party_docs/               # External docs
├── screenshots/                    # UI screenshots
├── .github/                        # GitHub Actions
└── git_mailbox_repo/               # Git-backed mailbox storage
```

**Features:**
- Mail-like inbox/outbox for agents
- Memorable agent identities
- Searchable message history
- File reservation "leases" (avoid conflicts)
- Git-backed artifacts (human-auditable)
- SQLite indexing

**Use case:** Coordinate multiple coding agents (backend, frontend, scripts, infra) without overwriting each other's work.

---

## 📂 /opt/containerd

**Size:** 12 KB  
**Purpose:** Docker runtime configuration  
**Contents:** Internal Docker config, not user-facing

---

## 📂 Root Home (~/)

```
/root/
├── .bash_history (20 KB)
├── .bashrc
├── .profile
├── .zshrc
├── download.pid                    # Stale PID file (tg-export moved to /opt)
├── .ssh/                           # SSH keys
├── .docker/                        # Docker CLI config
├── .npm/                           # npm cache
├── .cache/
├── .config/
├── .local/
├── .claude/                        # Claude Code config
└── .codex/                         # Codex config
```

---

## 🔑 Credentials & Secrets

**Locations:**
- `/opt/tg-export/.env` — Telegram API, Grok STT, Bot token
- `/opt/realty-portal/.env` (symlinked to `lightrag/.env`) — Anthropic API, Supabase creds, LLM keys
- `/opt/mcp_agent_mail/.env` — MCP server config
- `~/.ssh/` — SSH keys

**Never commit:** All `.env` files in `.gitignore`

**Backup:** User (Ilya) stores passwords locally; `.env.example` templates in each project

---

## 🛠️ System Resources

**CPU:** 2 vCPU  
**RAM:** 7.8 GB total, 4.0 GB used, 3.8 GB available  
**Swap:** 511 MB (unused)  
**Disk:** 59 GB total, 36 GB used (61%), 23 GB free

**Network:** realty_net (bridge) — shared by all realty_* containers

---

## 📋 Access Patterns

**SSH:** `ssh root@193.233.128.21`

**Common commands:**
```bash
# Docker stack
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker logs -f realty_openclaw
docker exec -it supabase-db psql -U postgres

# Telegram parser
cd /opt/tg-export
bash heartbeat.sh
bash notify.sh
node download.mjs 0 1 3      # Download P1-P3
tail -f download.log

# Realty Portal
cd /opt/realty-portal
cat docs/ilian-core-context.md
docker compose -f lightrag/docker-compose.yml ps

# MCP Mail
cd /opt/mcp_agent_mail
docker compose ps
```

---

## 🗂️ Quick Reference

**Telegram parser files:** `/opt/tg-export/{heartbeat,notify,sync_channel,download,transcribe}.{sh,mjs}`  
**Skills:** `/opt/realty-portal/skills/EVL-*/SKILL.md`  
**Core context:** `/opt/realty-portal/docs/ilian-core-context.md` ← **read first!**  
**DB:** `docker exec -it supabase-db psql -U postgres`  
**LightRAG API:** `http://127.0.0.1:9621/query`  
**OpenClaw API:** `http://127.0.0.1:18789/`

---

## 📚 Canon References

- **Simplicity-First Principle:** `C:\Users\97152\Documents\claude-library\kanon\simplicity-first-principle.md`
- **12 Principles:** `C:\Users\97152\Documents\claude-library\kanon\alexey-11-principles.md`
- **Telegram Parser Guide:** `C:\Users\97152\Documents\claude-library\troubleshoot\telegram-parser-recreation.md`
- **Heartbeat Pattern:** `C:\Users\97152\Documents\claude-library\navyki\heartbeat-telegram-pattern.md`

---

**Created:** 2026-04-24  
**Source:** SSH exploration of root@193.233.128.21  
**Maintainer:** AI agents working on Realty Portal  
**Update frequency:** On major infrastructure changes
