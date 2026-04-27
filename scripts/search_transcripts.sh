#!/bin/bash
# Слой 3 поиска: full-text по транскриптам.
# Использование: ./scripts/search_transcripts.sh "фраза для поиска"
# Возвращает msg_id всех транскриптов где встречается фраза.

set -e

if [ $# -eq 0 ]; then
  echo "Использование: $0 \"<фраза>\""
  echo "Пример: $0 \"cloudflare\""
  exit 1
fi

QUERY="$*"
TRANSCRIPTS_DIR="$(dirname "$0")/../alexey-materials/transcripts"

cd "$(dirname "$0")/.."

echo "Ищу '$QUERY' в транскриптах..."
echo ""

grep -irlF "$QUERY" "$TRANSCRIPTS_DIR" 2>/dev/null \
  | grep -oP '/\K\d+(?=_)' \
  | sort -u \
  | while read msg_id; do
      title=$(python3 -c "
import json, sys
data = json.load(open('alexey-materials/metadata/library_index.json'))
for p in data['posts']:
    if p['msg_id'] == int('$msg_id'):
        print(p.get('title', '?')[:80])
        break
")
      echo "  #$msg_id  $title"
    done

echo ""
echo "Готово. Дальше можно прочитать конкретный транскрипт:"
echo "  cat alexey-materials/transcripts/<msg_id>_*.transcript.txt"
