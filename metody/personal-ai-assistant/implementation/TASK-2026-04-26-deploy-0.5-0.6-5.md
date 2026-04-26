# TASK 2026-04-26 — 3-part deploy for Worker

**Branch:** `claude/setup-library-access-FrRfh`
**Author:** Architect (relayed via Foreman)
**Scope:** Stage 0.5 deploy + Stage 0.6 migration + Stage 5 deploy with bot voice_jobs integration.

---

## Context

- Stage 0.5 (vault) and Stage 5 (voice) code is already in repo — ready to deploy.
- Grok key was created and is stored in current `.env` as `XAI_API_KEY` AND `GROK_API_KEY` (same value).
- On UpCloud currently active: `listener`, `triage`, `draft-gen`, `brief`, `bot`, `sender` — all read secrets from `/opt/personal-assistant/.env`.
- Goal: deploy vault, migrate services to it, deploy voice, integrate bot.mjs with `voice_jobs`.

**Canon:** #0 Simplicity, #5 Fail Loud, #6 Single Vault, #11 Privilege Isolation.
**INVARIANT #1:** git = single source of truth — every commit pushed to `origin claude/setup-library-access-FrRfh`.

---

## Part 1 — Stage 0.5 Deploy (vault infrastructure)

### 1.1 Install vault infrastructure

On UpCloud server:

```bash
cd /tmp && rm -rf safe-vault-deploy
git clone -b claude/setup-library-access-FrRfh \
  https://github.com/ilianberawa-dev/librarian-v4-canon-repository-alexey \
  safe-vault-deploy
sudo bash /tmp/safe-vault-deploy/metody/personal-ai-assistant/implementation/stage-0.5/install-safe-vault.sh
```

Should create:
- `/etc/credstore.encrypted/` (root:root 0700, empty)
- `/etc/personal-assistant/config.env` (root:personal-assistant 0640)
- `/opt/personal-assistant/lib/vault.mjs` (personal-assistant:personal-assistant 0640)

### 1.2 Fill `/etc/personal-assistant/config.env` with real non-secrets

Copy from current `/opt/personal-assistant/.env` everything that is NOT a secret:

```
DB_PATH=/opt/personal-assistant/assistant.db
OWNER_TG_ID=<real from old .env>
TG_API_ID=<real>
POLL_INTERVAL_MS=2000
TRIAGE_POLL_MS=2000
VOICE_POLL_MS=3000
VOICE_INBOX=/opt/personal-assistant/voice_inbox
LOG_LEVEL=info
MONTHLY_BUDGET_USD=22
CHANNEL_CHAT_ID=<real, for voice posting>
TG_PHONE=<if used>
```

### 1.3 Deposit 5 keys via PowerShell (from owner Windows machine)

```powershell
.\vault-deposit.ps1 -KeyName anthropic-api-key
.\vault-deposit.ps1 -KeyName bot-token
.\vault-deposit.ps1 -KeyName tg-api-hash
.\vault-deposit.ps1 -KeyName tg-session-string
.\vault-deposit.ps1 -KeyName xai-api-key
```

Verify: `.\vault-list.ps1` should show 5 `*.cred` files in `/etc/credstore.encrypted/`.

### Acceptance Part 1

- [ ] `ls /etc/credstore.encrypted/` shows 5 `.cred` files
- [ ] `cat /etc/personal-assistant/config.env` contains all non-secrets
- [ ] `ls /opt/personal-assistant/lib/vault.mjs` exists
- [ ] Existing 6 services keep running on old `.env` (migration is in Part 2)

---

## Part 2 — Stage 0.6 Migration (services migrate to vault)

Create directory `metody/personal-ai-assistant/implementation/stage-0.6/` with:

### 2.1 Patch each of 6 services

For each service: 2 files — `<service>.mjs.patch` (code change) and `<service>.service` (new unit).

**Template `.mjs` changes:**

Remove:
```javascript
import 'dotenv/config';
```

Add at top (after imports):
```javascript
import { getSecret } from './lib/vault.mjs';
```

Replace each secret read:
```javascript
// BEFORE: const KEY = process.env.ANTHROPIC_API_KEY;
const KEY = getSecret('anthropic-api-key');
```

Do NOT touch `process.env.DB_PATH`, `process.env.OWNER_TG_ID`, `process.env.POLL_INTERVAL_MS`, etc — these are non-secrets from `config.env`.

**Template unit file (triage example):**

```ini
[Unit]
Description=Personal AI Assistant — Triage Worker
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=personal-assistant
Group=personal-assistant
WorkingDirectory=/opt/personal-assistant

EnvironmentFile=/etc/personal-assistant/config.env

LoadCredentialEncrypted=anthropic-api-key:/etc/credstore.encrypted/anthropic-api-key.cred

ExecStart=/usr/bin/node /opt/personal-assistant/triage.mjs

Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=personal-assistant-triage

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
MemoryMax=300M

[Install]
WantedBy=multi-user.target
```

### 2.2 Per-service mapping (what to patch)

