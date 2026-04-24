#!/bin/bash
# Telegram Notify Template — отправляет status в Telegram
# Источник: /opt/tg-export/notify.sh (Aeza proven pattern)
# Применение: AI Assistant status notifications
# Дата: 2026-04-24

set -u

# ========== КОНФИГУРАЦИЯ ==========
BASE="${BASE_DIR:-$HOME/.claude/assistant}"
STATUS_FILE="$BASE/_status.json"
ENV_FILE="${ENV_FILE:-$BASE/.env}"

# Load .env если есть
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
fi

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

# ========== VALIDATE ==========
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "[$(date -u +%FT%TZ)] notify: BOT_TOKEN or CHAT_ID not set — create .env file" >&2
  echo "# Пример .env файла:" >&2
  echo "BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11" >&2
  echo "CHAT_ID=123456789" >&2
  exit 1
fi

if [ ! -f "$STATUS_FILE" ]; then
  echo "[$(date -u +%FT%TZ)] notify: status file not found — run heartbeat.sh first" >&2
  exit 1
fi

# ========== READ STATUS ==========
S=$(cat "$STATUS_FILE")

# ========== PARSE DATA ==========
UPDATED=$(echo "$S" | jq -r '.updated')
MEM_STATUS=$(echo "$S" | jq -r '.memory.status')
MEM_AGE_H=$(echo "$S" | jq -r '.memory.age_sec / 3600 | floor')
THINK_STATUS=$(echo "$S" | jq -r '.proactive_think.status')
THINK_IDLE_H=$(echo "$S" | jq -r '.proactive_think.idle_sec / 3600 | floor')
DISK=$(echo "$S" | jq -r '.disk_usage')
FILES=$(echo "$S" | jq -r '.memory_files')

# Local time (измени timezone если нужно)
LOCAL_TIME=$(TZ='Asia/Makassar' date '+%H:%M %d.%m')  # Bali WITA = UTC+8
UTC_TIME=$(date -u '+%H:%M')

# Status emoji
case "$MEM_STATUS" in
  fresh) MEM_EMOJI="✅" ;;
  ok) MEM_EMOJI="🟢" ;;
  stale) MEM_EMOJI="⚠️" ;;
  *) MEM_EMOJI="❓" ;;
esac

case "$THINK_STATUS" in
  ok) THINK_EMOJI="✅" ;;
  overdue) THINK_EMOJI="⚠️" ;;
  never_run) THINK_EMOJI="🆕" ;;
  *) THINK_EMOJI="❓" ;;
esac

# ========== COMPOSE MESSAGE ==========
MSG="🤖 <b>AI Assistant Status</b>
${LOCAL_TIME} (UTC ${UTC_TIME})

${MEM_EMOJI} <b>Memory:</b> ${MEM_STATUS} (${MEM_AGE_H}h ago)
${THINK_EMOJI} <b>Proactive:</b> ${THINK_STATUS} (${THINK_IDLE_H}h idle)

💾 <b>Disk:</b> ${DISK} / ${FILES} files

<i>Last update: ${UPDATED}</i>
"

# ========== SEND ==========
RESPONSE=$(curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -d "parse_mode=HTML" 2>&1)

# ========== LOG RESULT ==========
LOG_FILE="$BASE/heartbeat.log"
if echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
  echo "[$(date -u +%FT%TZ)] notify: sent OK" >> "$LOG_FILE"
  exit 0
else
  echo "[$(date -u +%FT%TZ)] notify: FAIL $RESPONSE" >> "$LOG_FILE"
  exit 1
fi
