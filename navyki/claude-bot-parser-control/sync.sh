#!/bin/bash
# Синхронизирует Telegram канал (detect new posts)
# Источник: navyki/claude-bot-parser-control.md

PARSER_DIR="${PARSER_DIR:-$HOME/tg-export}"

echo "🔄 Syncing Telegram channel..."
cd "$PARSER_DIR"

# Backup library_index.json
if [ -f library_index.json ]; then
  cp library_index.json "library_index.json.bak.$(date +%s)"
fi

# Run sync
node sync_channel.mjs 2>&1 | tail -30

# Show summary
if [ -f library_index.json ]; then
  TOTAL=$(jq '.messages | length' library_index.json)
  echo
  echo "✅ Sync complete. Total posts: $TOTAL"

  # Show new posts if announced.txt changed
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
fi
