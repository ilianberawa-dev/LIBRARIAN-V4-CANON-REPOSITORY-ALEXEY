# НАВЫКИ (Skills)

**Категория:** Переиспользуемые паттерны и скрипты  
**Статус:** ✅ 1 proven pattern (heartbeat-telegram)

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

## 🚧 Roadmap

**Планируется:**
- `proactive-think/` — Проактивное мышление skill
- `gmail-check/` — Gmail inbox check + summarize
- `memory-sync/` — LightRAG sync automation

**Критерий добавления:** Работает в продакшне минимум 7 дней.

---

**Последнее обновление:** 2026-04-24  
**Источники:** Aeza production (tg-export), AI Assistant development
