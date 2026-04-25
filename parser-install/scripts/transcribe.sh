#!/bin/bash
# Transcribe all video/audio media files via Grok STT (xAI).
# Uses /v1/stt endpoint. Handles video (extracts audio) and audio files.
# Splits large files into chunks if needed (conservative 20MB threshold).
# Writes _transcripts/{msg_id}_{name}.transcript.json + .txt
# Incremental: skips already-transcribed.

set -eu

MEDIA_DIR="/opt/tg-export/media"
OUT_DIR="/opt/tg-export/transcripts"
CHUNK_DIR="/opt/tg-export/_chunks"
LOG="$OUT_DIR/_progress.log"
MANIFEST="$OUT_DIR/_manifest.json"

CHUNK_SIZE_BYTES=$((20 * 1024 * 1024))   # 20 MB upload chunks (safe)
CHUNK_SECONDS=600                         # 10 min chunks
ENDPOINT="https://api.x.ai/v1/stt"

mkdir -p "$OUT_DIR" "$CHUNK_DIR"

set -a; source /opt/tg-export/.env; set +a

log() {
  local line="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
  echo "$line"
  echo "$line" >> "$LOG"
}

seconds_to_hhmmss() {
  local s=$1
  printf "%02d:%02d:%06.3f" $((s/3600)) $(((s%3600)/60)) $(echo "$s - ($s/60)*60" | bc -l 2>/dev/null || echo 0)
}

transcribe_file() {
  local src="$1"
  local base_name="$2"
  local start_offset="${3:-0}"    # For chunked files
  local out_json="$OUT_DIR/${base_name}.transcript.json"

  local curl_out
  curl_out=$(curl -sS --max-time 600 -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $XAI_API_KEY" \
    -F "file=@$src" 2>&1)

  if echo "$curl_out" | jq -e . >/dev/null 2>&1; then
    if echo "$curl_out" | jq -e '.error' >/dev/null 2>&1; then
      log "[err] $src: $(echo "$curl_out" | jq -c .)"
      return 1
    fi
    echo "$curl_out" > "$out_json"
    local dur=$(echo "$curl_out" | jq -r '.duration // 0')
    local chars=$(echo "$curl_out" | jq -r '.text | length // 0')
    log "[ok] $base_name dur=${dur}s text=${chars}ch"
    return 0
  else
    log "[err] $src: non-json response: ${curl_out:0:200}"
    return 1
  fi
}

process_media() {
  local src="$1"
  local fname=$(basename "$src")
  local sanitized=$(echo "$fname" | tr ' ' '_' | sed 's/[^a-zA-Z0-9._а-яА-ЯёЁ-]/_/g')
  local out_json="$OUT_DIR/${sanitized}.transcript.json"
  local out_txt="$OUT_DIR/${sanitized}.transcript.txt"

  if [ -f "$out_json" ] && [ -s "$out_json" ]; then
    log "[skip] $fname (already transcribed)"
    return 0
  fi

  log "[start] $fname"

  local tmp_audio="$CHUNK_DIR/${sanitized}.mp3"
  local is_video
  is_video=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=codec_type -of csv=p=0 "$src" 2>/dev/null | head -1 || true)

  if [ "$is_video" = "video" ]; then
    log "[extract] ${fname} -> mp3 64kbps mono 16kHz"
    ffmpeg -loglevel error -i "$src" -vn -ac 1 -ar 16000 -c:a libmp3lame -b:a 64k -y "$tmp_audio"
  else
    log "[convert] ${fname} -> mp3 64kbps mono 16kHz (from audio)"
    ffmpeg -loglevel error -i "$src" -vn -ac 1 -ar 16000 -c:a libmp3lame -b:a 64k -y "$tmp_audio"
  fi

  local audio_size=$(stat -c%s "$tmp_audio")
  local duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp_audio" 2>/dev/null | head -1)
  log "[ready] ${sanitized}.mp3 size=${audio_size}B duration=${duration}s"

  if [ "$audio_size" -le "$CHUNK_SIZE_BYTES" ]; then
    transcribe_file "$tmp_audio" "$sanitized" 0
    if [ -f "$OUT_DIR/${sanitized}.transcript.json" ]; then
      jq -r '.text' "$OUT_DIR/${sanitized}.transcript.json" > "$out_txt"
    fi
  else
    log "[split] audio > 20MB, splitting into ${CHUNK_SECONDS}s chunks"
    local chunk_prefix="$CHUNK_DIR/${sanitized}_chunk_"
    ffmpeg -loglevel error -i "$tmp_audio" -f segment -segment_time "$CHUNK_SECONDS" -c copy -y "${chunk_prefix}%03d.mp3"
    local chunks=("${chunk_prefix}"*.mp3)
    local combined_text=""
    local combined_words="[]"
    local offset=0
    local i=0
    for chunk in "${chunks[@]}"; do
      local chunk_name="${sanitized}_part$(printf %03d $i)"
      log "[chunk] $chunk_name offset=${offset}s"
      transcribe_file "$chunk" "$chunk_name" "$offset"
      local chunk_json="$OUT_DIR/${chunk_name}.transcript.json"
      if [ -f "$chunk_json" ]; then
        combined_text="$combined_text $(jq -r '.text' "$chunk_json")"
        local chunk_words=$(jq --argjson off "$offset" '.words | map(.start += $off | .end += $off)' "$chunk_json")
        combined_words=$(jq -n --argjson a "$combined_words" --argjson b "$chunk_words" '$a + $b')
        local chunk_dur=$(jq -r '.duration' "$chunk_json")
        offset=$(echo "$offset + $chunk_dur" | bc)
      fi
      i=$((i+1))
      sleep 2
    done
    jq -n --arg text "$combined_text" --argjson words "$combined_words" --argjson dur "$offset" \
      '{text: $text, words: $words, duration: $dur, chunked: true}' > "$out_json"
    echo "$combined_text" > "$out_txt"
    log "[merged] $sanitized total_dur=${offset}s"
    rm -f "${chunk_prefix}"*.mp3
  fi

  rm -f "$tmp_audio"

  # Rule: delete source media after successful transcription
  # Verify both .transcript.json and .transcript.txt exist and non-empty before rm
  if [ -s "$out_json" ] && [ -s "$out_txt" ]; then
    log "[delete-source] $fname (transcript verified)"
    rm -f "$src"
  else
    log "[keep-source] $fname (transcript incomplete — kept for retry)"
  fi
}

# Main loop: find all video/audio files
log "[START] transcribe.sh"

shopt -s nullglob
for f in "$MEDIA_DIR"/*.mp4 "$MEDIA_DIR"/*.wav "$MEDIA_DIR"/*.mov "$MEDIA_DIR"/*.m4a "$MEDIA_DIR"/*.mp3 "$MEDIA_DIR"/*.webm "$MEDIA_DIR"/*.mkv "$MEDIA_DIR"/*.avi; do
  [ -f "$f" ] || continue
  process_media "$f" || log "[err] failed $f"
done

log "[END] transcribe.sh"
