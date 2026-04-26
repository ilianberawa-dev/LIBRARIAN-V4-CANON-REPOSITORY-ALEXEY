# TASK-AMENDMENT-2026-04-26 — Review Findings Resolution

**Amendment To**: TASK-2026-04-26-deploy-0.5-0.6-5.md (Big TZ)  
**Authority**: L-1 Architect approval 2026-04-26  
**Scope**: Blocks found by L-1.5 Канон-Контроль review of Groups A-E  
**Status**: APPROVED — architectural prescription ready for L-3 implementation

---

## Amendment Purpose

Review REPORT-2026-04-26-initial-audit.md identified **4 BLOCKERS** preventing Stage 5 deployment, plus 2 MAJORS and 1 UNCLEAR requiring resolution. This amendment documents approved fixes per INVARIANT #1 (git = source of truth for all decisions).

---

## BLOCKERS — Must Fix Before Stage 5 Deploy

### B1: voice.mjs Uses process.env Instead of getSecret()

**Location**: `stage-5/voice.mjs:7,16-22,48`

**Violation**: Canon #6 (Secrets via systemd-creds)

**Current Code**:
```javascript
import 'dotenv/config';
// ...
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
```

**Prescribed Fix**:
```javascript
import { getSecret } from '../stage-0.5/lib/vault.mjs';
// ...
const anthropic = new Anthropic({ apiKey: await getSecret('anthropic-api-key') });
```

**Impact**: Align Stage 5 with vault infrastructure (Stage 0.5), remove dotenv dependency

**Assigned To**: L-3 Worker

---

### B2: bot.mjs Missing voice_jobs INSERT for Owner Commands

**Location**: `stage-4/bot.mjs:359-394` (voice handler)

**Violation**: Canon #1 (Database = single source of truth)

**Current Behavior**: Voice handler only processes `await_voice` state (draft attachments). Owner voice commands sent outside draft context are acknowledged but NOT inserted to voice_jobs table.

**Prescribed Fix** (Interpretation b — approved by Architect):

Preserve existing `await_voice` logic for draft attachments, ADD new branch for owner voice commands:

```javascript
bot.on('voice', async (msg) => {
  const userId = msg.from.id;
  if (userId !== OWNER_TG_ID) return;
  if (msg.chat.id !== userId) return;
  
  const state = getState(userId);
  
  // Branch 1: Draft attachment (existing logic)
  if (state && state.action === 'await_voice') {
    // ... existing await_voice logic (attach to draft) ...
    return;
  }
  
  // Branch 2: Owner voice command (NEW)
  const fileId = msg.voice.file_id;
  const db = getDb();
  db.run(
    `INSERT INTO voice_jobs (file_id, status, created_at) VALUES (?, 'pending', datetime('now'))`,
    [fileId],
    (err) => {
      if (err) {
        bot.sendMessage(userId, '❌ Ошибка сохранения voice job');
        console.error('voice_jobs INSERT error:', err);
      } else {
        bot.sendMessage(userId, '🎙 Voice команда принята, обрабатывается...');
      }
    }
  );
});
```

**Schema Dependency**: Requires voice_jobs table (see M2 fix)

**Impact**: Enables owner voice commands outside draft context (Stage 5 intent parsing)

**Assigned To**: L-3 Worker

---

### B3: install-stage-5.sh Never Copies Fresh transcribe.sh

**Location**: `stage-5/install-stage-5.sh:26-37`

**Violation**: Canon #1 (Git = source of truth), deployment integrity

**Current Code**:
```bash
if [[ ! -f "${APP_DIR}/transcribe.sh" ]]; then
  if [[ -f /opt/tg-export/transcribe.sh ]]; then
    install ... /opt/tg-export/transcribe.sh "${APP_DIR}/transcribe.sh"
  else
    echo 'WARN: transcribe.sh not found...'
  fi
fi
```

**Problem**: 
- Only copies if file doesn't exist (`[[ ! -f ]]`)
- Checks wrong source (`/opt/tg-export/` instead of `${SRC_DIR}/`)
- Never updates stale script on re-install

