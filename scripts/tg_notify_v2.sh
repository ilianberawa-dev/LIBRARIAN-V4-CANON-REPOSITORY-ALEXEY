#!/bin/bash
# Telegram notification - IMPROVED VERSION v2
# Цветная визуализация прогресса с процентами
# Для TG-парсера канала Алексея

set -u

BASE=/opt/tg-export
ENV="$BASE/.env"

if [ ! -f "$ENV" ]; then exit 0; fi
set -a; source "$ENV"; set +a

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  exit 0
fi

# Status snapshot
S_FILE="$BASE/_status.json"
[ ! -f "$S_FILE" ] && bash "$BASE/heartbeat.sh"
S=$(cat "$S_FILE")

# Times
BALI_TIME=$(TZ='Asia/Makassar' date '+%H:%M %d.%m')
UTC_TIME=$(date -u '+%H:%M')

# Grok STT stats
TOTAL_SEC=0
for f in "$BASE/transcripts/"*.transcript.json; do
  [ -f "$f" ] || continue
  case "$f" in *_part*) continue ;; esac
  d=$(jq -r '.duration // 0' "$f" 2>/dev/null)
  TOTAL_SEC=$(echo "$TOTAL_SEC + $d" | bc)
done
GROK_COST=$(echo "scale=2; $TOTAL_SEC / 3600 * 0.10" | bc 2>/dev/null || echo "0")
TOTAL_HOURS=$(echo "scale=1; $TOTAL_SEC / 3600" | bc 2>/dev/null || echo "0")

# Download progress with percentages
P1_OK=$(grep -c '\[ok P1\]\|\[skip P1\]' "$BASE/download.log" 2>/dev/null || echo 0)
P2_OK=$(grep -c '\[ok P2\]\|\[skip P2\]' "$BASE/download.log" 2>/dev/null || echo 0)
P3_OK=$(grep -c '\[ok P3\]\|\[skip P3\]' "$BASE/download.log" 2>/dev/null || echo 0)

P1_TOTAL=27
P2_TOTAL=7
P3_TOTAL=16

P1_PCT=$((P1_OK * 100 / P1_TOTAL))
P2_PCT=$((P2_OK * 100 / P2_TOTAL))
P3_PCT=$((P3_OK * 100 / P3_TOTAL))

# Progress bars (10 blocks each)
render_bar() {
  local pct=$1
  local blocks=$((pct / 10))
  local bar=""
  local i
  for ((i=0; i<blocks; i++)); do bar+="▓"; done
  for ((i=blocks; i<10; i++)); do bar+="░"; done
  echo "$bar"
}

P1_BAR=$(render_bar $P1_PCT)
P2_BAR=$(render_bar $P2_PCT)
P3_BAR=$(render_bar $P3_PCT)

# Status indicators
DL_STATUS=$(echo "$S" | jq -r '.download.status')
DL_IDLE=$(echo "$S" | jq -r '.download.idle_sec')
TX_STATUS=$(echo "$S" | jq -r '.transcribe.status')
TX_COUNT=$(echo "$S" | jq -r '.transcripts_count')
MEDIA_FILES=$(echo "$S" | jq -r '.media_files')
MEDIA_MB=$(echo "$S" | jq -r '.media_bytes' | awk '{printf "%.0f", $1/1048576}')

# Compose message with visual progress
MSG="🌴 <b>TG-Export ${BALI_TIME}</b> (UTC ${UTC_TIME})

📥 <b>Download:</b> ${DL_STATUS} (idle ${DL_IDLE}s)

  <code>P1 ${P1_BAR} ${P1_PCT}%</code>
  scripts/configs: ${P1_OK}/${P1_TOTAL}

  <code>P2 ${P2_BAR} ${P2_PCT}%</code>
  PDFs/docs: ${P2_OK}/${P2_TOTAL}

  <code>P3 ${P3_BAR} ${P3_PCT}%</code>
  photos: ${P3_OK}/${P3_TOTAL}

🎙 <b>Transcribe (Grok STT):</b> ${TX_STATUS}
  Files done: ${TX_COUNT}
  Audio: ${TOTAL_HOURS}h (${TOTAL_SEC}s)
  💰 Cost: \$${GROK_COST}

💾 Media: ${MEDIA_FILES} files / ${MEDIA_MB} MB
"

# Send
RESPONSE=$(curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -d "parse_mode=HTML" 2>&1)

if echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
  echo "[$(date -u +%FT%TZ)] notify_v2: sent OK" >> "$BASE/heartbeat.log"
else
  echo "[$(date -u +%FT%TZ)] notify_v2: FAIL $RESPONSE" >> "$BASE/heartbeat.log"
fi
