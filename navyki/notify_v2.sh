#!/bin/bash
# TG Parser progress report — RUNTIME counts (no hardcoded numbers)
# Honest: shows what's expected vs done per category, lists missing msg_ids
set -u

BASE=/opt/tg-export
ENV="$BASE/.env"
[ ! -f "$ENV" ] && exit 0
set -a; source "$ENV"; set +a
[ -z "${BOT_TOKEN:-}" ] || [ -z "${CHAT_ID:-}" ] && exit 0

INDEX="$BASE/library_index.json"
TX_DIR="$BASE/transcripts"
GH_MEDIA="$BASE/.github-repo/alexey-materials/media"

BALI_TIME=$(TZ='Asia/Makassar' date '+%H:%M %d.%m')
UTC_TIME=$(date -u '+%H:%M')

# === RUNTIME COUNTS ===
TOTAL_POSTS=$(jq '.total_posts' "$INDEX")
TEXT_POSTS=$(jq '[.posts[] | select(.type == "text")] | length' "$INDEX")

# Expected per category
P1_TOTAL=$(jq '[.posts[] | select(.filename != null) | select(.filename | endswith(".mp4"))] | length' "$INDEX")
P2_TOTAL=$(jq '[.posts[] | select(.filename != null) | select(.filename | endswith(".wav"))] | length' "$INDEX")
P3_TOTAL=$(jq '[.posts[] | select(.filename != null) | select(.filename | endswith(".zip"))] | length' "$INDEX")
P4_TOTAL=$(jq '[.posts[] | select(.filename != null) | select(.filename | startswith("media_"))] | length' "$INDEX")

# Done per category
DONE_IDS=$(find "$TX_DIR" -name "*.transcript.json" ! -name "*_part*" -printf "%f\n" 2>/dev/null \
  | grep -oE "^[0-9]+" | sort)

count_done() {
  local ext=$1
  local expected=$(jq -r ".posts[] | select(.filename != null) | select(.filename | endswith(\"$ext\")) | .msg_id" "$INDEX" | sort)
  echo "$DONE_IDS" | comm -12 - <(echo "$expected") | wc -l
}

P1_OK=$(count_done ".mp4")
P2_OK=$(count_done ".wav")
# Documents — check if file exists in github-repo
P3_OK=0
for f in $(jq -r '.posts[] | select(.filename != null) | select(.filename | endswith(".zip")) | .filename' "$INDEX"); do
  [ -f "$GH_MEDIA/$f" ] && P3_OK=$((P3_OK + 1))
done

# Photos/voice — check media/ dir
P4_OK=0
for id in $(jq -r '.posts[] | select(.filename != null) | select(.filename | startswith("media_")) | .msg_id' "$INDEX"); do
  if find "$BASE/media" -maxdepth 1 -name "${id}_*" 2>/dev/null | grep -q .; then
    P4_OK=$((P4_OK + 1))
  fi
done

# Percentages
pct() { local n=${1:-0}; local d=${2:-0}; [ "$d" -gt 0 ] && echo $((n * 100 / d)) || echo 0; }
P1_PCT=$(pct $P1_OK $P1_TOTAL)
P2_PCT=$(pct $P2_OK $P2_TOTAL)
P3_PCT=$(pct $P3_OK $P3_TOTAL)
P4_PCT=$(pct $P4_OK $P4_TOTAL)

# Progress bar
render_bar() {
  local pct=${1:-0}
  local blocks=$((pct / 10))
  local bar="" i
  for ((i=0; i<blocks; i++)); do bar+="▓"; done
  for ((i=blocks; i<10; i++)); do bar+="░"; done
  echo "$bar"
}
P1_BAR=$(render_bar $P1_PCT)
P2_BAR=$(render_bar $P2_PCT)
P3_BAR=$(render_bar $P3_PCT)
P4_BAR=$(render_bar $P4_PCT)

