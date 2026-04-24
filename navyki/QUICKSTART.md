# Heartbeat Telegram — Quick Start

**5 минут до работающего heartbeat с Telegram уведомлениями**

---

## Шаг 1: Скачай скрипты

**Локально (если библиотека на машине):**
```bash
cp C:/Users/97152/Documents/claude-library/navyki/heartbeat-telegram.sh ~/.claude/heartbeat/
cp C:/Users/97152/Documents/claude-library/navyki/heartbeat-notify.sh ~/.claude/heartbeat/
chmod +x ~/.claude/heartbeat/*.sh
```

**Через GitHub:**
```bash
mkdir -p ~/.claude/heartbeat
cd ~/.claude/heartbeat

# Скачай с GitHub
curl -O https://raw.githubusercontent.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/main/navyki/heartbeat-telegram.sh
curl -O https://raw.githubusercontent.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/main/navyki/heartbeat-notify.sh

chmod +x *.sh
```

---

## Шаг 2: Создай Telegram бота

1. Открой Telegram → найди **@BotFather**
2. Отправь `/newbot`
3. Следуй инструкциям, получишь `BOT_TOKEN`
4. Узнай свой `CHAT_ID`:
   ```bash
   # Отправь боту любое сообщение, затем:
   curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
   # Найди "chat":{"id":123456789 ...
   ```

---

## Шаг 3: Настрой .env

```bash
mkdir -p ~/.claude/assistant

cat > ~/.claude/assistant/.env <<'EOF'
# Telegram Bot Configuration
BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
CHAT_ID=123456789

# Heartbeat Settings
BASE_DIR=$HOME/.claude/assistant
TELEGRAM_NOTIFY=true
WATCH_PROCESS=assistant  # измени на свой процесс если нужно
EOF
```

---

## Шаг 4: Адаптируй под свой проект (опционально)

Открой `~/.claude/heartbeat/heartbeat-telegram.sh` и измени:

**Пример 1: Мониторинг download.mjs**
```bash
check_custom_process() {
  local proc_pid
  proc_pid=$(pgrep -f "node download.mjs" | head -1)
  local proc_status="stopped"

  if [ -n "$proc_pid" ]; then
    proc_status="running"
    
    # Проверка idle (как в tg-export)
    local log_file="$BASE/download.log"
    if [ -f "$log_file" ]; then
      local last_mod=$(stat -c %Y "$log_file")
      local now=$(date +%s)
      local idle=$((now - last_mod))
      
      if [ "$idle" -gt 900 ]; then  # 15 min
        log "[stuck] download idle ${idle}s — restarting"
        kill "$proc_pid"
        cd "$BASE"
        nohup node download.mjs >> download.log 2>&1 &
        proc_status="restarted"
      fi
    fi
  else
    log "[dead] download not running — restarting"
    cd "$BASE"
    nohup node download.mjs >> download.log 2>&1 &
    proc_status="restarted"
  fi

  echo "{\"pid\":\"${proc_pid:-null}\",\"status\":\"$proc_status\"}"
}
```

**Пример 2: Мониторинг AI Assistant memory**
```bash
check_memory_sync() {
  local memory_file="$BASE/memory/MEMORY.md"
  local mem_age=0
  local mem_action="none"

  if [ -f "$memory_file" ]; then
    local last_mod=$(stat -c %Y "$memory_file" 2>/dev/null)
    local now=$(date +%s)
    mem_age=$((now - last_mod))

    if [ "$mem_age" -gt 86400 ]; then  # 24h stale
      log "[stale] memory not synced in 24h — triggering sync"
      # Триггер твоего sync скрипта:
      bash "$BASE/scripts/memory-sync.sh" || true
      mem_action="triggered_sync"
    fi
  fi

  echo "{\"age_sec\":$mem_age,\"action\":\"$mem_action\"}"
}
```

---

## Шаг 5: Добавь в cron

```bash
crontab -e

# Добавь эти строки:
*/30 * * * * bash $HOME/.claude/heartbeat/heartbeat-telegram.sh
0 */3 * * * bash $HOME/.claude/heartbeat/heartbeat-notify.sh
```

**Что это значит:**
- `*/30 * * * *` — каждые 30 минут проверка (heartbeat)
- `0 */3 * * *` — каждые 3 часа Telegram уведомление

**Для tg-export (как в продакшне):**
```bash
*/10 * * * * bash /opt/tg-export/heartbeat.sh
0 */2 * * * bash /opt/tg-export/notify.sh
```

---

## Шаг 6: Тест

**Ручной запуск:**
```bash
# Запусти heartbeat
bash ~/.claude/heartbeat/heartbeat-telegram.sh

# Проверь status
cat ~/.claude/assistant/_status.json

# Отправь в Telegram
bash ~/.claude/heartbeat/heartbeat-notify.sh
```

**Проверь в Telegram:**
Должно прийти сообщение вида:
```
🤖 AI Assistant Status
14:30 24.04 (UTC 06:30)

✅ Memory: fresh (2h ago)
✅ Proactive: ok (3h idle)

💾 Disk: 42M / 156 files

Last update: 2026-04-24T06:30:00Z
```

---

## Troubleshooting

**Не приходят уведомления:**
```bash
# Проверь .env
cat ~/.claude/assistant/.env

# Проверь что бот создан
curl "https://api.telegram.org/bot${BOT_TOKEN}/getMe"

# Ручной тест отправки
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=Test from heartbeat"
```

**Heartbeat не запускается:**
```bash
# Проверь права
ls -la ~/.claude/heartbeat/*.sh
# Должно быть -rwxr-xr-x

# Если нет:
chmod +x ~/.claude/heartbeat/*.sh

# Проверь логи
tail -f ~/.claude/assistant/heartbeat.log
```

**Cron не работает:**
```bash
# Проверь что cron запущен
systemctl status cron  # Linux
# или
launchctl list | grep cron  # macOS

# Логи cron
tail -f /var/log/syslog | grep CRON  # Linux
tail -f /var/log/system.log | grep cron  # macOS

# Тест cron синтаксиса
crontab -l
```

---

## Адаптация для разных проектов

**AI Assistant:**
- Мониторинг memory sync
- Proactive-think триггеры
- Gmail/Calendar последний check

**Парсеры (как tg-export):**
- Download процесс (stuck detection)
- Transcribe автостарт
- Media файлы счёт

**Web scraping:**
- Scraper процесс
- Proxy rotation
- Rate limit tracking

**Backend services:**
- API health check
- Database connection
- Queue size monitoring

---

## Что дальше

**Расширения:**
1. Добавь cost tracking (как в tg-export notify.sh)
2. Добавь больше проверок в heartbeat
3. Настрой разные интервалы для разных проверок
4. Добавь webhooks для критичных событий

**Интеграция с AI Assistant:**
- Memory sync через LightRAG
- Proactive-think автоматизация
- Daily brief генерация

**Документация:**
- `heartbeat-telegram-pattern.md` — полная документация
- `README.md` — обзор навыков
- Этот файл — quick start

---

**Время setup:** 5 минут  
**Proven:** 7 дней uptime в продакшне  
**Source:** Aeza tg-export heartbeat.sh

✅ Готово к использованию
