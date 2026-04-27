#!/bin/bash
#
# SessionStart hook — runs before Claude's first response in a new session.
# Output is automatically injected as system context.
#
# DESIGN: only DYNAMIC data (inbox listing, latest memory files) + a single
# pointer to CLAUDE.md / onboarding skill. All static rules live in CLAUDE.md
# to avoid duplication and "instruction inflation".

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 0

echo "═══════ SESSION START — DYNAMIC CONTEXT ═══════"

# === INBOX (dynamic) ===
if [ -d "inbox" ]; then
    INBOX_FILES=$(find inbox/ -maxdepth 1 -type f \
        ! -name '.gitkeep' ! -name 'README.md' \
        -printf '%f\n' 2>/dev/null)
    INBOX_COUNT=$(printf '%s' "$INBOX_FILES" | grep -c . || true)
    if [ "$INBOX_COUNT" -gt 0 ]; then
        echo ""
        echo "📥 inbox/ — $INBOX_COUNT файл(ов):"
        echo "$INBOX_FILES" | sed 's/^/   • /'
    fi
fi

# === LAST 3 SESSION-MEMORY FILES (dynamic) ===
if [ -d "docs/session-memory" ]; then
    MEMORY_FILES=$(ls -1t docs/session-memory/ 2>/dev/null | grep '\.md$' | head -3)
    if [ -n "$MEMORY_FILES" ]; then
        echo ""
        echo "📚 docs/session-memory/ — последние 3:"
        echo "$MEMORY_FILES" | sed 's/^/   • /'
    fi
fi

# === SINGLE POINTER (no rules duplication) ===
echo ""
echo "▶ Перед первым ответом: прочитай CLAUDE.md и .claude/skills/onboarding.md."
echo "▶ Лимит ответа: ≤ 10 000 знаков. Длиннее — разбивай на части."
echo "▶ Первый заход в репо? Прочитай kanon/alexey-11-principles.md (12 принципов)."
echo "═══════════════════════════════════════════════"
