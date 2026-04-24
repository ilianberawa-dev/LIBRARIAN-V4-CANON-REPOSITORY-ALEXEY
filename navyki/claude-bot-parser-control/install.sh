#!/bin/bash
# One-shot installer for Claude Desktop — Parser Control skill
# Copies 5 skill scripts to ~/.claude/skills/telegram-parser/
# Source: navyki/claude-bot-parser-control/
#
# Usage (from repo root):
#   bash navyki/claude-bot-parser-control/install.sh
#
# Canon: Simplicity-First — one command instead of 5 cat-heredocs

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/telegram-parser}"

echo "📦 Installing Telegram Parser Control skill"
echo "   Source: $SCRIPT_DIR"
echo "   Target: $SKILL_DIR"
echo

mkdir -p "$SKILL_DIR"

for f in status.sh sync.sh download.sh logs.sh transcribe.sh SKILL.md; do
  src="$SCRIPT_DIR/$f"
  dst="$SKILL_DIR/$f"
  if [ ! -f "$src" ]; then
    echo "❌ Missing: $src"
    exit 1
  fi
  cp "$src" "$dst"
  case "$f" in
    *.sh) chmod +x "$dst" ;;
  esac
  echo "  ✅ $f"
done

echo
echo "✅ Installed 5 skill scripts + SKILL.md"
echo
echo "Next steps:"
echo "  1. Prepare parser at \$HOME/tg-export (clone from Aeza or aeza-archive/)"
echo "  2. Configure \$HOME/tg-export/.env (TG_API_*, XAI_API_KEY, BOT_TOKEN, CHAT_ID)"
echo "  3. Test:"
echo "       bash $SKILL_DIR/status.sh"
echo
echo "Full guide: navyki/claude-bot-parser-control.md"
