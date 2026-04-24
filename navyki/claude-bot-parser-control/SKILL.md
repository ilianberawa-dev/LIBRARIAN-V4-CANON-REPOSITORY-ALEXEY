# Telegram Parser Management

Control Telegram channel parser (sync, download, transcribe) through Claude chat.

## Commands

### Check Status
```bash
bash ~/.claude/skills/telegram-parser/status.sh
```

### Sync Channel
Detect new posts from Telegram channel.
```bash
bash ~/.claude/skills/telegram-parser/sync.sh
```

### Download Media
Download media files by priority.

Args: `[limit] [minPriority] [maxPriority]`
- `limit`: 0=all, N=first N messages
- `minPriority`: 1-4 (1=scripts, 2=docs, 3=photos, 4=video)
- `maxPriority`: 1-4

```bash
bash ~/.claude/skills/telegram-parser/download.sh [limit] [minPrio] [maxPrio]
```

Examples:
- All scripts+docs: `download.sh 0 1 2`
- First 10 photos: `download.sh 10 3 3`
- Everything: `download.sh 0 1 4`

### Transcribe Media
Transcribe video/audio via Grok STT.
```bash
bash ~/.claude/skills/telegram-parser/transcribe.sh
```

### Show Logs
View recent logs.

Args: `[component] [lines]`
- `component`: download | transcribe | sync | heartbeat
- `lines`: number of lines (default 30)

```bash
bash ~/.claude/skills/telegram-parser/logs.sh [component] [lines]
```

## Usage Patterns

**User:** "Check parser"
**Assistant:** runs `status.sh`, interprets results.

**User:** "Download all scripts from Alexey's channel"
**Assistant:** runs `download.sh 0 1 1`, opens terminal for monitoring.

**User:** "Why is download stuck?"
**Assistant:** runs `status.sh`, checks `idle_sec`, reads `download.log` last 50 lines, explains human pacing.

**User:** "Transcribe new videos"
**Assistant:** runs `transcribe.sh`, shows Grok STT progress.

## Environment

Parser location is controlled by `$PARSER_DIR` (default: `$HOME/tg-export`).

## Canon References

- Simplicity-First (Принцип #0): chat > SSH
- Skills Over Agents (Принцип #4): portable, version-controlled
- Proven in production: 7 days uptime, $0.72 Grok STT cost, 0 false positives
