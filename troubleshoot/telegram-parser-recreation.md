# Telegram Parser — Recreation Guide

**Статус:** PROVEN ARCHITECTURE (работает на Aeza 7+ дней)  
**Назначение:** Полное воссоздание парсера Telegram канала  
**Управление:** Claude Desktop + Terminal  
**Дата:** 2026-04-24

---

## Проблема

**Канал Алексея Колесова (Private):**
- 142+ поста с кодом, PDF, видео, аудио
- Нужна автоматизация: download → transcribe → classify → notify
- Управление должно быть через Claude bot

**Традиционное решение:**
```python
# Кастомный Python скрипт на 2000+ строк
# Ручной запуск
# Ручной мониторинг
# Нет self-healing
```

❌ **Не масштабируется**

---

## Решение: Telegram Parser v1.0

```
┌─────────────────────────────────────────┐
│     TELEGRAM CHANNEL (Алексей Private)  │
└──────────────┬──────────────────────────┘
               │
        ┌──────▼──────┐
        │ sync_channel│ ← Detect new posts (6h cron)
        │   .mjs      │
        └──────┬──────┘
               │
    ┌──────────┼──────────┐
    │          │          │
┌───▼───┐  ┌───▼───┐  ┌──▼────┐
│library│  │p4_    │  │announce│
│_index │  │white  │  │Telegram│
│.json  │  │list   │  │        │
└───┬───┘  └───┬───┘  └────────┘
    │          │
    └──────┬───┘
           │
    ┌──────▼──────┐
    │ download.mjs│ ← Download media (priority P1-P4)
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │media/*.{jpg,│
    │ pdf,mp4,etc}│
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │transcribe.sh│ ← Grok STT (auto-start on new media)
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │transcripts/ │
    │*.json + .txt│
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │ heartbeat.sh│ ← Watchdog (10min) + notify (2h)
    │ + notify.sh │
    └─────────────┘
```

---

## Архитектура компонентов

### 1. sync_channel.mjs (Channel Sync)

**Частота:** Каждые 6 часов (cron)

**Что делает:**
1. Сканирует Telegram канал с last sync point
2. Детектирует новые посты
3. Классифицирует (HIGH_CODE / HIGH_SALES / MED / LOW)
4. Обновляет library_index.json
5. Добавляет HIGH priority в p4_whitelist.txt
6. Анонсирует в Telegram бота

**Классификация:**
```javascript
const CODE_KW = ['скрипт','api','mcp','docker','n8n','supabase',
                 'agent','код','sql','установ','setup','deploy',
                 'install','config','cli','github','skill','rag'];
const SALES_KW = ['продаж','монетиз','лид','маркет','воронк',
                  'клиент','бизнес','доход','подписк','тариф'];

function classify(text) {
  const c = CODE_KW.reduce((n, k) => n + (text.split(k).length - 1), 0);
  const s = SALES_KW.reduce((n, k) => n + (text.split(k).length - 1), 0);
  if (c >= 3 && c > s * 1.5) return 'HIGH_CODE';
  if (s >= 3) return 'HIGH_SALES';
  if (c + s >= 3) return 'HIGH_MIXED';
  return c + s >= 1 ? 'MED' : 'LOW';
}
```

**Output:**
- `library_index.json` — метаданные всех постов
- `p4_whitelist.txt` — ID постов для download
- `announced.txt` — уже анонсированные (не повторять)

---

### 2. download.mjs (Priority Download)

**Запуск:** Вручную или через heartbeat

**Приоритеты:**
- **P1:** Scripts/configs (.zip, .md, .json, .js, .py, .sh, .yml, .sql, .env, .html)
- **P2:** Docs (.pdf, .txt, .csv, .xlsx, .docx)
- **P3:** Photos (.jpg, .png, .gif, .webp, .svg)
- **P4:** Video/audio (.mp4, .wav, .m4a, .mp3, .mov, .webm, .mkv)

**Human pacing (anti-ban):**
```javascript
const SHORT_MIN = 60_000, SHORT_MAX = 300_000;     // 1-5 min between files
const BURST_EVERY = 3-6;                            // Every N files
const BREAK_MIN = 300_000, BREAK_MAX = 1_200_000;  // 5-20 min break
const LONG_BREAK_EVERY = 12-20;                     // Every N files
const LONG_BREAK_MIN = 1_800_000, LONG_BREAK_MAX = 5_400_000; // 30-90 min
```

