#!/bin/bash
# Telegram Parser Install Script
# One-command deployment to /opt/tg-export

set -eu

TARGET_DIR="${TARGET_DIR:-/opt/tg-export}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Telegram Parser Installation"
echo "  Target: $TARGET_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create target directory
echo "[1/6] Creating directory structure..."
mkdir -p "$TARGET_DIR"/{media,transcripts}
echo "  ✓ $TARGET_DIR/media"
echo "  ✓ $TARGET_DIR/transcripts"

# Copy scripts
echo ""
echo "[2/6] Copying scripts..."
cp "$SCRIPT_DIR/scripts/"* "$TARGET_DIR/"
chmod +x "$TARGET_DIR/"*.{mjs,sh,py}
echo "  ✓ Copied $(ls "$SCRIPT_DIR/scripts" | wc -l) scripts"

# Copy config templates
echo ""
echo "[3/6] Creating config templates..."
cp "$SCRIPT_DIR/config/.env.example" "$TARGET_DIR/.env"
cp "$SCRIPT_DIR/config/config.json5.example" "$TARGET_DIR/config.json5"
cp "$SCRIPT_DIR/config/package.json" "$TARGET_DIR/"
cp "$SCRIPT_DIR/config/package-lock.json" "$TARGET_DIR/"
echo "  ✓ .env (fill with real tokens)"
echo "  ✓ config.json5 (fill with Telegram API creds)"
echo "  ✓ package.json + package-lock.json"

# Install dependencies
echo ""
echo "[4/6] Installing Node.js dependencies..."
cd "$TARGET_DIR"
if command -v npm >/dev/null 2>&1; then
  npm install
  echo "  ✓ npm install complete"
else
  echo "  ⚠️  npm not found - install Node.js 18+ first"
  echo "     Then run: cd $TARGET_DIR && npm install"
fi

# Copy existing library_index.json if available
echo ""
echo "[5/6] Checking for existing library_index.json..."
if [ -f "$SCRIPT_DIR/../alexey-materials/metadata/library_index.json" ]; then
  cp "$SCRIPT_DIR/../alexey-materials/metadata/library_index.json" "$TARGET_DIR/"
  POSTS=$(node -e "console.log(require('./library_index.json').posts.length)" 2>/dev/null || echo "?")
  echo "  ✓ Copied library_index.json ($POSTS posts)"
  echo "    Parser will sync only NEW posts (incremental)"
else
  echo "  ⚠️  library_index.json not found"
  echo "     Parser will download ALL posts from scratch on first run"
fi

# Print manual steps
echo ""
echo "[6/6] Installation complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MANUAL STEPS REQUIRED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Fill $TARGET_DIR/.env with real API keys:"
echo "   - XAI_API_KEY (https://console.x.ai/team/api-keys)"
echo "   - BOT_TOKEN (@BotFather in Telegram)"
echo "   - CHAT_ID (@userinfobot in Telegram)"
echo ""
echo "2. Fill $TARGET_DIR/config.json5 with Telegram API credentials:"
echo "   - Get from: https://my.telegram.org/apps"
echo "   - apiId, apiHash (from app registration)"
echo "   - sessionString (run sync_channel.mjs once to generate)"
echo ""
echo "3. Setup cron jobs (see cron.example):"
echo "   crontab -e"
echo "   # Add lines from $SCRIPT_DIR/cron.example"
echo ""
echo "4. Optional: Setup GitHub sync"
echo "   - Copy github-sync.sh to /opt/librarian/"
echo "   - Set GITHUB_TOKEN env var in cron"
echo "   - Add to crontab: 0 * * * * cd /opt/librarian && bash github-sync.sh"
echo ""
echo "5. Test first sync:"
echo "   cd $TARGET_DIR"
echo "   node sync_channel.mjs  # Will prompt for phone/code on first run"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installation directory: $TARGET_DIR"
echo "Package source: $SCRIPT_DIR"
echo ""
