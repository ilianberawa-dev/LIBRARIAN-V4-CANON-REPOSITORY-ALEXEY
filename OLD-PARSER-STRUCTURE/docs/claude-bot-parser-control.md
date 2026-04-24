# Claude Desktop — Parser Control

**Назначение:** Управление Telegram парсером через Claude Desktop  
**Workflow:** Чат → Terminal → Skills → Monitoring  
**Дата:** 2026-04-24

---

## Идея

**Вместо:**
```bash
# SSH в сервер
ssh root@server
cd /opt/tg-export
node download.mjs...
tail -f download.log...
# ... мучения
```

**Делаем:**
```
User: "Запусти парсер на скачивание P1-P3"
Claude: [открывает Terminal, запускает download, мониторит через heartbeat]
User: "Статус?"
Claude: [читает _status.json, показывает progress]
```

✅ **Просто**. Всё через чат.

---

## Архитектура

```
┌─────────────────────────────────────────┐
│      CLAUDE DESKTOP (chat interface)     │
└──────────────┬──────────────────────────┘
               │
        ┌──────▼──────┐
        │   Skills    │ ← ~/.claude/skills/telegram-parser/
        │  (bash)     │
        └──────┬──────┘
               │
    ┌──────────┼──────────┐
    │          │          │
┌───▼───┐  ┌───▼───┐  ┌──▼────┐
│status │  │sync   │  │download│
│.sh    │  │.sh    │  │.sh     │
└───┬───┘  └───┬───┘  └───┬────┘
    │          │          │
    └──────────┼──────────┘
               │
        ┌──────▼──────┐
        │~/tg-export/ │ ← Parser files
        └──────┬──────┘
               │
    ┌──────────┼──────────┐
    │          │          │
┌───▼───┐  ┌───▼───┐  ┌──▼────┐
│download│  │sync_  │  │_status│
│.mjs   │  │channel│  │.json  │
└───────┘  └───┬───┘  └────────┘
               │
        ┌──────▼──────┐
        │ Telegram    │ ← Notifications
        │   Bot       │
        └─────────────┘
```

---

## Setup (5 минут)

### Шаг 1: Подготовь парсер

**Вариант A: Clone с Aeza**
```bash
scp -r root@193.233.128.21:/opt/tg-export ~/tg-export
cd ~/tg-export
npm install
```

**Вариант B: Используй backup из библиотеки**
```bash
cp -r C:/Users/97152/Documents/claude-library/aeza-archive ~/tg-export
cd ~/tg-export
npm install
```

**Настрой .env:**
```bash
cat > ~/tg-export/.env <<'EOF'
# Telegram API (https://my.telegram.org)
TG_API_ID=your_id
TG_API_HASH=your_hash
TG_SESSION_STRING=your_session

# Grok STT (https://console.x.ai)
XAI_API_KEY=xai-...

# Telegram Bot (@BotFather)
BOT_TOKEN=123456:ABC...
CHAT_ID=123456789
EOF
```

---

### Шаг 2: Создай skills

```bash
mkdir -p ~/.claude/skills/telegram-parser
cd ~/.claude/skills/telegram-parser
```

**status.sh** (проверка статуса):
```bash
cat > status.sh <<'EOF'
#!/bin/bash
# Показывает статус парсера

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"
STATUS_FILE="$PARSER_DIR/_status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ Parser not initialized. Run heartbeat first:"
  echo "   bash $PARSER_DIR/heartbeat.sh"
  exit 1
fi

echo "📊 Parser Status ($(date '+%H:%M %d.%m')):"
echo

# Parse JSON
cat "$STATUS_FILE" | jq -r '
  "Updated: \(.updated)",
  "",
  "📥 Download:",
  "  Status: \(.download.status)",
  "  PID: \(.download.pid)",
  "  Idle: \(.download.idle_sec)s",
  "",
  "🎙 Transcribe:",
  "  Status: \(.transcribe.status)",
  "  Pending: \(.transcribe.pending) files",
  "",
  "💾 Storage:",
  "  Media: \(.media_files) files (\(.media_bytes / 1048576 | floor)MB)",
  "  Transcripts: \(.transcripts_count) files"
'

# Check processes
echo
echo "🔄 Running processes:"
pgrep -f "node download.mjs" >/dev/null && echo "  ✅ download.mjs" || echo "  ❌ download.mjs"
pgrep -f "transcribe.sh" >/dev/null && echo "  ✅ transcribe.sh" || echo "  ❌ transcribe.sh"
EOF

chmod +x status.sh
```