# Missing video msg_ids (truncate to first 15 if many)
jq -r '.posts[] | select(.filename != null) | select(.filename | endswith(".mp4")) | .msg_id' "$INDEX" | sort > /tmp/_exp.txt
echo "$DONE_IDS" > /tmp/_done.txt
MISSING_VIDEOS=$(comm -23 /tmp/_exp.txt /tmp/_done.txt | sort -n | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

# Missing total size (in GB) — re-read missing ids from /tmp file
MISSING_SIZE_MB=$(cat /tmp/_exp.txt | comm -23 - /tmp/_done.txt | while read id; do
  jq -r --argjson m "$id" '.posts[] | select(.msg_id == $m) | .size_mb' "$INDEX"
done | awk '{s+=$1} END {printf "%.0f", s}')
MISSING_SIZE_GB=$(echo "scale=1; $MISSING_SIZE_MB / 1024" | bc 2>/dev/null || echo "0")

# Grok STT cost
TOTAL_SEC=0
for f in "$TX_DIR/"*.transcript.json; do
  [ -f "$f" ] || continue
  case "$f" in *_part*) continue ;; esac
  d=$(jq -r '.duration // 0' "$f" 2>/dev/null)
  TOTAL_SEC=$(echo "$TOTAL_SEC + $d" | bc 2>/dev/null || echo "$TOTAL_SEC")
done
TOTAL_HOURS=$(echo "scale=1; $TOTAL_SEC / 3600" | bc 2>/dev/null || echo "0")
GROK_COST=$(echo "scale=2; $TOTAL_SEC / 3600 * 0.10" | bc 2>/dev/null || echo "0")

# Total transcripts done
TX_TOTAL=$((P1_TOTAL + P2_TOTAL))
TX_DONE=$((P1_OK + P2_OK))
TX_PCT=$(pct $TX_DONE $TX_TOTAL)
TX_BAR=$(render_bar $TX_PCT)

# DB count
TRANSCRIPTS_DB=$(docker exec supabase-db psql -U postgres -d postgres -t -c \
  "SELECT COUNT(*) FROM telegram_transcripts;" 2>/dev/null | xargs || echo "?")

# Last transcript (UTF-8 safe truncation via Python)
LAST_TX=$(find "$TX_DIR" -name "*.transcript.json" ! -name "*_part*" -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
LAST_TX_INFO=""
if [ -n "$LAST_TX" ]; then
  LAST_MSG_ID=$(basename "$LAST_TX" | grep -oP '^\d+')
  LAST_NAME=$(basename "$LAST_TX" .transcript.json | sed "s/^${LAST_MSG_ID}_//" | python3 -c "import sys; print(sys.stdin.read().strip()[:35])")
  LAST_DUR=$(jq -r '.duration // 0' "$LAST_TX" 2>/dev/null | awk '{printf "%.0f", $1/60}')
  LAST_TX_INFO="
  Последний: #${LAST_MSG_ID} ${LAST_NAME} (${LAST_DUR} мин)"
fi

# Compose message — prev form (P1/P2/P3) adapted for this channel's content
MSG="🌴 <b>TG-Export ${BALI_TIME}</b> (UTC ${UTC_TIME})

📊 <b>База:</b> ${TOTAL_POSTS} постов в канале
  Тексты: ${TEXT_POSTS} (без файлов)

📥 <b>Скачивание + Транскрипция:</b>

  <code>P1 ${P1_BAR} ${P1_PCT}%</code>
  Видео .mp4: ${P1_OK}/${P1_TOTAL}

  <code>P2 ${P2_BAR} ${P2_PCT}%</code>
  Аудио .wav: ${P2_OK}/${P2_TOTAL}

  <code>P3 ${P3_BAR} ${P3_PCT}%</code>
  Документы .zip: ${P3_OK}/${P3_TOTAL}

  <code>P4 ${P4_BAR} ${P4_PCT}%</code>
  Фото/voice: ${P4_OK}/${P4_TOTAL}

🎙 <b>Всего транскриптов:</b> ${TX_DONE}/${TX_TOTAL} • ${TX_PCT}%
<code>${TX_BAR}</code>
  В БД: ${TRANSCRIPTS_DB}${LAST_TX_INFO}
  Аудио: ${TOTAL_HOURS}ч
  💰 Grok STT: \$${GROK_COST}

🚧 <b>Не сделано:</b>
  Видео msg_id: ${MISSING_VIDEOS:-—}
  Размер очереди: ${MISSING_SIZE_GB:-0}GB (${MISSING_SIZE_MB:-0}MB)"

RESPONSE=$(curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -d "parse_mode=HTML" 2>&1)

if echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
  echo "[$(date -u +%FT%TZ)] notify_v2: sent OK" >> "$BASE/heartbeat.log"
else
  echo "[$(date -u +%FT%TZ)] notify_v2: FAIL $RESPONSE" >> "$BASE/heartbeat.log"
fi