**Аргументы:**
```bash
node download.mjs [limit] [minPriority] [maxPriority] [notakeout]

# Примеры:
node download.mjs 0 1 3          # All messages, P1-P3 only (skip video)
node download.mjs 0 1 4          # All including video/audio
node download.mjs 0 1 3 notakeout # Without Telegram takeout session
```

**Output:**
- `media/{msg_id}_{filename}` — скачанные файлы
- `media/_progress.log` — подробный лог
- `media/_manifest.json` — метаданные download

---

### 3. transcribe.sh (Grok STT)

**Триггер:** Heartbeat (auto-start при новых media файлах)

**Что делает:**
1. Сканирует `media/*.{mp4,wav,m4a,mp3,mov,webm,mkv}`
2. Пропускает уже транскрибированные
3. Для video: извлекает audio (ffmpeg)
4. Для больших файлов: разбивает на chunks (20MB / 10min)
5. Отправляет в Grok STT API (xAI)
6. Сохраняет JSON (words + timestamps) + TXT (plain text)

**API:**
```bash
ENDPOINT="https://api.x.ai/v1/stt"

curl -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -F "file=@video.mp4"
```

**Output:**
```json
{
  "text": "полный текст...",
  "language": "English",
  "duration": 59.11,
  "words": [
    {"text": "слово", "start": 0.38, "end": 0.7},
    ...
  ]
}
```

**Chunking:**
```bash
CHUNK_SIZE_BYTES=$((20 * 1024 * 1024))  # 20 MB
CHUNK_SECONDS=600                        # 10 min

# Splits large files, then merges results
```

---

### 4. heartbeat.sh (Watchdog)

**Частота:** Каждые 10 минут (cron)

**Что проверяет:**
1. **Download alive?**
   - pgrep -f 'node download.mjs'
   - Idle > expected break + 5min? → Kill + Restart
   - Not running but not finished? → Restart

2. **Transcribe needed?**
   - Count untranscribed media
   - If exists → Launch transcribe.sh

3. **Log rotation:**
   - Logs > 10MB? → Rotate with timestamp

4. **Write _status.json:**
   - PIDs, statuses, counters, disk usage

**_status.json format:**
```json
{
  "updated": "2026-04-24T10:30:00Z",
  "download": {
    "pid": "12345",
    "status": "running",
    "idle_sec": 120,
    "action": "none"
  },
  "transcribe": {
    "pid": "12346",
    "status": "running",
    "pending": 0,
    "action": "none"
  },
  "media_files": 48,
  "media_bytes": 33554432,
  "transcripts_count": 15,
  "transcripts_bytes": 12582912
}
```

---

### 5. notify.sh (Telegram Push)

**Частота:** Каждые 2 часа (cron)

**Что делает:**
1. Читает `_status.json`
2. Считает AI costs (Grok STT: $0.10/hour)
3. Считает progress (P1/P2/P3 done vs total)
4. Форматирует HTML message
5. Шлёт в Telegram via BotFather API

**Message format:**
```
🌴 TG-Export 14:30 24.04 (UTC 06:30)

📥 Download: running (idle 120s)
  P1 scripts/configs: 27 / 27
  P2 PDFs/docs: 7 / 7
  P3 photos: 16 / 16

🎙 Transcribe (Grok STT): running
  Files done: 15
  Audio: 7.18h
  💰 Cost: $0.72

💾 Media on disk: 48 files / 32 MB
```

---

### 6. verify.sh (Health Check)

**Частота:** Каждый день 02:30 (cron)

**Что проверяет:**
1. library_index.json валидность
2. Все media файлы имеют запись в manifest
3. Все transcript JSON парсятся
4. Нет битых ссылок

**Output:** verification.log

---

### 7. enumerate_p4.mjs (Prioritization)

**Запуск:** Вручную (обычно раз перед download)

**Что делает:**
1. Читает library_index.json
2. Сканирует все посты
3. Классифицирует по приоритетам
4. Создаёт p4_catalog.json с метриками
5. Генерирует p4_whitelist.txt (топ HIGH priority)

**Output:**
```json
{
  "total_messages": 142,
  "HIGH_CODE": 45,
  "HIGH_SALES": 12,
  "HIGH_MIXED": 18,
  "MED": 34,
  "LOW": 33
}
```

---

## Cron Schedule (working setup)

```cron
# Sync channel (detect new posts)
15 */6 * * * cd /opt/tg-export && node sync_channel.mjs >> sync.log 2>&1

# Heartbeat (watchdog + auto-restart)
*/10 * * * * /opt/tg-export/heartbeat.sh

# Notify (Telegram status push)
0 */2 * * * /opt/tg-export/notify.sh

# Verify (daily health check)
30 2 * * * /opt/tg-export/verify.sh > /dev/null 2>&1
```

