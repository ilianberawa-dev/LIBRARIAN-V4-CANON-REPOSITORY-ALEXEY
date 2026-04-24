#!/bin/bash
# Синхронизирует Telegram канал (detect new posts)
# Source: navyki/claude-bot-parser-control.md

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"

echo "🔄 Syncing Telegram channel..."
cd "$PARSER_DIR" || { echo "❌ PARSER_DIR not found: $PARSER_DIR"; exit 1; }

if [ -f library_index.json ]; then
  cp library_index.json "library_index.json.bak.$(date +%s)"
fi

node sync_channel.mjs 2>&1 | tail -30

if [ -f library_index.json ]; then
  TOTAL=$(jq '.messages | length' library_index.json)
  echo
  echo "✅ Sync complete. Total posts: $TOTAL"

  if [ -f announced.txt ]; then
    NEW=$(tail -5 announced.txt 2>/dev/null)
    if [ -n "$NEW" ]; then
      echo
      echo "🆕 New posts:"
      echo "$NEW"
    fi
  fi
else
  echo "❌ Sync failed. Check logs."
  exit 1
fi