**Prescribed Fix**:
```bash
# Unconditional copy from repo source
if [[ -f "${SRC_DIR}/stage-5/transcribe.sh" ]]; then
  install -m 755 "${SRC_DIR}/stage-5/transcribe.sh" "${APP_DIR}/transcribe.sh"
  echo "transcribe.sh installed from ${SRC_DIR}"
else
  echo "ERROR: ${SRC_DIR}/stage-5/transcribe.sh not found in repository"
  exit 1
fi
```

**Impact**: Ensures fresh transcribe.sh on every install, prevents stale script bugs

**Severity Escalation**: Originally marked Minor in HANDOFF, escalated to BLOCKER by Architect (deployment-critical)

**Assigned To**: L-3 Worker

---

### B4: systemd Unit Uses EnvironmentFile Instead of Vault

**Location**: `stage-5/personal-assistant-voice.service:11`

**Violation**: Canon #6 (Secrets via systemd-creds), #11 (Privilege Isolation)

**Current Config**:
```ini
EnvironmentFile=/opt/personal-assistant/.env
```

**Prescribed Fix**:
```ini
LoadCredentialEncrypted=xai-api-key:/etc/credstore.encrypted/xai-api-key.cred
LoadCredentialEncrypted=anthropic-api-key:/etc/credstore.encrypted/anthropic-api-key.cred
```

**Additional**: Remove `EnvironmentFile` line entirely

**Impact**: Aligns Stage 5 systemd unit with Stage 0.5 vault infrastructure

**Deployment Note**: L-2 Foreman must run `install-safe-vault.sh` to create credentials before installing Stage 5

**Assigned To**: L-3 Worker (fix .service file), L-2 Foreman (deploy vault first)

---

## MAJORS — Should Fix Before Production

### M1: Hardcoded OWNER_TG_ID in bot.mjs

**Location**: `stage-4/bot.mjs` (multiple functions)

**Violation**: Canon #0 (Simplicity First — but hardcoded values create drift risk)

**Current**: `const OWNER_TG_ID = 123456789;` (example)

**Prescribed Fix**:

**Option A** (Recommended): Move to database
```sql
CREATE TABLE IF NOT EXISTS config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
INSERT INTO config (key, value) VALUES ('owner_tg_id', '123456789');
```

```javascript
function getOwnerId() {
  const row = db.get('SELECT value FROM config WHERE key = ?', ['owner_tg_id']);
  return parseInt(row.value, 10);
}
```

**Option B** (Simpler): Move to systemd Environment
```ini
[Service]
Environment="OWNER_TG_ID=123456789"
```