Use the table from `KEYS-MAP.md`:

| Service       | Credentials                                  | .mjs changes                                                          |
|---------------|----------------------------------------------|-----------------------------------------------------------------------|
| listener      | tg-api-hash, tg-session-string               | TG_API_HASH, TG_SESSION_STRING → getSecret(...)                       |
| triage        | anthropic-api-key                            | ANTHROPIC_API_KEY → getSecret('anthropic-api-key')                    |
| draft-gen     | anthropic-api-key                            | same                                                                  |
| brief         | anthropic-api-key                            | same                                                                  |
| bot           | bot-token, anthropic-api-key                 | BOT_TOKEN, ANTHROPIC_API_KEY → getSecret(...)                         |
| sender        | bot-token, tg-api-hash, tg-session-string    | three replacements                                                    |

### 2.3 Migration installer

Idempotent script:
1. Verify Stage 0.5 deployed (`/etc/credstore.encrypted/`, `/etc/personal-assistant/config.env`, `/opt/personal-assistant/lib/vault.mjs` all present)
2. Verify 5 keys in vault: `ls /etc/credstore.encrypted/*.cred | wc -l == 5`
3. Backup: `cp -a /opt/personal-assistant /opt/personal-assistant.pre-0.6.$(date +%s)`
4. Backup units: `cp /etc/systemd/system/personal-assistant-*.service /tmp/units-pre-0.6/`
5. Deploy updated `.mjs` files
6. Deploy updated `.service` files
7. `systemctl daemon-reload`
8. Restart each service one by one, verify `is-active` and last 2 minutes of journal for absence of fatal errors:

```bash
for svc in listener triage draft-gen brief bot sender; do
  systemctl restart personal-assistant-$svc
  sleep 5
  systemctl is-active personal-assistant-$svc || {
    echo "FAIL: $svc"
    journalctl -u personal-assistant-$svc -n 30 --no-pager
    exit 1
  }
done
```

9. Final check: in last 5 minutes of logs there are NO lines with `vault_not_initialized`, `vault_secret_missing`, `missing_env`.

### 2.4 Cleanup (only after successful 2.3)

```bash
# Archive backup of .env (in case rollback needed)
sudo install -o root -g root -m 0600 /opt/personal-assistant/.env \
  /root/.env.pre-0.6.archive.$(date +%s)
# Remove active .env
sudo rm /opt/personal-assistant/.env
```

Then restart all services again — they should work without `.env`. If anything fails, restore from `/root/.env.pre-0.6.archive.*` and investigate.

### 2.5 Audit

```bash
grep -RnE 'process\.env\.(ANTHROPIC_API_KEY|BOT_TOKEN|TG_API_HASH|TG_SESSION_STRING|XAI_API_KEY|GROK_API_KEY)' /opt/personal-assistant/*.mjs
# Expected: empty
```

### Acceptance Part 2

- [ ] `/opt/personal-assistant/.env` removed
- [ ] All 6 services `is-active`
- [ ] 5 minutes after restart: 0 fatal errors about vault/secret/env
- [ ] grep audit (2.5) — empty output
- [ ] Commit in repo: `feat(stage-0.6): migrate services to systemd-creds vault`

---

## Part 3 — Stage 5 Deploy + bot.mjs voice_jobs integration

### 3.1 Adapt voice.mjs for vault (worker, in repo)

In `voice.mjs`:

Remove:
```javascript
import 'dotenv/config';
const REQUIRED_ENV = ['ANTHROPIC_API_KEY', 'BOT_TOKEN', 'CHANNEL_CHAT_ID', 'GROK_API_KEY'];
for (const key of REQUIRED_ENV) { ... process.env[key] ... }
```

Add:
```javascript
import { getSecret } from './lib/vault.mjs';

const ANTHROPIC_API_KEY = getSecret('anthropic-api-key');
const BOT_TOKEN = getSecret('bot-token');
const XAI_API_KEY = getSecret('xai-api-key');
const CHANNEL_CHAT_ID = process.env.CHANNEL_CHAT_ID; // non-secret
if (!CHANNEL_CHAT_ID) { /* fail loud */ }
```

Replace all `process.env.GROK_API_KEY` / `process.env.ANTHROPIC_API_KEY` / `process.env.BOT_TOKEN` with the local constants above.

In transcribe call:
```javascript
env: { ...process.env, XAI_API_KEY, GROK_API_KEY: XAI_API_KEY }
```
(duplication so old `transcribe.sh` interface keeps working).

### 3.2 Adapt voice service unit

`personal-assistant-voice.service`:

```ini
EnvironmentFile=/etc/personal-assistant/config.env

LoadCredentialEncrypted=xai-api-key:/etc/credstore.encrypted/xai-api-key.cred
LoadCredentialEncrypted=anthropic-api-key:/etc/credstore.encrypted/anthropic-api-key.cred
LoadCredentialEncrypted=bot-token:/etc/credstore.encrypted/bot-token.cred
```
(remove old `EnvironmentFile=/opt/personal-assistant/.env`)