**sync.sh** (синхронизация канала):
```bash
cat > sync.sh <<'EOF'
#!/bin/bash
# Синхронизирует Telegram канал (detect new posts)

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"

echo "🔄 Syncing Telegram channel..."
cd "$PARSER_DIR"

# Backup library_index.json
if [ -f library_index.json ]; then
  cp library_index.json "library_index.json.bak.$(date +%s)"
fi

# Run sync
node sync_channel.mjs 2>&1 | tail -30

# Show summary
if [ -f library_index.json ]; then
  TOTAL=$(jq '.messages | length' library_index.json)
  echo
  echo "✅ Sync complete. Total posts: $TOTAL"
  
  # Show new posts if announced.txt changed
  if [ -f announced.txt ]; then
    NEW=$(tail -5 announced.txt 2>/dev/null)
    if [ -n "$NEW" ]; then
      echo
      echo "🆕 New posts:"
      echo "$NEW"
    fi
  fi
else
  echo "❌ Sync failed. Check logs."
fi
EOF

chmod +x sync.sh
```

**download.sh** (запуск скачивания):
```bash
cat > download.sh <<'EOF'
#!/bin/bash
# Запускает download с параметрами
# Args: [limit] [minPrio] [maxPrio]

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"

LIMIT="${1:-0}"
MIN_PRIO="${2:-1}"
MAX_PRIO="${3:-3}"

echo "📥 Starting download..."
echo "  Limit: $LIMIT (0=all)"
echo "  Priority: P$MIN_PRIO - P$MAX_PRIO"
echo

cd "$PARSER_DIR"

# Check if already running
if pgrep -f "node download.mjs" >/dev/null; then
  PID=$(pgrep -f "node download.mjs")
  echo "⚠️  Download already running (PID: $PID)"
  echo
  echo "Options:"
  echo "  1. Kill existing: kill $PID"
  echo "  2. Check status: tail -f download.log"
  exit 1
fi

# Start download in background
nohup node download.mjs "$LIMIT" "$MIN_PRIO" "$MAX_PRIO" >> download.log 2>&1 &
NEW_PID=$!

echo "✅ Download started (PID: $NEW_PID)"
echo
echo "Monitor:"
echo "  tail -f $PARSER_DIR/download.log"
echo "  Or check status: bash ~/.claude/skills/telegram-parser/status.sh"
EOF

chmod +x download.sh
```

**logs.sh** (показать логи):
```bash
cat > logs.sh <<'EOF'
#!/bin/bash
# Показывает последние логи парсера
# Args: [component] [lines]

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"
COMPONENT="${1:-download}"
LINES="${2:-30}"

LOG_FILE="$PARSER_DIR/${COMPONENT}.log"

if [ ! -f "$LOG_FILE" ]; then
  echo "❌ Log not found: $LOG_FILE"
  echo
  echo "Available logs:"
  ls -1 "$PARSER_DIR"/*.log 2>/dev/null | sed 's/.*\//  - /'
  exit 1
fi

echo "📄 Last $LINES lines of $COMPONENT.log:"
echo
tail -n "$LINES" "$LOG_FILE"
EOF

chmod +x logs.sh
```