**Architect Preference**: Option A (database = single source per Canon #1)

**Impact**: Centralizes config, prevents hardcoded drift across stages

**Priority**: MAJOR (not blocking deploy, but should fix before production scale)

**Assigned To**: L-3 Worker

---

### M2: Schema Drift — Missing voice_jobs Table + drafts Columns

**Location**: `stage-1/schema.sql` (v1.2)

**Violation**: Canon #1 (Database schema must match runtime state)

**Missing Elements**:

1. **voice_jobs table** (required for Stage 5):
```sql
CREATE TABLE IF NOT EXISTS voice_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  transcription TEXT,
  intent_result TEXT,
  created_at TEXT,
  processed_at TEXT
);
```

2. **drafts table columns** (used in production but not in schema):
```sql
ALTER TABLE drafts ADD COLUMN voice_file_id TEXT;
ALTER TABLE drafts ADD COLUMN channel_message_id INTEGER;
ALTER TABLE drafts ADD COLUMN status_finalized INTEGER DEFAULT 0;
```

**Prescribed Fix**:

Create `stage-1/migrations/001-add-voice-support.sql`:
```sql
-- Migration: Add Stage 5 voice support
-- Version: 1.2 → 1.3
-- Date: 2026-04-26

-- Add voice_jobs table for Stage 5 worker
CREATE TABLE IF NOT EXISTS voice_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  transcription TEXT,
  intent_result TEXT,
  created_at TEXT,
  processed_at TEXT
);

-- Add missing columns to drafts table
ALTER TABLE drafts ADD COLUMN voice_file_id TEXT;
ALTER TABLE drafts ADD COLUMN channel_message_id INTEGER;
ALTER TABLE drafts ADD COLUMN status_finalized INTEGER DEFAULT 0;

-- Update schema version
UPDATE schema_version SET version = '1.3', updated_at = datetime('now');
```

**Deployment**:
```bash
sqlite3 /opt/personal-assistant/assistant.db < stage-1/migrations/001-add-voice-support.sql
```

**Impact**: Reconciles schema with production state, enables Stage 5 deploy

**Assigned To**: L-3 Worker (create migration), L-2 Foreman (apply to production DB)

---

## UNCLEAR RESOLUTIONS

### U1: Voice Handler Interpretation

**Question**: Should voice handler INSERT voice_jobs for ALL owner voice, or only outside await_voice state?

**Architect Decision**: **Interpretation (b)** — Preserve both paths

**Rationale**:
- `await_voice` state = user explicitly requested voice attachment to draft → attach to draft (existing logic)
- No active state = owner voice command → route to Stage 5 intent parser via voice_jobs (new branch)

**Implementation**: See B2 prescribed fix above

**Status**: ✅ RESOLVED

---

## Implementation Order

### Phase 1: Schema (M2)
1. L-3 creates migration file `001-add-voice-support.sql`
2. L-2 applies migration to dev DB, verifies
3. L-2 applies migration to production DB

### Phase 2: Code Fixes (B1, B2, B4)
1. L-3 fixes voice.mjs (B1) — import vault, use getSecret()
2. L-3 fixes bot.mjs (B2) — add voice_jobs INSERT branch
3. L-3 fixes personal-assistant-voice.service (B4) — use LoadCredentialEncrypted

### Phase 3: Installer Fix (B3)
1. L-3 fixes install-stage-5.sh — unconditional transcribe.sh copy from SRC_DIR

### Phase 4: Config Refactor (M1) — Optional
1. L-3 moves OWNER_TG_ID to database config table
2. L-3 updates bot.mjs to read from config table

### Phase 5: Verification
1. L-1.5 re-reviews Groups B, D (voice.mjs, bot.mjs) for canon compliance
2. L-2 deploys Stage 5 to dev environment
3. L-2 tests voice command flow: owner voice → voice_jobs → transcribe.sh → voice.mjs → messages
4. If tests pass → L-2 deploys to production

---

## Acceptance Criteria

### Stage 5 Deploy Unblocked When:
- ✅ voice.mjs uses getSecret() (B1 fixed)
- ✅ bot.mjs inserts voice_jobs for owner commands (B2 fixed)
- ✅ install-stage-5.sh copies fresh transcribe.sh (B3 fixed)
- ✅ systemd unit uses LoadCredentialEncrypted (B4 fixed)
- ✅ voice_jobs table exists in production DB (M2 fixed)
- ✅ L-1.5 review shows 0 blockers for Groups B, D

### Production-Ready When:
- ✅ All above criteria met
- ✅ OWNER_TG_ID centralized (M1 fixed)
- ✅ drafts columns added (M2 fixed)
- ✅ Dev testing confirms voice flow works end-to-end

---

## Rollback Plan

If Stage 5 deploy fails after fixes:

1. **Stop voice service**: `systemctl stop personal-assistant-voice`
2. **Check logs**: `journalctl -u personal-assistant-voice -n 50`
3. **Verify transcribe.sh**: Test manually with sample .oga file
4. **Verify credentials**: `ls -la $CREDENTIALS_DIRECTORY` (should show xai-api-key, anthropic-api-key)
5. **If critical failure**: Leave service stopped, escalate to L-1 Architect
6. **If minor issue**: Fix and restart without rollback

**Database rollback** (if migration causes issues):
```bash
# Backup first
cp /opt/personal-assistant/assistant.db /opt/personal-assistant/assistant.db.backup-pre-v1.3

# Rollback (if needed)
sqlite3 /opt/personal-assistant/assistant.db <<EOF
DROP TABLE IF EXISTS voice_jobs;
-- Note: Cannot drop columns in SQLite, would need to recreate table
EOF
```

---

## Change Log

| Date | Change | Authority |
|------|--------|-----------|
| 2026-04-26 | Initial amendment created from REPORT-2026-04-26-initial-audit.md findings | L-1 Architect |
| 2026-04-26 | B3 severity escalated from Minor → BLOCKER | L-1 Architect |
| 2026-04-26 | U1 resolved as interpretation (b) | L-1 Architect |
| 2026-04-26 | M1 fix option chosen: database config (Option A) | L-1 Architect |

---

*Amendment approved 2026-04-26 — canonical per INVARIANT #1*
