#!/bin/bash
# transcribe.sh — per-file STT wrapper for Personal AI Assistant Stage 5.
# Calls xAI Grok STT API (/v1/stt), prints transcript text to stdout.
#
# Usage: transcribe.sh <audio_file> [language]
# Output (stdout): plain transcript text (one line if short, multi-line if long)
# Errors (stderr): diagnostic message
# Exit:  0 ok / 1 error
#
# Env (one of, checked in order):
#   XAI_API_KEY   — canonical
#   GROK_API_KEY  — legacy alias for compatibility with voice.mjs current code
#
# Telegram voice messages arrive as .ogg/opus, typically <1MB and <60s.
# Grok STT accepts ogg/mp3/wav/m4a/mp4 directly — no preprocessing for normal
# voice commands. ffmpeg fallback only triggers if direct upload fails.

set -euo pipefail

INPUT="${1:?usage: transcribe.sh <audio_file> [language]}"
LANG="${2:-ru}"
ENDPOINT="https://api.x.ai/v1/stt"
MAX_DIRECT_MB=20

KEY="${XAI_API_KEY:-${GROK_API_KEY:-}}"
[ -n "$KEY" ] || { echo "ERR: XAI_API_KEY (or GROK_API_KEY) not set" >&2; exit 1; }
[ -f "$INPUT" ] || { echo "ERR: file not found: $INPUT" >&2; exit 1; }

size_bytes=$(stat -c%s "$INPUT")
size_mb=$(( size_bytes / 1024 / 1024 ))

# For files > 20 MB convert to mp3 64kbps mono 16kHz first (always fits voice cmd budget).
upload_file="$INPUT"
tmp_audio=""
if [ "$size_mb" -ge "$MAX_DIRECT_MB" ]; then
  tmp_audio="$(mktemp --suffix=.mp3)"
  ffmpeg -loglevel error -i "$INPUT" -vn -ac 1 -ar 16000 -c:a libmp3lame -b:a 64k -y "$tmp_audio" \
    || { echo "ERR: ffmpeg conversion failed" >&2; rm -f "$tmp_audio"; exit 1; }
  upload_file="$tmp_audio"
fi

cleanup() { [ -n "$tmp_audio" ] && rm -f "$tmp_audio"; }
trap cleanup EXIT

response=$(curl -sS --max-time 60 -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $KEY" \
  -F "file=@$upload_file" \
  -F "language=$LANG" 2>&1) || { echo "ERR: curl failed: $response" >&2; exit 1; }

if ! echo "$response" | jq -e . >/dev/null 2>&1; then
  echo "ERR: non-json response: ${response:0:200}" >&2
  exit 1
fi

if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERR: api error: $(echo "$response" | jq -c .error)" >&2
  exit 1
fi

echo "$response" | jq -r '.text'