### 3.3 NEW: bot.mjs voice_jobs integration

In `bot.mjs` add logic:

When `bot.on('voice', msg)` → check `msg.from.id === OWNER_TG_ID`:

If owner — this is a voice command:
1. `getFile` from Bot API → download .ogg to `/tmp/pa-voice/voice_${msg.message_id}.ogg`
2. `INSERT INTO voice_jobs (file_id, file_path, status) VALUES (?, ?, 'pending')`
3. Ack: `bot.sendMessage(OWNER_TG_ID, '🎙 Команда принята, обрабатываю...')`

If NOT owner (a contact sent voice to owner): existing "live forward" logic should NOT change — that voice goes through normal inline-keyboard card with Send/Edit/Voice/Ignore/Mute (Stage 4). If already works, do not touch.

Schema migration (if not done):

```sql
-- add to schema.sql or as separate migration
CREATE TABLE IF NOT EXISTS voice_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id TEXT NOT NULL,
  file_path TEXT,
  received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  transcript TEXT,
  intent TEXT,
  args_json TEXT,
  action_result TEXT,
  status TEXT DEFAULT 'pending',
  error TEXT
);
```

(Even though voice.mjs creates this table via `CREATE TABLE IF NOT EXISTS` at startup — better to have a single canonical place in schema.sql.)

### 3.4 Deploy on server

```bash
cd /tmp && rm -rf stage-5-deploy
git clone -b claude/setup-library-access-FrRfh \
  https://github.com/ilianberawa-dev/librarian-v4-canon-repository-alexey \
  stage-5-deploy
sudo bash /tmp/stage-5-deploy/metody/personal-ai-assistant/implementation/stage-5/install-stage-5.sh
```

Installer copies:
- `voice.mjs` → `/opt/personal-assistant/voice.mjs`
- `skills/voice_intent.md` → `/opt/personal-assistant/skills/voice_intent.md`
- `transcribe.sh` → `/opt/personal-assistant/transcribe.sh`
- `personal-assistant-voice.service` → `/etc/systemd/system/`

Verify `transcribe.sh` is copied correctly (new, not from `/opt/tg-export/`). If install-stage-5.sh prefers `/opt/tg-export/transcribe.sh` as fallback, fix to take `${SRC_DIR}/transcribe.sh` as primary.

```bash
sudo systemctl daemon-reload
sudo systemctl restart personal-assistant-bot       # picks up voice_jobs patch
sudo systemctl start personal-assistant-voice
sudo systemctl is-active personal-assistant-voice
```

### 3.5 End-to-end test

Owner sends voice message to bot in DM: «Поиск Маша»

Expected chain:
1. `bot.mjs` receives voice → writes to `voice_jobs` (status='pending')
2. `bot.mjs` replies: «🎙 Команда принята...»
3. `voice.mjs` polls → finds job → downloads file → `transcribe.sh` → "Поиск Маша"
4. `voice.mjs` → Anthropic intent parse → `{"intent":"search","args":{"query":"Маша"}}`
5. `voice.mjs` → `actSearch` → FTS query → post to `CHANNEL_CHAT_ID`: `🎙 Поиск «Маша» — top N: ...`

Verify via DB:

```bash
sqlite3 /opt/personal-assistant/assistant.db \
  "SELECT id, status, transcript, intent, action_result FROM voice_jobs ORDER BY id DESC LIMIT 1;"
```

Should be: status=`done`, transcript≠NULL, intent=`search`, action_result contains `found_*`.

### Acceptance Part 3

- [ ] `voice.mjs` uses `vault.getSecret` (not `process.env` for secrets)
- [ ] `personal-assistant-voice.service` has 3 `LoadCredentialEncrypted=`
- [ ] `bot.mjs` writes owner voice to `voice_jobs`
- [ ] End-to-end test "Поиск Маша" passes through to status=done
- [ ] Commit: `feat(stage-5): vault integration + bot voice_jobs`

---

## Cross-cutting requirements

- Each part = separate commit in `claude/setup-library-access-FrRfh`. Minimum 3 commits: deploy-0.5, migrate-0.6, deploy-5.
- After each part — push to origin. Do not pile up locally on `main`.
- On any fatal log on UpCloud — STOP, debug, do not proceed further.
- Do not touch anything outside this task scope. If you find a bug in Stage 1 catchUp — that is `HOTFIX-2026-04-26-listener-catchup.md` task, not this one.
- Backup before every destructive operation (rm .env, daemon-reload, restart).

## Final report (after all 3 parts)

Send to architect:

1. SHA of final commits (minimum 3)
2. Output of `systemctl is-active personal-assistant-{listener,triage,draft-gen,brief,bot,sender,voice}` — should be 7 lines `active`
3. Output of "Поиск Маша" test from 3.5 (sqlite query)
4. Confirmation: `/opt/personal-assistant/.env` does NOT exist

## Start

Begin with Part 1 (deploy 0.5). After acceptance of Part 1 — proceed to Part 2. Do not skip steps.
