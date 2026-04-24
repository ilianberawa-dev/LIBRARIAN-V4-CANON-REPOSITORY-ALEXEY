#!/bin/bash
# Запускает download с параметрами
# Args: [limit] [minPrio] [maxPrio]
#   limit: 0=all, N=first N messages
#   minPrio/maxPrio: 1=scripts, 2=docs, 3=photos, 4=video
# Source: navyki/claude-bot-parser-control.md

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"

LIMIT="${1:-0}"
MIN_PRIO="${2:-1}"
MAX_PRIO="${3:-3}"

echo "📥 Starting download..."
echo "  Limit: $LIMIT (0=all)"
echo "  Priority: P$MIN_PRIO - P$MAX_PRIO"
echo

cd "$PARSER_DIR" || { echo "❌ PARSER_DIR not found: $PARSER_DIR"; exit 1; }

if pgrep -f "node download.mjs" >/dev/null; then
  PID=$(pgrep -f "node download.mjs")
  echo "⚠️  Download already running (PID: $PID)"
  echo
  echo "Options:"
  echo "  1. Kill existing: kill $PID"
  echo "  2. Check status: tail -f download.log"
  exit 1
fi

nohup node download.mjs "$LIMIT" "$MIN_PRIO" "$MAX_PRIO" >> download.log 2>&1 &
NEW_PID=$!

echo "✅ Download started (PID: $NEW_PID)"
echo
echo "Monitor:"
echo "  tail -f $PARSER_DIR/download.log"
echo "  Or status: bash ~/.claude/skills/telegram-parser/status.sh"
