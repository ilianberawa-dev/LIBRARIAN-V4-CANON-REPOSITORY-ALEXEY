# PROJECT-INDEX — Universal Code Library

**Repository**: LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY  
**Branch**: claude/setup-library-access-FrRfh  
**Snapshot**: 2026-04-26  
**Purpose**: Canonical catalog of all implementation files with SHA verification references

---

## Stage 0.5 — Encrypted Credentials Vault

**Status**: ✅ Deployed to production  
**Canon Alignment**: Replaces .env files per Canon #6 (Secrets via systemd-creds), #11 (Privilege Isolation)

| File | Purpose | Type |
|------|---------|------|
| `stage-0.5/lib/vault.mjs` | Reads secrets from $CREDENTIALS_DIRECTORY, provides getSecret() + redact() | Core |
| `stage-0.5/install-safe-vault.sh` | Installer: creates credstore, systemd creds, adds LoadCredential to units | Install |
| `stage-0.5/KEYS-MAP.md` | Reference guide: secret names, migration from .env, troubleshooting | Docs |

**Key Functions**:
- `getSecret(name)` → reads from systemd credentials directory
- `redact(text)` → masks sk-ant-, xai-, bot tokens in logs

**Dependencies**: systemd 247+, systemd-creds, Node.js fs

---

## Stage 1 — Telegram Listener + SQLite State

**Status**: ✅ Deployed to production (with HOTFIX-2026-04-26 applied server-side)  
**Canon Alignment**: Canon #1 (Database single source), #2 (SQLite for MVP)

| File | Purpose | Type |
|------|---------|------|
| `stage-1/listener.mjs` | MTProto client, listens for owner messages, inserts to messages table | Worker |
| `stage-1/auth.mjs` | Interactive Telegram auth via phone/code | Setup |
| `stage-1/auth-qr.mjs` | Alternative: QR code auth flow | Setup |
| `stage-1/schema.sql` | SQLite schema v1.2: messages, drafts, brief_history, channel_config | Schema |
| `stage-1/install.sh` | Installer: schema init, systemd unit, auth flow | Install |
| `stage-1/personal-assistant-listener.service` | systemd unit for listener daemon | Service |
| `stage-1/HOTFIX-2026-04-26-listener-catchup.md` | Documents useWSS fix + catchUp behavior (server-only patch) | Hotfix |

**Schema Tables** (v1.2):
- `messages` (id, text, from_user_id, timestamp, processed)
- `drafts` (id, user_message_id, content, status) — missing voice_file_id, channel_message_id, status_finalized
- `brief_history` (id, summary, timestamp)
- `channel_config` (channel_id, chat_id, enabled)

**Known Issues**:
- M2: Schema drift (missing voice_jobs table, missing drafts columns)
- HOTFIX: catchUp + useWSS applied via nano/sed on server, not committed to repo (FLAG-3)

---

## Stage 2 — Triage Worker (Haiku)

**Status**: ✅ Deployed to production  
**Canon Alignment**: Canon #3 (AI workers stateless), #7 (Haiku for cheap tasks)

| File | Purpose | Type |
|------|---------|------|
| `stage-2/triage.mjs` | Polls messages table, classifies urgent/normal/defer, updates processed=1 | Worker |
| `stage-2/skills/triage.md` | Claude skill: classify message urgency | Skill |
| `stage-2/install-stage-2.sh` | Installer for triage service | Install |
| `stage-2/personal-assistant-triage.service` | systemd unit for triage daemon | Service |

**Triage Flow**: messages (processed=0) → Haiku classification → update processed=1

---

## Stage 2.5 — Cascade Reserve Router

**Status**: 🟡 Implemented, deployment pending  
**Canon Alignment**: Canon #8 (Graceful degradation)

| File | Purpose | Type |
|------|---------|------|
| `stage-2.5-cascade-reserve/router-cascade.mjs` | Falls back Haiku→Sonnet→Opus on rate limit or error | Router |
| `stage-2.5-cascade-reserve/skills/triage-haiku.md` | Haiku-specific triage skill variant | Skill |
| `stage-2.5-cascade-reserve/README-RESERVE.md` | Cascade fallback strategy documentation | Docs |

**Cascade Order**: Haiku (cheap) → Sonnet (balance) → Opus (heavy, last resort)

---

## Stage 3 — Draft Generator (Sonnet)

**Status**: ✅ Deployed to production (with HOTFIX-2026-04-26 applied server-side)  
**Canon Alignment**: Canon #3 (AI workers stateless), #4 (Sonnet for quality)

| File | Purpose | Type |
|------|---------|------|
| `stage-3/draft_gen.mjs` | Polls messages, generates draft reply, inserts to drafts table | Worker |
| `stage-3/skills/draft.md` | Claude skill: generate reply draft with context | Skill |
| `stage-3/install-stage-3.sh` | Installer for draft generator | Install |
| `stage-3/personal-assistant-draft-gen.service` | systemd unit for draft gen daemon | Service |
| `stage-3/HOTFIX-2026-04-26-need-context.md` | Documents brief_history context injection fix (server-only patch) | Hotfix |

**Draft Flow**: messages (processed=1) → Sonnet generates draft → insert drafts (status=pending)

**Known Issues**:
- HOTFIX: brief_history context injection applied via nano/sed on server, not committed (FLAG-3)

---

## Stage 3.5 — Brief Compiler (Daily Summary)

**Status**: ✅ Deployed to production  
**Canon Alignment**: Canon #3 (AI workers stateless), #9 (Daily aggregation)

