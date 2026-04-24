#!/bin/bash
# Показывает последние логи парсера
# Args: [component] [lines]
#   component: download | transcribe | sync | heartbeat
#   lines: число строк (по умолчанию 30)
# Source: navyki/claude-bot-parser-control.md

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"
COMPONENT="${1:-download}"
LINES="${2:-30}"

LOG_FILE="$PARSER_DIR/${COMPONENT}.log"

if [ ! -f "$LOG_FILE" ]; then
  echo "❌ Log not found: $LOG_FILE"
  echo
  echo "Available logs:"
  ls -1 "$PARSER_DIR"/*.log 2>/dev/null | sed 's/.*\//  - /'
  exit 1
fi

echo "📄 Last $LINES lines of $COMPONENT.log:"
echo
tail -n "$LINES" "$LOG_FILE"
