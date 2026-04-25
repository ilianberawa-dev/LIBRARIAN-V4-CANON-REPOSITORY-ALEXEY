#!/bin/bash
# Telegram push notification of tg-export status.
# Reads /opt/tg-export/_status.json + computes AI costs.
# Sends via BotFather bot to user's chat (configured in .env).
# Cron: every 2 hours.

set -u

BASE=/opt/tg-export
ENV="$BASE/.env"

# Load config
if [ ! -f "$ENV" ]; then exit 0; fi
set -a; source "$ENV"; set +a

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "[$(date -u +%FT%TZ)] notify: BOT_TOKEN or CHAT_ID not set — skipping" >> "$BASE/heartbeat.log"
  exit 0
fi

# Status snapshot
S_FILE="$BASE/_status.json"
if [ ! -f "$S_FILE" ]; then
  bash "$BASE/heartbeat.sh"
fi
S=$(cat "$S_FILE")

# Local times (Bali WITA = UTC+8)
BALI_TIME=$(TZ='Asia/Makassar' date '+%H:%M %d.%m')
UTC_TIME=$(date -u '+%H:%M')

# Grok STT total audio seconds transcribed & cost
TOTAL_SEC=0
for f in "$BASE/transcripts/"*.transcript.json; do
  [ -f "$f" ] || continue
  # skip chunk parts (handled via merged files)
  case "$f" in *_part*) continue ;; esac
  d=$(jq -r '.duration // 0' "$f" 2>/dev/null)
  TOTAL_SEC=$(echo "$TOTAL_SEC + $d" | bc)
done
GROK_COST=$(echo "scale=4; $TOTAL_SEC / 3600 * 0.10" | bc 2>/dev/null || echo "0")
TOTAL_HOURS=$(echo "scale=2; $TOTAL_SEC / 3600" | bc 2>/dev/null || echo "0")

# Download progress
P1_OK=$(grep -c '\[ok P1\]\|\[skip P1\]' "$BASE/download.log" 2>/dev/null || echo 0)
P2_OK=$(grep -c '\[ok P2\]\|\[skip P2\]' "$BASE/download.log" 2>/dev/null || echo 0)
P3_OK=$(grep -c '\[ok P3\]\|\[skip P3\]' "$BASE/download.log" 2>/dev/null || echo 0)

# Status fields
DL_STATUS=$(echo "$S" | jq -r '.download.status')
DL_IDLE=$(echo "$S" | jq -r '.download.idle_sec')
TX_STATUS=$(echo "$S" | jq -r '.transcribe.status')
TX_COUNT=$(echo "$S" | jq -r '.transcripts_count')
MEDIA_FILES=$(echo "$S" | jq -r '.media_files')
MEDIA_MB=$(echo "$S" | jq -r '.media_bytes' | awk '{printf "%.0f", $1/1048576}')

# Compose
MSG="🌴 <b>TG-Export ${BALI_TIME}</b> (UTC ${UTC_TIME})

📥 <b>Download:</b> ${DL_STATUS} (idle ${DL_IDLE}s)
  P1 scripts/configs: ${P1_OK} / 27
  P2 PDFs/docs: ${P2_OK} / 7
  P3 photos: ${P3_OK} / 16

🎙 <b>Transcribe (Grok STT):</b> ${TX_STATUS}
  Files done: ${TX_COUNT}
  Audio: ${TOTAL_HOURS}h (${TOTAL_SEC}s)
  💰 Cost: \$${GROK_COST}

💾 Media on disk: ${MEDIA_FILES} files / ${MEDIA_MB} MB
"

# Send
RESPONSE=$(curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -d "parse_mode=HTML" 2>&1)

if echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
  echo "[$(date -u +%FT%TZ)] notify: sent OK" >> "$BASE/heartbeat.log"
else
  echo "[$(date -u +%FT%TZ)] notify: FAIL $RESPONSE" >> "$BASE/heartbeat.log"
fi