**transcribe.sh** (запуск транскрибации):
```bash
cat > transcribe.sh <<'EOF'
#!/bin/bash
# Запускает транскрибацию untranscribed media

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"

cd "$PARSER_DIR"

# Count untranscribed
UNTRANSCRIBED=0
for f in media/*.{mp4,wav,m4a,mp3,mov,webm,mkv} 2>/dev/null; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  if [ ! -f "transcripts/${fname}.transcript.txt" ]; then
    UNTRANSCRIBED=$((UNTRANSCRIBED + 1))
  fi
done

if [ "$UNTRANSCRIBED" -eq 0 ]; then
  echo "✅ No untranscribed media files"
  exit 0
fi

echo "🎙 Found $UNTRANSCRIBED untranscribed files"
echo "Starting transcribe.sh..."
echo

nohup bash transcribe.sh >> transcribe.log 2>&1 &
PID=$!

echo "✅ Transcribe started (PID: $PID)"
echo
echo "Monitor:"
echo "  tail -f $PARSER_DIR/transcribe.log"
EOF

chmod +x transcribe.sh
```

---

### Шаг 3: Тестируй skills

```bash
# Статус
bash ~/.claude/skills/telegram-parser/status.sh

# Синхронизация
bash ~/.claude/skills/telegram-parser/sync.sh

# Download (только P1-P2, первые 10 файлов для теста)
bash ~/.claude/skills/telegram-parser/download.sh 10 1 2

# Логи
bash ~/.claude/skills/telegram-parser/logs.sh download 50
```

---

## Использование через Claude Desktop

### Диалог 1: Первый запуск

**User:**
```
Настрой Telegram парсер для канала Алексея
```

**Claude:**
1. Проверяет наличие `~/tg-export/`
2. Если нет — предлагает скопировать с Aeza или из библиотеки
3. Проверяет `.env` (API keys)
4. Запускает первую синхронизацию:
   ```bash
   bash ~/.claude/skills/telegram-parser/sync.sh
   ```
5. Показывает результат: "Синхронизировано 142 поста"

---

### Диалог 2: Скачивание приоритетных файлов

**User:**
```
Скачай все скрипты и конфиги из канала (P1-P2)
```

**Claude:**
1. Проверяет статус:
   ```bash
   bash ~/.claude/skills/telegram-parser/status.sh
   ```
2. Запускает download:
   ```bash
   bash ~/.claude/skills/telegram-parser/download.sh 0 1 2
   ```
3. **Открывает Terminal** (Open in Terminal) для мониторинга:
   ```bash
   tail -f ~/tg-export/download.log
   ```
4. Показывает как остановить: `Ctrl+C`, затем `kill <PID>`

---

### Диалог 3: Проверка прогресса

**User:**
```
Как там парсер? Сколько уже скачал?
```

**Claude:**
```bash
bash ~/.claude/skills/telegram-parser/status.sh
```

**Output:**
```
📊 Parser Status (14:30 24.04):

Updated: 2026-04-24T06:30:00Z

📥 Download:
  Status: running
  PID: 12345
  Idle: 120s

🎙 Transcribe:
  Status: ok
  Pending: 0 files

💾 Storage:
  Media: 48 files (32MB)
  Transcripts: 15 files

🔄 Running processes:
  ✅ download.mjs
  ❌ transcribe.sh
```

Claude интерпретирует:
- Download работает, idle 120s (в паузе между файлами — нормально)
- Скачано 48 файлов (32MB)
- Transcribe не запущен (нет новых media для транскрибации)

---

### Диалог 4: Транскрибация

**User:**
```
Транскрибируй все видео
```

**Claude:**
1. Проверяет untranscribed:
   ```bash
   bash ~/.claude/skills/telegram-parser/transcribe.sh
   ```
2. Если есть — запускает в фоне
3. Показывает мониторинг:
   ```bash
   tail -f ~/tg-export/transcribe.log
   ```

---

### Диалог 5: Troubleshooting

**User:**
```
Download завис
```

**Claude:**
1. Проверяет статус:
   ```bash
   bash status.sh
   ```
2. Видит `idle: 1800s` (30 минут)
3. Проверяет лог:
   ```bash
   bash logs.sh download 50
   ```
4. Видит `[long-break] ~60 min` — нормальная пауза
5. Объясняет: "Download в долгой паузе (anti-ban). Подожди ещё 30 мин или kill+restart"

---

## Open in Terminal workflow