---

## Dependencies

**Node.js:**
```json
{
  "dependencies": {
    "telegram": "^2.27.1"
  }
}
```

**System packages:**
```bash
apt-get install -y ffmpeg jq bc curl
```

**API Keys (.env):**
```bash
# Telegram API (https://my.telegram.org)
TG_API_ID=12345678
TG_API_HASH=abcdef1234567890abcdef1234567890
TG_SESSION_STRING=<from telegram/sessions login>

# Grok STT (https://console.x.ai)
XAI_API_KEY=xai-...

# Telegram Bot (https://t.me/BotFather)
BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
CHAT_ID=123456789
```

---

## Proven Metrics (Aeza production)

**Uptime:** 7+ дней без ручного вмешательства

**Downloads:**
- P1 (scripts/configs): 27 файлов
- P2 (PDFs/docs): 7 файлов  
- P3 (photos): 16 файлов
- P4 (video/audio): 3 файла (избирательно)

**Transcriptions:**
- 15 файлов транскрибировано
- 7.18 часов аудио
- Стоимость: $0.72

**Auto-restarts:** 3 (2× download stuck, 1× transcribe new media)  
**False positives:** 0  
**Notifications:** 84 (каждые 2ч × 7 дней)

---

## Воссоздание через Claude Desktop

### Вариант 1: Quick Clone (10 минут)

**Шаг 1: Скачай с Aeza**
```bash
# Создай локальную копию
scp -r root@193.233.128.21:/opt/tg-export ~/tg-export-backup

# Или через tar (excluding videos)
ssh root@193.233.128.21 "cd /opt/tg-export && tar czf - --exclude='*.mp4' --exclude='*.wav' ." | tar xzf - -C ~/tg-export
```

**Шаг 2: Setup .env**
```bash
cd ~/tg-export

# Создай .env (скопируй credentials с Aeza)
cat > .env <<'EOF'
TG_API_ID=your_api_id
TG_API_HASH=your_api_hash
TG_SESSION_STRING=your_session_string
XAI_API_KEY=your_xai_key
BOT_TOKEN=your_bot_token
CHAT_ID=your_chat_id
EOF
```

**Шаг 3: Install dependencies**
```bash
npm install
```

**Шаг 4: Test**
```bash
# Тест sync
node sync_channel.mjs

# Проверь library_index.json
cat library_index.json | jq '.messages | length'

# Тест heartbeat
bash heartbeat.sh
cat _status.json
```

**Шаг 5: Cron setup**
```bash
crontab -e

# Add:
*/10 * * * * cd ~/tg-export && bash heartbeat.sh
0 */2 * * * cd ~/tg-export && bash notify.sh
15 */6 * * * cd ~/tg-export && node sync_channel.mjs >> sync.log 2>&1
```

✅ **Готово** за 10 минут

---

### Вариант 2: Claude Desktop Integration (30 минут)

**Идея:** Claude Desktop управляет парсером через skills

**Шаг 1: Создай skills**

`~/.claude/skills/telegram-parser/sync.sh`:
```bash
#!/bin/bash
cd ~/tg-export
node sync_channel.mjs 2>&1 | tail -20
```

`~/.claude/skills/telegram-parser/status.sh`:
```bash
#!/bin/bash
cat ~/tg-export/_status.json | jq '.'
```

`~/.claude/skills/telegram-parser/download.sh`:
```bash
#!/bin/bash
# Args: [limit] [minPrio] [maxPrio]
cd ~/tg-export
nohup node download.mjs ${1:-0} ${2:-1} ${3:-3} >> download.log 2>&1 &
echo "Download started (PID: $!)"
```

**Шаг 2: Создай MCP skill definition**

`~/.claude/skills/telegram-parser/SKILL.md`:
```markdown
# Telegram Parser Control

Control Telegram channel parser from Claude Desktop.

## Commands

**Check status:**
```
bash ~/.claude/skills/telegram-parser/status.sh
```

**Sync channel:**
```
bash ~/.claude/skills/telegram-parser/sync.sh
```

**Start download:**
```
bash ~/.claude/skills/telegram-parser/download.sh 0 1 3
```

## Usage

User: "Check parser status"
Assistant: [runs status.sh, shows JSON]

User: "Sync Alexey channel"
Assistant: [runs sync.sh, reports new posts]

User: "Download P1-P3 files"
Assistant: [runs download.sh 0 1 3]
```