| File | Purpose | Type |
|------|---------|------|
| `stage-3.5/brief_compiler.mjs` | Daily cron: aggregates messages → Sonnet summary → brief_history | Worker |
| `stage-3.5/skills/brief.md` | Claude skill: compile daily summary | Skill |
| `stage-3.5/install-stage-3.5.sh` | Installer for brief compiler | Install |
| `stage-3.5/personal-assistant-brief.service` | systemd timer unit for daily brief | Service |

**Brief Flow**: messages (last 24h) → Sonnet summary → insert brief_history

---

## Stage 4 — Bot + Sender (User Interface)

**Status**: ✅ Deployed to production  
**Canon Alignment**: Canon #0 (Simplicity first), #10 (Telegram as UI)

| File | Purpose | Type |
|------|---------|------|
| `stage-4/bot.mjs` | node-telegram-bot-api: handles /commands, voice, reviews drafts | Bot |
| `stage-4/sender.mjs` | Polls drafts (status=approved), sends to channel, updates status=sent | Worker |
| `stage-4/install-stage-4.sh` | Installer for bot + sender services | Install |
| `stage-4/personal-assistant-bot.service` | systemd unit for bot daemon | Service |
| `stage-4/personal-assistant-sender.service` | systemd unit for sender daemon | Service |

**Bot Commands**:
- `/start`, `/help`, `/status` — info commands
- `/test_voice` — trigger voice recording state
- Voice handler — routes to Stage 5 voice_jobs OR Stage 4 await_voice (draft attachment)

**Sender Flow**: drafts (status=approved) → send to channel → update status=sent

**Known Issues**:
- B2: Missing voice_jobs INSERT for owner voice commands (only handles await_voice for draft attachments)
- M1: Hardcoded OWNER_TG_ID in multiple functions, should extract to config

---

## Stage 5 — Voice Intent Parser (Grok STT + Claude)

**Status**: 🟡 Code complete, deployment blocked (4 blockers)  
**Canon Alignment**: Canon #5 (External APIs stateless)

| File | Purpose | Type |
|------|---------|------|
| `stage-5/voice.mjs` | Polls voice_jobs, Grok STT → Claude intent parsing → insert to messages | Worker |
| `stage-5/skills/voice_intent.md` | Claude skill: parse voice transcription into structured command | Skill |
| `stage-5/install-stage-5.sh` | Installer for voice service + transcribe.sh dependency | Install |
| `stage-5/personal-assistant-voice.service` | systemd unit for voice worker daemon | Service |
| `(missing) transcribe.sh` | Grok API wrapper: .oga → transcribed text | External |

**Voice Flow**: voice_jobs (status=pending) → transcribe.sh (Grok STT) → Claude intent parsing → insert messages

**Known Blockers** (from REPORT-2026-04-26):
- **B1**: Uses `process.env.ANTHROPIC_API_KEY` instead of `getSecret('anthropic-api-key')` (voice.mjs:7,16-22,48)
- **B2**: Stage 4 bot.mjs missing voice_jobs INSERT for owner voice commands (only routes await_voice)
- **B3**: install-stage-5.sh never copies fresh transcribe.sh from repo (lines 26-37 broken logic)
- **B4**: systemd unit uses EnvironmentFile=/opt/personal-assistant/.env, missing LoadCredentialEncrypted

---

## Documentation Files

**Architecture & Canon**:
- `alexey-materials/alexey-11-principles.md` — 12 canon principles (#0-#11), definitive source
- `alexey-materials/alexey-consultation-2026-04-24-agent-canon.md` — Architect's consultation on orchestration
- `metody/personal-ai-assistant/v1.1-mvp-simplified.md` — TZ for MVP stages 0.5-5
- `metody/personal-ai-assistant/ORCHESTRATION-LESSONS-2026-04-25.md` — 7 orchestration invariants (IV-1 through IV-7)

**Agent Prompts**:
- `metody/personal-ai-assistant/FOREMAN-PROMPT.md` — L-2 Прораб (foreman) role charter
- `metody/personal-ai-assistant/INSTALLER-TEMPLATE.md` — Install/deploy workflow template

**Operations**:
- `metody/personal-ai-assistant/INSTALLATION-PLAN.md` — Multi-stage deployment plan
- `metody/personal-ai-assistant/CHANGELOG.md` — Production change log
- `metody/personal-ai-assistant/AUDIT-2026-04-24.md` — Previous code audit

---

## Git Verification

**Current HEAD**: `ad1fd13` (docs(stage-0.5): expand KEYS-MAP with troubleshooting + migration guide)

To verify file integrity:
```bash
git ls-files metody/personal-ai-assistant/implementation/ | xargs git hash-object
```

To check specific file SHA:
```bash
git hash-object metody/personal-ai-assistant/implementation/stage-5/voice.mjs
```

**Canonical Branch**: `claude/setup-library-access-FrRfh`  
**Remote**: `origin/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY`

---

## Usage for New Agents

When joining project:
1. **Verify branch**: `git rev-parse HEAD` should match snapshot reference above
2. **Integrity check**: Run `git status` — should show clean working tree
3. **Read canon sources**: alexey-11-principles.md (12 principles), ORCHESTRATION-LESSONS (7 invariants)
4. **Read TZ**: v1.1-mvp-simplified.md for stage requirements
5. **Check deployment status**: CHANGELOG.md for production state
6. **Review blockers**: Search this index for "Known Issues" and "Known Blockers"

**CRITICAL**: Always `git checkout claude/setup-library-access-FrRfh` and `git pull origin` before making changes. Per INVARIANT #1, git repository on canonical branch = single source of truth.

---

*Generated 2026-04-26 for teleport handoff — L-1.5 Канон-Контроль → новый агент*
