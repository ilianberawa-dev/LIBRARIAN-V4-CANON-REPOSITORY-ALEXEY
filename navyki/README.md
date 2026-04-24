# НАВЫКИ (Skills)

**Категория:** Переиспользуемые паттерны и скрипты  
**Статус:** ✅ 2 proven patterns (heartbeat-telegram, claude-bot-parser-control)

---

## Что здесь

Готовые к использованию паттерны, скрипты и skills для AI Assistant и автоматизации.

**Критерий включения:** Proven in production (работает в реальном продакте минимум 7 дней).

---

## 📁 Содержимое

### 1. Heartbeat Telegram Pattern ✅

**Файлы:**
- `heartbeat-telegram-pattern.md` — документация (334 строки)
- `heartbeat-telegram.sh` — executable template
- `heartbeat-notify.sh` — Telegram notify template

**Что делает:**
- Self-healing watchdog для long-running процессов
- Auto-restart при зависании
- Log rotation
- Telegram notifications каждые N часов
- Status snapshot (_status.json)

**Proven metrics:**
- 7 дней uptime в продакшне (Aeza tg-export)
- 0 false positives
- 3 auto-restarts (все корректные)

**Применение:**
- AI Assistant monitoring (memory-sync, proactive-think)
- Парсеры (download, transcribe)
- Любые daemons

**Быстрый старт:**
```bash
# 1. Копируй template
cp navyki/heartbeat-telegram.sh ~/.claude/heartbeat/

# 2. Адаптируй под свой процесс (измени check_custom_process)

# 3. Настрой .env
cat > ~/.claude/assistant/.env <<EOF
BOT_TOKEN=your_token_from_botfather
CHAT_ID=your_telegram_chat_id
EOF

# 4. Добавь в cron
crontab -e
# Add:
*/30 * * * * BASE_DIR=$HOME/.claude/assistant bash $HOME/.claude/heartbeat/heartbeat-telegram.sh
0 */3 * * * BASE_DIR=$HOME/.claude/assistant bash $HOME/.claude/heartbeat/heartbeat-notify.sh

# 5. Тест
bash ~/.claude/heartbeat/heartbeat-telegram.sh
cat ~/.claude/assistant/_status.json
```

**Canon refs:**
- `kanon/simplicity-first-principle.md` — Принцип #0 (доверяй но проверяй)
- `kanon/alexey-11-principles.md:23` — Принцип #1 (Portability)
- `kanon/alexey-11-principles.md:36` — Принцип #2 (Minimal Integration)

---

### 2. Claude Bot Parser Control ✅

**Файлы:**
- `claude-bot-parser-control.md` — документация (600+ строк, архитектура + диалоги)
- `claude-bot-parser-control/` — 5 executable skills + SKILL.md + one-shot installer
  - `status.sh` — показать `_status.json` парсера
  - `sync.sh` — детект новых постов в канале
  - `download.sh [limit] [minPrio] [maxPrio]` — скачивание по приоритетам
  - `logs.sh [component] [lines]` — просмотр логов
  - `transcribe.sh` — транскрибация untranscribed media через Grok STT
  - `SKILL.md` — MCP skill definition
  - `install.sh` — копирует все 5 скриптов в `~/.claude/skills/telegram-parser/`

**Что делает:**
- Управление Telegram парсером через Claude Desktop чат вместо SSH
- 5 bash skills вызываются прямо из диалога
- Open in Terminal workflow для live-мониторинга

**Proven metrics (Aeza production):**
- 142 поста проиндексировано
- 48 медиа скачано (P1-P3)
- 15 транскриптов (7.18ч аудио)
- $0.72 Grok STT cost
- 7 дней uptime

**Быстрый старт (30 секунд):**
```bash
# 1. Склонируй библиотеку (или git pull если уже есть)
git clone https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY.git

# 2. Запусти installer
cd LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY
bash navyki/claude-bot-parser-control/install.sh

# 3. Подготовь парсер (один из двух):
#    a) clone с Aeza:     scp -r root@193.233.128.21:/opt/tg-export ~/tg-export
#    b) из backup:        cp -r aeza-archive ~/tg-export
cd ~/tg-export && npm install

# 4. Настрой .env (TG_API_*, XAI_API_KEY, BOT_TOKEN, CHAT_ID)

# 5. Тест
bash ~/.claude/skills/telegram-parser/status.sh
```

**Canon refs:**
- `kanon/simplicity-first-principle.md` — Принцип #0 (чат проще SSH)
- `kanon/alexey-11-principles.md` — Принцип #4 (Skills Over Agents)
- `troubleshoot/telegram-parser-recreation.md` — полная архитектура парсера

---

## 🚧 Roadmap

**Планируется:**
- `proactive-think/` — Проактивное мышление skill
- `gmail-check/` — Gmail inbox check + summarize
- `memory-sync/` — LightRAG sync automation

**Критерий добавления:** Работает в продакшне минимум 7 дней.

---

**Последнее обновление:** 2026-04-24  
**Источники:** Aeza production (tg-export), AI Assistant development
