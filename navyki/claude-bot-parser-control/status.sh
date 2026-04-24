#!/bin/bash
# Показывает статус парсера
# Источник: navyki/claude-bot-parser-control.md (Aeza proven pattern)

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"
STATUS_FILE="$PARSER_DIR/_status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ Parser not initialized. Run heartbeat first:"
  echo "   bash $PARSER_DIR/heartbeat.sh"
  exit 1
fi

echo "📊 Parser Status ($(date '+%H:%M %d.%m')):"
echo

# Parse JSON
cat "$STATUS_FILE" | jq -r '
  "Updated: \(.updated)",
  "",
  "📥 Download:",
  "  Status: \(.download.status)",
  "  PID: \(.download.pid)",
  "  Idle: \(.download.idle_sec)s",
  "",
  "🎙 Transcribe:",
  "  Status: \(.transcribe.status)",
  "  Pending: \(.transcribe.pending) files",
  "",
  "💾 Storage:",
  "  Media: \(.media_files) files (\(.media_bytes / 1048576 | floor)MB)",
  "  Transcripts: \(.transcripts_count) files"
'

# Check processes
echo
echo "🔄 Running processes:"
pgrep -f "node download.mjs" >/dev/null && echo "  ✅ download.mjs" || echo "  ❌ download.mjs"
pgrep -f "transcribe.sh" >/dev/null && echo "  ✅ transcribe.sh" || echo "  ❌ transcribe.sh"
