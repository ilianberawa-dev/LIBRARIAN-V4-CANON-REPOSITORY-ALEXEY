#!/bin/bash
# Запускает транскрибацию untranscribed media
# Источник: navyki/claude-bot-parser-control.md

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"

cd "$PARSER_DIR"

# Count untranscribed
UNTRANSCRIBED=0
shopt -s nullglob
for f in media/*.mp4 media/*.wav media/*.m4a media/*.mp3 media/*.mov media/*.webm media/*.mkv; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  if [ ! -f "transcripts/${fname}.transcript.txt" ]; then
    UNTRANSCRIBED=$((UNTRANSCRIBED + 1))
  fi
done
shopt -u nullglob

if [ "$UNTRANSCRIBED" -eq 0 ]; then
  echo "✅ No untranscribed media files"
  exit 0
fi

echo "🎙 Found $UNTRANSCRIBED untranscribed files"
echo "Starting transcribe.sh..."
echo

nohup bash transcribe.sh >> transcribe.log 2>&1 &
PID=$!

echo "✅ Transcribe started (PID: $PID)"
echo
echo "Monitor:"
echo "  tail -f $PARSER_DIR/transcribe.log"
