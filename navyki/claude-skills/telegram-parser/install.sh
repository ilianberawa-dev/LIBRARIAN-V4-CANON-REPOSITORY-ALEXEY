#!/bin/bash
# Installer для Claude Desktop Telegram Parser skills
# Копирует 5 скриптов + SKILL.md в ~/.claude/skills/telegram-parser/
#
# Usage:
#   bash install.sh                    # локальная установка из клона репо
#   curl -fsSL https://raw.githubusercontent.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/main/navyki/claude-skills/telegram-parser/install.sh | bash
#
# Env:
#   CLAUDE_SKILLS_DIR   куда ставить (по умолчанию $HOME/.claude/skills)
#   PARSER_DIR          где лежит парсер (по умолчанию $HOME/tg-export)

set -euo pipefail

CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
TARGET="$CLAUDE_SKILLS_DIR/telegram-parser"
REPO_RAW="https://raw.githubusercontent.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/main/navyki/claude-skills/telegram-parser"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" 2>/dev/null && pwd || echo "" )"

echo "📦 Installing telegram-parser skills → $TARGET"
mkdir -p "$TARGET"

FILES=(status.sh sync.sh download.sh logs.sh transcribe.sh SKILL.md)

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/status.sh" ]; then
  echo "   source: local ($SCRIPT_DIR)"
  for f in "${FILES[@]}"; do
    cp "$SCRIPT_DIR/$f" "$TARGET/$f"
  done
else
  echo "   source: GitHub ($REPO_RAW)"
  for f in "${FILES[@]}"; do
    echo "   ↓ $f"
    curl -fsSL "$REPO_RAW/$f" -o "$TARGET/$f"
  done
fi

chmod +x "$TARGET"/*.sh

echo
echo "✅ Installed. Test:"
echo "   bash $TARGET/status.sh"
echo
echo "Ожидается парсер в: ${PARSER_DIR:-\$HOME/tg-export}"
echo "Если парсера ещё нет — см. navyki/claude-bot-parser-control.md 'Шаг 1: Подготовь парсер'"
