#!/bin/bash
# Heartbeat for tg-export on Aeza.
# Runs via cron every 10 minutes. Self-healing:
#   - restarts download.mjs if stuck > max-expected-break + 5 min
#   - relaunches transcribe.sh if new untranscribed media files present
#   - writes /opt/tg-export/_status.json for at-a-glance state
#   - rotates logs when > 10 MB

set -eu

BASE=/opt/tg-export
LOG="$BASE/heartbeat.log"
STATUS="$BASE/_status.json"
MIN_PRIO="${MIN_PRIO:-1}"
MAX_PRIO="${MAX_PRIO:-4}"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"
}

# ---------- DOWNLOAD WATCHDOG ----------
check_download() {
  local dl_pid
  dl_pid=$(pgrep -f 'node download.mjs' | head -1)
  local dl_status="dead"
  local dl_idle=0
  local dl_action="none"

  if [ -n "$dl_pid" ]; then
    dl_status="running"
    # Is it actually making progress? Check log mtime
    if [ -f "$BASE/download.log" ]; then
      local last_mod=$(stat -c %Y "$BASE/download.log")
      local now=$(date +%s)
      dl_idle=$((now - last_mod))

      # Get last declared break duration (long-break or break)
      local expected_break=60  # default short
      if tail -5 "$BASE/download.log" | grep -qE '\[long-break\]'; then
        expected_break=$(tail -5 "$BASE/download.log" | grep -oP 'long-break.*~\K[0-9]+' | tail -1)
      elif tail -5 "$BASE/download.log" | grep -qE '\[break\]'; then
        expected_break=$(tail -5 "$BASE/download.log" | grep -oP 'break.*~\K[0-9]+' | tail -1)
      fi
      [ -z "$expected_break" ] && expected_break=60
      local max_idle=$(( expected_break * 60 + 300 ))  # +5 min buffer

      if [ "$dl_idle" -gt "$max_idle" ]; then
        log "[stuck] download idle=${dl_idle}s > max=${max_idle}s (expected break ${expected_break}min) — killing+restarting"
        kill "$dl_pid" 2>/dev/null
        sleep 3
        cd "$BASE"
        nohup node download.mjs 0 $MIN_PRIO $MAX_PRIO >> download.log 2>&1 &
        local new_pid=$!
        log "[restarted] download new PID=$new_pid"
        dl_action="restarted_stuck"
        dl_status="restarted"
        dl_pid=$new_pid
      fi
    fi
  else
    # Not running — is it done?
    if [ -f "$BASE/media/_manifest.json" ] && jq -e '.finished' "$BASE/media/_manifest.json" >/dev/null 2>&1; then
      dl_status="completed"
      log "[done] download completed cleanly"
    else
      log "[dead] download not running and not finished — restarting"
      cd "$BASE"
      nohup node download.mjs 0 $MIN_PRIO $MAX_PRIO >> download.log 2>&1 &
      dl_pid=$!
      log "[restarted] download PID=$dl_pid (was dead)"
      dl_action="restarted_dead"
      dl_status="restarted"
    fi
  fi

  echo "{\"pid\":\"$dl_pid\",\"status\":\"$dl_status\",\"idle_sec\":$dl_idle,\"action\":\"$dl_action\"}"
}

# ---------- TRANSCRIBE WATCHDOG ----------
check_transcribe() {
  local tx_pid
  tx_pid=$(pgrep -f 'transcribe.sh' | head -1)
  local tx_status="idle"
  local tx_pending=0
  local tx_action="none"

  if [ -n "$tx_pid" ]; then
    tx_status="running"
  else
    # Count untranscribed media
    shopt -s nullglob
    local missing=0
    for f in "$BASE/media/"*.mp4 "$BASE/media/"*.wav "$BASE/media/"*.m4a "$BASE/media/"*.mp3 "$BASE/media/"*.mov "$BASE/media/"*.webm "$BASE/media/"*.mkv; do
      [ -f "$f" ] || continue
      local fname=$(basename "$f")
      local sanitized=$(echo "$fname" | tr ' ' '_' | sed 's/[^a-zA-Z0-9._а-яА-ЯёЁ-]/_/g')
      if [ ! -s "$BASE/transcripts/${sanitized}.transcript.txt" ]; then
        missing=$((missing+1))
      fi
    done
    tx_pending=$missing

    if [ "$missing" -gt 0 ]; then
      log "[new-media] $missing untranscribed — launching transcribe.sh"
      nohup bash "$BASE/transcribe.sh" >> "$BASE/transcribe.log" 2>&1 &
      tx_pid=$!
      tx_status="started"
      tx_action="launched"
      log "[started] transcribe PID=$tx_pid"
    fi
  fi

  echo "{\"pid\":\"$tx_pid\",\"status\":\"$tx_status\",\"pending\":$tx_pending,\"action\":\"$tx_action\"}"
}

# ---------- LOG ROTATION ----------
rotate_logs() {
  for f in download.log transcribe.log heartbeat.log; do
    local path="$BASE/$f"
    if [ -f "$path" ]; then
      local size=$(stat -c%s "$path")
      if [ "$size" -gt 10485760 ]; then  # 10 MB
        mv "$path" "${path}.$(date +%Y%m%d_%H%M%S)"
        log "[rotated] $f (was ${size}B)"
      fi
    fi
  done
}

# ---------- MAIN ----------
mkdir -p "$BASE"
log "[tick]"

DL_JSON=$(check_download)
TX_JSON=$(check_transcribe)
rotate_logs

# Status snapshot
FILES_COUNT=$(find "$BASE/media/" -maxdepth 1 -type f ! -name '_*' 2>/dev/null | wc -l)
MEDIA_BYTES=$(du -sb "$BASE/media/" 2>/dev/null | awk '{print $1}')
TX_COUNT=$(find "$BASE/transcripts/" -maxdepth 1 -name '*.transcript.txt' 2>/dev/null | wc -l)
TX_BYTES=$(du -sb "$BASE/transcripts/" 2>/dev/null | awk '{print $1}')

cat > "$STATUS" <<EOF
{
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "download": $DL_JSON,
  "transcribe": $TX_JSON,
  "media_files": $FILES_COUNT,
  "media_bytes": ${MEDIA_BYTES:-0},
  "transcripts_count": $TX_COUNT,
  "transcripts_bytes": ${TX_BYTES:-0}
}
EOF