**Шаг 3: Open in Terminal workflow**

Пользователь:
```
Создай чат для управления парсером
```

Claude Desktop:
1. Читает `~/tg-export/_status.json`
2. Показывает статус
3. Предлагает actions: sync / download / transcribe
4. При выборе — запускает skill
5. Для download — **открывает Terminal** (Open in Terminal)
6. Мониторит через heartbeat notifications в Telegram

---

### Вариант 3: Full Recreation (с нуля, 1 час)

**Используй если:**
- Нет доступа к Aeza
- Хочешь понять архитектуру
- Адаптируешь под другой канал

**Компоненты в библиотеке:**
- `aeza-archive/download.mjs` — reference implementation
- `aeza-archive/sync_channel.mjs` — sync logic
- `aeza-archive/transcribe.sh` — Grok STT integration
- `navyki/heartbeat-telegram.sh` — watchdog template
- `navyki/heartbeat-notify.sh` — notify template

**Адаптация:**
1. Копируй скрипты из `aeza-archive/`
2. Измени CHANNEL на свой
3. Настрой priorities под свои нужды
4. Добавь custom классификацию keywords
5. Deploy на VPS или запускай локально

---

## Управление через Claude Bot

### Setup Telegram Bot

**1. Создай бота:**
- Открой @BotFather
- `/newbot`
- Получи `BOT_TOKEN`

**2. Узнай CHAT_ID:**
```bash
# Отправь боту любое сообщение
curl "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'
```

**3. Тестируй:**
```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -d "chat_id=<CHAT_ID>" \
  -d "text=Parser ready!" \
  -d "parse_mode=HTML"
```

### Commands для бота

**В будущем (расширение):**

`/status` — показать _status.json  
`/sync` — запустить sync_channel.mjs  
`/download` — запустить download с параметрами  
`/transcribe` — запустить transcribe.sh  
`/logs` — показать последние 20 строк логов

*Пока работает через notify.sh (авто-уведомления каждые 2ч)*

---

## Troubleshooting

**Download зависает:**
```bash
# Проверь idle detection в heartbeat
tail -f ~/tg-export/download.log

# Ручной restart
pkill -f "node download.mjs"
cd ~/tg-export && nohup node download.mjs 0 1 3 >> download.log 2>&1 &
```

**Transcribe не запускается:**
```bash
# Проверь есть ли untranscribed media
cd ~/tg-export
for f in media/*.mp4; do
  txt="transcripts/$(basename "$f").transcript.txt"
  [ ! -f "$txt" ] && echo "Missing: $f"
done

# Ручной запуск
bash transcribe.sh
```

**Telegram API errors:**
```bash
# FloodWaitError — слишком частые запросы
# Решение: увеличь паузы в download.mjs

# SessionExpired — перелогинься
# Решение: обнови TG_SESSION_STRING
```

---

## Canon References

**Принцип #1 (Portability):**  
`kanon/alexey-11-principles.md:23`
- "Только официальные Docker-образы"
- Parser переносим: tar → new VPS → npm install → работает

**Принцип #2 (Minimal Integration Code):**  
`kanon/alexey-11-principles.md:36`
- "Логика в конфигах"
- Priorities, keywords, pauses — всё в константах вверху файла

**Heartbeat Pattern:**  
`navyki/heartbeat-telegram-pattern.md`
- Self-healing watchdog
- Proven в продакшне

---

## Файлы в библиотеке

**Reference implementation (Aeza backup):**
- `aeza-archive/download.mjs` (10K)
- `aeza-archive/sync_channel.mjs` (9.3K)
- `aeza-archive/transcribe.sh` (5.4K)
- `aeza-archive/heartbeat.sh` (4.9K)
- `aeza-archive/notify.sh` (2.7K)
- `aeza-archive/verify.sh` (3.7K)
- `aeza-archive/enumerate_p4.mjs` (3.7K)

**Data examples:**
- `aeza-archive/library_index.json` (273KB) — 142 поста
- `aeza-archive/p4_catalog.json` (57KB) — priorities
- `aeza-archive/_status.json` — state snapshot

**Templates:**
- `navyki/heartbeat-telegram.sh` — adaptable watchdog
- `navyki/heartbeat-notify.sh` — notify template

---

**Создано:** 2026-04-24  
**Proven:** 7+ дней uptime на Aeza  
**Ready to deploy:** ✅ Quick clone за 10 минут

**Следующий шаг:** Интеграция с Claude Desktop (см. Вариант 2)
