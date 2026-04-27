#!/bin/bash
#
# SessionStart hook — runs before Claude's first response in a new session.
# Output is automatically injected as system context.
#
# This is the "deterministic enforcement layer" for the onboarding ritual.
# Whatever this script prints, Claude WILL see before responding.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 0

echo "═══════════════════════════════════════════════════════════"
echo "  CLAUDE LIBRARY — SESSION START RITUAL (REQUIRED)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# === STEP 0: INBOX CHECK ===
INBOX_COUNT=0
INBOX_FILES=""
if [ -d "inbox" ]; then
    while IFS= read -r f; do
        if [ -n "$f" ]; then
            INBOX_FILES="$INBOX_FILES   • $f"$'\n'
            INBOX_COUNT=$((INBOX_COUNT + 1))
        fi
    done < <(find inbox/ -maxdepth 1 -type f \
        ! -name '.gitkeep' ! -name 'README.md' \
        -printf '%f\n' 2>/dev/null)
fi

if [ "$INBOX_COUNT" -gt 0 ]; then
    echo "📥 INBOX: $INBOX_COUNT файл(ов) ждут разбора:"
    printf '%s' "$INBOX_FILES"
    echo ""
    echo "   В первом сообщении упомяни: «📥 в inbox $INBOX_COUNT файлов, разобрать сейчас или после задачи?»"
    echo ""
fi

# === STEP 1: RECENT SESSION MEMORY ===
echo "📚 ПАМЯТЬ ПРЕДЫДУЩИХ СЕССИЙ (последние 3):"
if [ -d "docs/session-memory" ]; then
    ls -1t docs/session-memory/ 2>/dev/null | grep '\.md$' | head -3 | sed 's/^/   • /'
    echo ""
    echo "   ОБЯЗАТЕЛЬНО прочитай эти файлы перед ответом."
else
    echo "   (папка пуста)"
fi
echo ""

# === STEP 2: REMIND OF ONBOARDING QUESTIONS ===
echo "❓ 4 ВОПРОСА ОНБОРДИНГА (задай в одном сообщении ДО любого действия):"
echo "   1. Роль сегодня? (А=Архитектор, Б=Установщик, В=Не-код, Г=Дизайн)"
echo "   2. Создать алиас sync? (он уже создан — отвечай 'уже есть')"
echo "   3. Есть что-то загрузить в inbox/?"
echo "   4. Подтверждение коридора: rm/sudo/push --force запрещены, идём?"
echo ""
echo "   ИСКЛЮЧЕНИЕ: если задача очевидно узкая (одна команда) — выполняй молча."
echo ""

# === STEP 3: PERMISSION CORRIDOR REMINDER ===
echo "🚫 КОРИДОР РАЗРЕШЕНИЙ (зашит в ~/.claude/settings.json):"
echo "   • ЗАПРЕЩЕНО: rm*, sudo*, chmod*, chown*, git push --force, git reset --hard"
echo "   • СПРАШИВАЮТ: git push, npm publish, docker build, mcp create_pr"
echo ""

# === STEP 4: TOP 5 RULES ===
echo "✅ 5 ГЛАВНЫХ ПРАВИЛ (из CLAUDE.md):"
echo "   1. Проверь inbox + прочитай session-memory + задай 4 вопроса"
echo "   2. Архитектура/дизайн → 3-слойный поиск в библиотеке (НЕ из общих знаний)"
echo "   3. В конце сессии — запиши docs/session-memory/<date>-<role>-<topic>.md"
echo "   4. \"разбери inbox\" → спроси \"один проект или несколько?\", группируй по проекту"
echo "   5. Сложное решение → Принцип #0 Алексея (как обычные люди делают это просто?)"
echo ""

echo "📂 СКИЛЛЫ (детали — читай по требованию):"
echo "   • .claude/skills/onboarding.md       — детали 4 вопросов и ролей"
echo "   • .claude/skills/inbox-triage.md     — протокол разбора inbox"
echo "   • .claude/skills/library-search.md   — 3-слойный поиск"
echo "   • .claude/skills/session-memory.md   — правила записи памяти"
echo ""
echo "═══════════════════════════════════════════════════════════"
