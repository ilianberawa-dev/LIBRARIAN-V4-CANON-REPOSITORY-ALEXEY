# Telegram Parser Management

Control Telegram channel parser (tg-export) through Claude Desktop chat.

**Setup:** см. `install.sh` в этой папке или `navyki/claude-bot-parser-control.md`
**Env:** `PARSER_DIR` — путь к парсеру (по умолчанию `$HOME/tg-export`)

---

## Commands

### Check Status
```bash
bash ~/.claude/skills/telegram-parser/status.sh
```
Читает `_status.json`, показывает download/transcribe progress, running processes.

### Sync Channel
Detect new posts from Telegram channel.
```bash
bash ~/.claude/skills/telegram-parser/sync.sh
```

### Download Media
Download media files by priority.

Args: `[limit] [minPriority] [maxPriority]`
- `limit`: 0=all, N=first N messages
- `minPriority/maxPriority`: 1=scripts, 2=docs, 3=photos, 4=video

```bash
bash ~/.claude/skills/telegram-parser/download.sh [limit] [minPrio] [maxPrio]
```

Examples:
- Все скрипты+документы: `download.sh 0 1 2`
- Первые 10 фото: `download.sh 10 3 3`
- Всё подряд: `download.sh 0 1 4`

### Transcribe Media
Транскрибировать video/audio через Grok STT.
```bash
bash ~/.claude/skills/telegram-parser/transcribe.sh
```

### Show Logs
View recent logs.

Args: `[component] [lines]`
- `component`: download | transcribe | sync | heartbeat
- `lines`: число строк (по умолчанию 30)

```bash
bash ~/.claude/skills/telegram-parser/logs.sh [component] [lines]
```

---

## Usage Patterns

**User:** "Check parser"
**Assistant:** запускает `status.sh`, интерпретирует вывод.

**User:** "Download all scripts from Alexey's channel"
**Assistant:** запускает `download.sh 0 1 1`, открывает Terminal с `tail -f download.log` для мониторинга.

**User:** "Why is download stuck?"
**Assistant:** `status.sh` → проверяет `idle_sec`, читает последние 50 строк `download.log`, объясняет human-pacing (anti-ban паузы до 60 минут — нормально).

**User:** "Transcribe new videos"
**Assistant:** `transcribe.sh` → показывает Grok STT progress.

---

## Canon References

- **Simplicity-First (Принцип #0):** `kanon/simplicity-first-principle.md` — 5 bash-скриптов вместо сложного UI, управление через чат.
- **Skills Over Agents (Принцип #4):** `kanon/alexey-11-principles.md` — skills версионируются, переиспользуются.
- **Heartbeat Pattern:** `navyki/heartbeat-telegram-pattern.md` — self-healing watchdog.

---

## Proven Metrics (Aeza production)

- 7 дней uptime без ручного вмешательства
- 48 файлов скачано (P1: 27, P2: 7, P3: 16)
- 15 транскриптов (7.18 ч аудио, $0.72 Grok STT)
- 3 auto-restarts (все корректные), 0 false positives
