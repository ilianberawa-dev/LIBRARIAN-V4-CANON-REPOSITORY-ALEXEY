#!/bin/bash
# Heartbeat Template — адаптируй под свой проект
# Источник: /opt/tg-export/heartbeat.sh (Aeza proven pattern)
# Применение: AI Assistant, long-running процессы
# Дата: 2026-04-24

set -eu

# ========== КОНФИГУРАЦИЯ (измени под себя) ==========
BASE="${BASE_DIR:-$HOME/.claude/assistant}"  # Базовая директория
LOG="$BASE/heartbeat.log"
STATUS="$BASE/_status.json"

# Telegram notify (опционально)
TELEGRAM_NOTIFY="${TELEGRAM_NOTIFY:-false}"
BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

# ========== УТИЛИТЫ ==========
log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"
}

rotate_logs() {
  for f in heartbeat.log assistant.log; do
    local path="$BASE/$f"
    if [ -f "$path" ]; then
      local size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || echo 0)
      if [ "$size" -gt 10485760 ]; then  # 10 MB
        mv "$path" "${path}.$(date +%Y%m%d_%H%M%S)"
        log "[rotated] $f (was ${size}B)"
      fi
    fi
  done
}

# ========== ПРОВЕРКИ (адаптируй под свой процесс) ==========

check_memory_sync() {
  # Проверяем что memory обновлялась недавно
  local memory_file="$BASE/memory/MEMORY.md"
  local mem_status="unknown"
  local mem_age=0
  local mem_action="none"

  if [ -f "$memory_file" ]; then
    local last_mod=$(stat -c %Y "$memory_file" 2>/dev/null || stat -f %m "$memory_file" 2>/dev/null)
    local now=$(date +%s)
    mem_age=$((now - last_mod))

    if [ "$mem_age" -lt 86400 ]; then  # <24h
      mem_status="fresh"
    elif [ "$mem_age" -lt 259200 ]; then  # <3 days
      mem_status="ok"
    else
      mem_status="stale"
      log "[stale] memory not updated in $(($mem_age / 86400)) days"
      # Триггер sync если нужно
      # claude-skill memory-sync || true
      mem_action="needs_sync"
    fi
  else
    mem_status="missing"
    log "[missing] memory file not found"
  fi

  echo "{\"status\":\"$mem_status\",\"age_sec\":$mem_age,\"action\":\"$mem_action\"}"
}

check_proactive_think() {
  # Проверяем когда последний раз был proactive-think
  local think_file="$BASE/last-proactive.txt"
  local think_status="unknown"
  local think_idle=0
  local think_action="none"

  if [ -f "$think_file" ]; then
    local last_think=$(cat "$think_file")
    local now=$(date +%s)
    think_idle=$((now - last_think))

    if [ "$think_idle" -gt 21600 ]; then  # >6h
      think_status="overdue"
      log "[overdue] proactive-think not run in $(($think_idle / 3600))h"
      # Триггер proactive-think если нужно
      # claude-skill proactive-think || true
      echo "$now" > "$think_file"
      think_action="triggered"
    else
      think_status="ok"
    fi
  else
    think_status="never_run"
    log "[init] creating last-proactive.txt"
    date +%s > "$think_file"
  fi

  echo "{\"status\":\"$think_status\",\"idle_sec\":$think_idle,\"action\":\"$think_action\"}"
}

check_custom_process() {
  # TEMPLATE: замени на свой процесс
  # Пример: проверка что download.mjs запущен
  local proc_name="${WATCH_PROCESS:-assistant}"  # имя процесса для мониторинга
  local proc_pid
  proc_pid=$(pgrep -f "$proc_name" | head -1)
  local proc_status="stopped"

  if [ -n "$proc_pid" ]; then
    proc_status="running"
  else
    proc_status="stopped"
    log "[stopped] $proc_name not running"
    # Auto-restart если нужно:
    # nohup your-command >> "$BASE/process.log" 2>&1 &
  fi

  echo "{\"pid\":\"${proc_pid:-null}\",\"status\":\"$proc_status\"}"
}

# ========== TELEGRAM NOTIFY ==========
send_telegram() {
  if [ "$TELEGRAM_NOTIFY" != "true" ] || [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    return 0
  fi

  local msg="$1"

  curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${msg}" \
    -d "parse_mode=HTML" >/dev/null 2>&1
}

# ========== MAIN ==========
mkdir -p "$BASE/memory" "$BASE/logs"

log "[tick]"

# Запускаем проверки
MEMORY_JSON=$(check_memory_sync)
THINK_JSON=$(check_proactive_think)
CUSTOM_JSON=$(check_custom_process)

# Rotate logs
rotate_logs

# Формируем status snapshot
DISK_USAGE=$(du -sh "$BASE" 2>/dev/null | awk '{print $1}' || echo "0")
MEMORY_COUNT=$(find "$BASE/memory" -type f 2>/dev/null | wc -l)

cat > "$STATUS" <<EOF
{
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "memory": $MEMORY_JSON,
  "proactive_think": $THINK_JSON,
  "custom_process": $CUSTOM_JSON,
  "disk_usage": "$DISK_USAGE",
  "memory_files": $MEMORY_COUNT
}
EOF

# Опционально: отправить в Telegram если есть проблемы
if echo "$MEMORY_JSON" | grep -q '"action":"needs_sync"' || \
   echo "$THINK_JSON" | grep -q '"action":"triggered"'; then
  MSG="⚠️ AI Assistant Heartbeat

$(cat "$STATUS" | jq -r '.memory.status') memory ($(cat "$STATUS" | jq -r '.memory.age_sec / 3600')h)
$(cat "$STATUS" | jq -r '.proactive_think.status') proactive ($(cat "$STATUS" | jq -r '.proactive_think.idle_sec / 3600')h)

Last check: $(date '+%H:%M %d.%m')"

  send_telegram "$MSG"
fi

log "[done] status written to $STATUS"