**Когда Claude открывает Terminal:**

1. **При download start:**
   - Claude запускает `download.sh`
   - Открывает Terminal с `tail -f download.log`
   - User видит real-time progress

2. **При transcribe:**
   - Claude запускает `transcribe.sh`
   - Terminal показывает Grok STT calls

3. **При debugging:**
   - Claude открывает Terminal с:
     ```bash
     cd ~/tg-export
     ps aux | grep -E "download|transcribe"
     ```

**User control:**
- `Ctrl+C` — остановить tail
- `kill <PID>` — убить процесс
- Terminal остаётся открытым для ручных команд

---

## Monitoring через Telegram

**Setup notify:**
```bash
# Добавь в cron (локально или на VPS)
crontab -e

# Add:
0 */3 * * * bash ~/tg-export/notify.sh
```

**Каждые 3 часа получаешь:**
```
🤖 TG-Parser Status

📥 Download: running (idle 120s)
  P1: 27/27
  P2: 7/7
  P3: 16/50

🎙 Transcribe: 15 files done
  Audio: 7.18h
  💰 Cost: $0.72

💾 32MB on disk
```

---

## Advanced: MCP Skill Definition

**Для Claude Code (будущее):**

`~/.claude/skills/telegram-parser/SKILL.md`:
```markdown
# Telegram Parser Management

Control Telegram channel parser.

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

Args: [limit] [minPriority] [maxPriority]
- limit: 0=all, N=first N messages
- minPriority: 1-4 (1=scripts, 2=docs, 3=photos, 4=video)
- maxPriority: 1-4

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

Args: [component] [lines]
- component: download | transcribe | sync | heartbeat
- lines: number of lines (default 30)

```bash
bash ~/.claude/skills/telegram-parser/logs.sh [component] [lines]
```

## Usage Patterns

**User:** "Check parser"  
**Assistant:** [runs status.sh, interprets results]

**User:** "Download all scripts from Alexey's channel"  
**Assistant:** [runs download.sh 0 1 1, opens terminal for monitoring]

**User:** "Why is download stuck?"  
**Assistant:** [runs status.sh, checks idle_sec, reads download.log last 50 lines, explains human pacing]

**User:** "Transcribe new videos"  
**Assistant:** [runs transcribe.sh, shows Grok STT progress]
```

---

## Готовые команды для копипасты

**В новый Claude Desktop чат:**

```
Setup Telegram Parser:

1. Clone parser:
   scp -r root@193.233.128.21:/opt/tg-export ~/tg-export
   cd ~/tg-export && npm install

2. Создай skills:
   mkdir -p ~/.claude/skills/telegram-parser
   
   Скопируй skills из библиотеки:
   Read C:\Users\97152\Documents\claude-library\navyki\claude-bot-parser-control.md
   
   Секция "Шаг 2: Создай skills" — все 5 файлов

3. Тест:
   bash ~/.claude/skills/telegram-parser/status.sh

Готов к управлению через чат.
```

---

## Canon References

**Simplicity-First (Принцип #0):**  
`kanon/simplicity-first-principle.md`
- Управление через чат проще чем SSH
- 5 bash скриптов вместо сложного UI

**Skills Over Agents (Принцип #4):**  
`kanon/alexey-11-principles.md:57`
- Skills version controlled, reusable
- `~/.claude/skills/telegram-parser/` — portable

**Heartbeat Pattern:**  
`navyki/heartbeat-telegram-pattern.md`
- Self-healing monitoring
- Telegram notifications

---

## Файлы

**В библиотеке:**
- `navyki/claude-bot-parser-control.md` — этот файл
- `troubleshoot/telegram-parser-recreation.md` — полная архитектура
- `aeza-archive/*.{mjs,sh}` — reference implementation

**Создашь локально:**
- `~/.claude/skills/telegram-parser/*.sh` — 5 скриптов управления
- `~/tg-export/` — сам парсер

---

**Создано:** 2026-04-24  
**Workflow:** Chat → Skills → Terminal → Monitoring  
**Setup time:** 5 минут  
**Ready:** ✅
