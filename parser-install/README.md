# Telegram Parser Install Package

**Version:** 2.0 (with PR #6 fixes)  
**Size:** ~50 KB  
**Target:** Fresh server deployment

---

## 📦 What's Included

```
parser-install/
├── scripts/               9 parser scripts (with fixes)
│   ├── sync_channel.mjs   ✅ msg.media fallback (PR #6)
│   ├── heartbeat.sh       ✅ MIN_PRIO/MAX_PRIO env (PR #6)
│   ├── download.mjs
│   ├── enumerate_p4.mjs
│   ├── transcribe.sh
│   ├── notify.sh
│   ├── verify.sh
│   ├── ingest_transcripts.py
│   └── merge_transcripts.py
│
├── config/                Config templates (no secrets)
│   ├── .env.example
│   ├── config.json5.example
│   ├── package.json
│   └── package-lock.json
│
├── cron.example           Crontab lines
├── github-sync.sh         Auto-sync to GitHub
├── install.sh             One-command deployment
└── README.md              This file
```

---

## 🚀 Quick Start (5 minutes)

### Prerequisites
- Ubuntu/Debian server (2GB RAM, 5GB disk)
- Node.js 18+ (`curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt install -y nodejs`)
- ffmpeg (`sudo apt install -y ffmpeg`)
- jq (`sudo apt install -y jq`)

### Installation

```bash
# 1. Upload this folder to server
scp -r parser-install/ root@YOUR_SERVER:/tmp/

# 2. SSH to server
ssh root@YOUR_SERVER

# 3. Run install script
cd /tmp/parser-install
bash install.sh

# Output:
#   ✓ Created /opt/tg-export/
#   ✓ Copied 9 scripts
#   ✓ Created config templates
#   ✓ npm install complete
#   ⚠️  Manual steps required (see below)
```

---

## 🔧 Manual Configuration

### Step 1: Fill API Keys

Edit `/opt/tg-export/.env`:

```bash
nano /opt/tg-export/.env
```

Fill with real values:

```env
# xAI Grok API (for transcription)
# Get from: https://console.x.ai/team/api-keys
XAI_API_KEY=xai-YOUR_KEY_HERE

# Telegram Bot (for notifications)
# Create: @BotFather → /newbot
BOT_TOKEN=1234567890:YOUR_BOT_TOKEN_HERE

# Your Telegram chat ID
# Get: @userinfobot → /start
CHAT_ID=YOUR_CHAT_ID_HERE
```

### Step 2: Fill Telegram API Credentials

1. Go to https://my.telegram.org/auth
2. Login with phone number
3. Go to "API development tools"
4. Create app (any name)
5. Copy `api_id` and `api_hash`

Edit `/opt/tg-export/config.json5`:

```bash
nano /opt/tg-export/config.json5
```

```json5
{
  apiId: 12345678,  // ← paste your api_id
  apiHash: 'a1b2c3d4e5f6...',  // ← paste your api_hash
  sessionString: ''  // ← leave empty for now
}
```

### Step 3: Generate Session

Run sync once to create Telegram session:

```bash
cd /opt/tg-export
node sync_channel.mjs
```

It will prompt:
```
Please enter your phone number: +1234567890
Please enter the code you received: 12345
```

After successful login, it saves session to `session.txt`. Copy content to `config.json5`:

```bash
SESSION=$(cat session.txt)
# Edit config.json5 and paste $SESSION into sessionString field
nano config.json5
```

### Step 4: Copy Existing Index (Optional)

If you have `library_index.json` from previous install:

```bash
# Copy from GitHub repo clone
cp /path/to/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/alexey-materials/metadata/library_index.json /opt/tg-export/

# Or download directly
curl -o /opt/tg-export/library_index.json https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/alexey-materials/metadata/library_index.json
```

**Why?** Parser will sync only NEW posts (incremental). Without it, parser downloads ALL 150+ posts from scratch.

**Current state in repo:**
- Total posts: 154
- Latest msg_id: 181
- Last sync: 2026-04-25 04:00 UTC

### Step 5: Setup Cron

```bash
crontab -e
```

Add these lines:

```cron
# Sync channel every 6 hours
0 */6 * * * cd /opt/tg-export && node sync_channel.mjs >> sync.log 2>&1

# Heartbeat monitor every 10 minutes
*/10 * * * * cd /opt/tg-export && bash heartbeat.sh

# Progress notifications every 2 hours
0 */2 * * * cd /opt/tg-export && bash notify.sh >> notify.log 2>&1

# Optional: GitHub sync every hour (if configured)
# 0 * * * * cd /opt/librarian && bash github-sync.sh >> github-sync.log 2>&1
```

---

## 📊 First Run Test

```bash
cd /opt/tg-export

# Test sync (should see new posts)
node sync_channel.mjs

# Check library index
jq -r '.total_posts' library_index.json

# Start download (P1-P3 only, skip P4 videos for now)
MIN_PRIO=1 MAX_PRIO=3 node download.mjs &

# Monitor progress
tail -f download.log
```

---

## 🔄 GitHub Auto-Sync (Optional)

If you want parser to auto-push to GitHub:

### 1. Copy github-sync.sh

```bash
# Clone your GitHub repo
git clone https://github.com/YOUR_USER/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY.git /opt/librarian

# Copy sync script
cp /tmp/parser-install/github-sync.sh /opt/librarian/
chmod +x /opt/librarian/github-sync.sh
```

### 2. Create GitHub Token

1. Go to https://github.com/settings/tokens
2. "Generate new token (classic)"
3. Scopes: `repo` (full control)
4. Copy token

### 3. Add to Cron with Token

```bash
crontab -e
```

```cron
# GitHub sync every hour
0 * * * * GITHUB_TOKEN=ghp_YOUR_TOKEN_HERE cd /opt/librarian && bash github-sync.sh >> github-sync.log 2>&1
```

**⚠️ Security:** Don't put token in files, only in cron env.

---

## 🐛 Troubleshooting

### Parser not detecting new posts

```bash
# Check sync log
tail -50 /opt/tg-export/sync.log

# Check library index
jq -r '.posts[0] | {msg_id, date, title}' /opt/tg-export/library_index.json

# Force sync from specific msg_id
node sync_channel.mjs --from-msg-id 181
```

### Download stuck

```bash
# Check if running
pgrep -f 'node download.mjs'

# Check last activity
tail -20 /opt/tg-export/download.log

# Heartbeat will auto-restart if stuck > expected pause + 5min
```

### Transcription fails

```bash
# Check ffmpeg
ffmpeg -version

# Check xAI API key
grep XAI_API_KEY /opt/tg-export/.env

# Test single file
cd /opt/tg-export
bash transcribe.sh media/YOUR_VIDEO.mp4
```

### GitHub sync not working

```bash
# Check git repo
cd /opt/librarian && git status

# Check token (should not show in logs!)
# GITHUB_TOKEN is in cron env only

# Test manual sync
cd /opt/librarian
GITHUB_TOKEN=ghp_YOUR_TOKEN bash github-sync.sh
```

---

## 📈 Data Flow

```
Telegram Channel «Алексей Колесов | Private»
    ↓ sync_channel.mjs (every 6h)
library_index.json (152 → 154 → ...)
    ↓ download.mjs (priority-based)
media/ (photos, docs, videos)
    ↓ transcribe.sh (Grok STT)
transcripts/*.transcript.json
    ↓ github-sync.sh (every 1h)
GitHub repo: alexey-materials/
    ↓ ingest_transcripts.py (manual/cron)
LightRAG database (full-text search)
```

---

## 🔒 Security

**Never commit to git:**
- `.env` (contains API keys)
- `config.json5` (contains session)
- `*.session` files
- `node_modules/`

**Included `.gitignore` handles this.**

---

## 📝 Changelog (PR #6 Fixes)

### heartbeat.sh
- **Before:** Hardcoded `MAX_PRIO=3` → P4 videos never downloaded after restart
- **After:** Respects `MIN_PRIO`/`MAX_PRIO` env vars (default 1-4)
- **Impact:** P4 whitelisted files survive restart

### sync_channel.mjs
- **Before:** Checked `msg.document` directly → missed `msg.media.document`
- **After:** Fallback to `msg.media?.document` and `msg.media?.photo`
- **Impact:** 12 documents (pdf/json/csv) now properly indexed

---

## 💡 Tips

1. **Incremental sync:** Always copy `library_index.json` from previous install
2. **P4 videos:** Use whitelist (`p4_whitelist.txt`) for selective download
3. **Rate limits:** Default pauses prevent Telegram ban (don't lower them!)
4. **Transcription cost:** ~$0.10/hour audio (56 videos ≈ $6-8 total)
5. **GitHub sync:** Keeps backup + enables search via web UI

---

## 🆘 Support

**Issues:** https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/issues  
**Docs:** See `OLD-PARSER-STRUCTURE/docs/` in main repo  
**Skills:** `navyki/claude-skills/telegram-parser/` for Claude integration

---

**Package created:** 2026-04-25  
**PR #6:** Parser fixes (P4 lockout + document metadata)  
**Verified:** All scripts real implementations, no placeholders
