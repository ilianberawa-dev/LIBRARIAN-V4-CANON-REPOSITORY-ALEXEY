# Parser → GitHub Sync Algorithm

**Назначение:** Безопасное добавление новых материалов из Aeza парсера в GitHub базу Алексея  
**Принцип:** ТОЛЬКО ДОБАВЛЯТЬ, НИКОГДА НЕ УДАЛЯТЬ  
**Создано:** 2026-04-24  
**Роль:** Reference для агентов-исполнителей

---

## 🎯 Цель

Парсер на Aeza находит новые посты → **безопасно добавляет** в GitHub `alexey-materials/` → уведомляет о новых материалах

**КРИТИЧНО:** НЕ СЛОМАТЬ существующую базу (151 пост, 22 файла, proven structure)

---

## 📂 Структура базы GitHub (alexey-materials/)

```
alexey-materials/
├── guides/              ← PDF гайды (skills-a-to-ya.pdf)
│   └── {topic}_{title}.pdf
│
├── media/               ← Медиа файлы + манифест
│   ├── {msg_id}_{sanitized_title}.{ext}
│   ├── _manifest.json   ← КРИТИЧНЫЙ: список всех файлов
│   └── _progress.log    ← История добавлений
│
├── metadata/            ← JSON индексы
│   ├── library_index.json     ← МАСТЕР-ИНДЕКС (151 пост)
│   ├── p4_catalog.json
│   ├── p4_priority.json
│   └── result.json
│
├── transcripts/         ← Транскрипты (пары .json + .txt)
│   ├── {msg_id}_{sanitized_filename}.transcript.json
│   └── {msg_id}_{sanitized_filename}.transcript.txt
│
├── INDEX.md             ← Человеко-читаемый индекс
├── README.md            ← Описание базы
└── Алексей Колесов - Private.md  ← Текстовый экспорт канала
```

---

## 🔍 Этап 1: Определение НОВЫХ материалов

### Шаг 1.1: Прочитать текущее состояние базы GitHub

```bash
# Клонируй или pull базу
git clone https://github.com/{username}/telegram-archive.git ~/telegram-archive
# ИЛИ
cd ~/telegram-archive && git pull

# Прочитай мастер-индекс
cat ~/telegram-archive/alexey-materials/metadata/library_index.json
```

**Извлечь:**
- `total_posts` (сейчас: 151)
- Все `msg_id` из массива `posts[]`
- Максимальный `msg_id` (сейчас: 178)

### Шаг 1.2: Прочитать свежие данные с Aeza парсера

```bash
# Скачай свежий индекс с парсера
scp root@193.233.128.21:/opt/tg-export/library_index.json /tmp/parser_library_index.json

# Прочитай
cat /tmp/parser_library_index.json
```

**Извлечь:**
- `total_posts` (сейчас: 152)
- Все `msg_id` из массива `messages[]` (в парсере это `messages`, в базе `posts`)

### Шаг 1.3: Вычислить diff

```bash
# Псевдокод (реализуй в скрипте)
GITHUB_IDS = [178, 177, 176, ... 30]  # из базы GitHub
PARSER_IDS = [179, 178, 177, ... 30]  # с парсера

NEW_IDS = PARSER_IDS - GITHUB_IDS
# Результат: NEW_IDS = [179]
```

**Если NEW_IDS пустой → СТОП, ничего не делать**

**Если NEW_IDS НЕ пустой → продолжить Этап 2**

---

## 📥 Этап 2: Скачивание НОВЫХ материалов с Aeza

Для каждого `msg_id` в NEW_IDS:

### Шаг 2.1: Получить метаданные поста

```bash
# Из /tmp/parser_library_index.json
POST = find_post_by_id(msg_id)

# Извлечь:
{
  "msg_id": 179,
  "date": "2026-04-21T09:17:51.000Z",
  "title": "Готовые Skills - это кубики для твоих собственных скиллов",
  "type": "text",  # или "media"
  "filename": "177_telegram.zip",  # если media
  "topics": ["OpenClaw", "n8n", "Supabase"],
  "category": "HIGH_CODE",
  "text_full": "..."
}
```

### Шаг 2.2: Скачать медиа файлы (если есть)

**Только если `type == "media"` И `filename != ""`**

```bash
# Sanitize filename (убрать спецсимволы)
SANITIZED = sanitize_filename(POST.filename)
# Пример: "177_telegram.zip" → "177_telegram.zip" (OK)
# "179_Skills: кубики?.mp4" → "179_Skills_кубики.mp4"

# Проверь что файл НЕ существует в базе
if [ -f "~/telegram-archive/alexey-materials/media/${SANITIZED}" ]; then
  echo "SKIP: ${SANITIZED} already exists"
  continue
fi

# Скачай с Aeza
scp root@193.233.128.21:/opt/tg-export/media/${POST.filename} \
    ~/telegram-archive/alexey-materials/media/${SANITIZED}

# Verify size
SIZE=$(stat -f%z ~/telegram-archive/alexey-materials/media/${SANITIZED})
if [ "$SIZE" -eq 0 ]; then
  echo "ERROR: Downloaded file is empty"
  rm ~/telegram-archive/alexey-materials/media/${SANITIZED}
  exit 1
fi
```

### Шаг 2.3: Скачать транскрипты (если есть)

**Только если есть `.transcript.json` на Aeza**

```bash
# Проверь существование транскрипта
TRANSCRIPT_JSON="${POST.filename}.transcript.json"
ssh root@193.233.128.21 "[ -f /opt/tg-export/transcripts/${TRANSCRIPT_JSON} ]"

if [ $? -eq 0 ]; then
  # Sanitize
  SANITIZED_TRANS=$(sanitize_filename ${TRANSCRIPT_JSON})
  
  # Проверь что НЕ существует
  if [ ! -f "~/telegram-archive/alexey-materials/transcripts/${SANITIZED_TRANS}" ]; then
    # Скачай .json
    scp root@193.233.128.21:/opt/tg-export/transcripts/${TRANSCRIPT_JSON} \
        ~/telegram-archive/alexey-materials/transcripts/${SANITIZED_TRANS}
    
    # Скачай .txt
    TRANSCRIPT_TXT="${POST.filename}.transcript.txt"
    SANITIZED_TXT=$(sanitize_filename ${TRANSCRIPT_TXT})
    scp root@193.233.128.21:/opt/tg-export/transcripts/${TRANSCRIPT_TXT} \
        ~/telegram-archive/alexey-materials/transcripts/${SANITIZED_TXT}
  fi
fi
```

### Шаг 2.4: Обновить _manifest.json

```bash
# Прочитай текущий манифест
MANIFEST=~/telegram-archive/alexey-materials/media/_manifest.json

# Добавь новый файл (если скачали медиа)
if [ -n "${SANITIZED}" ]; then
  jq --arg file "${SANITIZED}" \
     --arg msgid "${POST.msg_id}" \
     --arg date "${POST.date}" \
     '.files += [{
       "filename": $file,
       "msg_id": $msgid,
       "date": $date,
       "added": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
     }]' ${MANIFEST} > ${MANIFEST}.tmp
  
  mv ${MANIFEST}.tmp ${MANIFEST}
fi
```

### Шаг 2.5: Обновить _progress.log

```bash
LOG=~/telegram-archive/alexey-materials/media/_progress.log

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | msg_id:${POST.msg_id} | ${SANITIZED} | ${SIZE} bytes" >> ${LOG}
```

---

## 📝 Этап 3: Обновление metadata/library_index.json

**КРИТИЧНО:** MERGE, НЕ REPLACE!

### Шаг 3.1: Backup текущего индекса

```bash
cp ~/telegram-archive/alexey-materials/metadata/library_index.json \
   ~/telegram-archive/alexey-materials/metadata/library_index.json.backup.$(date +%s)
```

### Шаг 3.2: Merge новых постов

```bash
# Прочитай оба индекса
GITHUB_INDEX=~/telegram-archive/alexey-materials/metadata/library_index.json
PARSER_INDEX=/tmp/parser_library_index.json

# Псевдокод merge (реализуй в jq или python)
MERGED = {
  "channel": "Алексей Колесов | Private",
  "channel_id": 2653037830,
  "generated": NOW(),
  "total_posts": GITHUB_INDEX.total_posts + NEW_IDS.length,
  "active_posts": GITHUB_INDEX.active_posts + count_active(NEW_IDS),
  "posts": GITHUB_INDEX.posts + NEW_POSTS_FROM_PARSER
}

# Важно: NEW_POSTS_FROM_PARSER = посты с msg_id из NEW_IDS
# Адаптируй формат парсера к формату базы:
# - "messages" → "posts"
# - добавь "has_full_text": true
# - sanitize filenames

# Сохрани
echo ${MERGED} | jq '.' > ${GITHUB_INDEX}
```

**jq пример:**

```bash
jq --slurpfile parser /tmp/parser_library_index.json \
   --argjson new_ids '[179]' '
   .posts += ($parser[0].messages | map(select(.msg_id as $id | $new_ids | index($id)))) |
   .total_posts = (.posts | length) |
   .generated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
' ${GITHUB_INDEX} > ${GITHUB_INDEX}.tmp

mv ${GITHUB_INDEX}.tmp ${GITHUB_INDEX}
```

### Шаг 3.3: Verify integrity

```bash
# Проверь что JSON валидный
jq empty ${GITHUB_INDEX} || {
  echo "ERROR: Invalid JSON in library_index.json"
  mv ~/telegram-archive/alexey-materials/metadata/library_index.json.backup.* ${GITHUB_INDEX}
  exit 1
}

# Проверь что total_posts совпадает с длиной массива
TOTAL=$(jq '.total_posts' ${GITHUB_INDEX})
ACTUAL=$(jq '.posts | length' ${GITHUB_INDEX})

if [ "$TOTAL" -ne "$ACTUAL" ]; then
  echo "ERROR: total_posts ($TOTAL) != actual count ($ACTUAL)"
  exit 1
fi
```

---

## 🔄 Этап 4: Git commit & push

### Шаг 4.1: Git add ТОЛЬКО новые файлы

```bash
cd ~/telegram-archive

# Add новые медиа
git add alexey-materials/media/${SANITIZED}*

# Add новые транскрипты (если есть)
git add alexey-materials/transcripts/${msg_id}_*.transcript.*

# Add обновлённые metadata
git add alexey-materials/metadata/library_index.json
git add alexey-materials/media/_manifest.json
git add alexey-materials/media/_progress.log
```

### Шаг 4.2: Проверка перед commit

```bash
# git status должен показать ТОЛЬКО новые/изменённые файлы
git status --short

# Ожидаемый вывод:
# A  alexey-materials/media/179_Skills_кубики.mp4
# M  alexey-materials/metadata/library_index.json
# M  alexey-materials/media/_manifest.json
# M  alexey-materials/media/_progress.log

# Если видишь:
# D  alexey-materials/media/178_*.* (удалённые файлы)
# → СТОП! ЧТО-ТО СЛОМАЛОСЬ!

# Если видишь изменения в НЕ-metadata файлах:
# M  alexey-materials/README.md
# → СТОП! НЕ ТРОГАЙ README без явного указания
```

**Правило:** `git status` должен показать **ТОЛЬКО**:
- `A` (added) новые файлы
- `M` (modified) metadata/library_index.json, _manifest.json, _progress.log
- **НИКАКИХ** `D` (deleted)

### Шаг 4.3: Commit с информативным сообщением

```bash
git commit -m "$(cat <<EOF
sync: add ${NEW_IDS.length} new post(s) from Telegram parser

New posts:
- msg_id ${msg_id_1}: ${title_1} (${type_1})
- msg_id ${msg_id_2}: ${title_2} (${type_2})

Files added:
- Media: ${media_count} files (${media_total_mb} MB)
- Transcripts: ${transcript_count} files

Updated metadata:
- library_index.json: ${old_total} → ${new_total} posts
- _manifest.json: +${media_count} entries

Source: Aeza /opt/tg-export at $(date -u +%Y-%m-%dT%H:%M:%SZ)

Co-Authored-By: Telegram Parser <parser@aeza.server>
EOF
)"
```

### Шаг 4.4: Push к GitHub

```bash
git push origin main

# Verify push
if [ $? -eq 0 ]; then
  echo "✅ Successfully pushed to GitHub"
else
  echo "❌ Push failed, check network/credentials"
  exit 1
fi
```

---

## 📢 Этап 5: Уведомление о новых материалах

### Шаг 5.1: Формирование уведомления

```bash
# Telegram notification через notify.sh
NOTIFICATION=$(cat <<EOF
🆕 New Materials Added to GitHub

📊 Summary:
- Posts: +${NEW_IDS.length} (total: ${new_total})
- Media: +${media_count} files (${media_total_mb} MB)
- Transcripts: +${transcript_count} files

📝 New Posts:
$(for id in ${NEW_IDS[@]}; do
  POST=$(jq ".posts[] | select(.msg_id == $id)" ${GITHUB_INDEX})
  TITLE=$(echo $POST | jq -r '.title')
  TOPICS=$(echo $POST | jq -r '.topics | join(", ")')
  echo "• #${id}: ${TITLE}"
  echo "  Topics: ${TOPICS}"
done)

🔗 GitHub: https://github.com/{username}/telegram-archive/commit/$(git rev-parse HEAD)

Last sync: $(date -u +%Y-%m-%d %H:%M UTC)
EOF
)
```

### Шаг 5.2: Отправка в Telegram

```bash
# Через Telegram Bot API (BOT_TOKEN из .env)
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": \"${CHAT_ID}\",
    \"text\": \"${NOTIFICATION}\",
    \"parse_mode\": \"Markdown\"
  }"
```

### Шаг 5.3: Логирование в парсер

```bash
# На Aeza сервере
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | GitHub sync: +${NEW_IDS.length} posts | commit $(git rev-parse HEAD)" \
  >> /opt/tg-export/github-sync.log
```

---

## 🛡️ Safety Checks (обязательные проверки)

### Before Commit:

```bash
# 1. Проверка что НЕТ удалённых файлов
DELETED=$(git status --short | grep '^D' | wc -l)
if [ "$DELETED" -gt 0 ]; then
  echo "❌ STOP: Deleted files detected!"
  git status
  exit 1
fi

# 2. Проверка что library_index.json валидный
jq empty ${GITHUB_INDEX} || exit 1

# 3. Проверка что total_posts увеличился (не уменьшился)
OLD_TOTAL=$(jq '.total_posts' ${GITHUB_INDEX}.backup.*)
NEW_TOTAL=$(jq '.total_posts' ${GITHUB_INDEX})
if [ "$NEW_TOTAL" -lt "$OLD_TOTAL" ]; then
  echo "❌ STOP: total_posts decreased ($OLD_TOTAL → $NEW_TOTAL)"
  exit 1
fi

# 4. Проверка что все новые медиа файлы существуют
for id in ${NEW_IDS[@]}; do
  POST=$(jq ".posts[] | select(.msg_id == $id)" ${GITHUB_INDEX})
  FILENAME=$(echo $POST | jq -r '.filename')
  if [ -n "$FILENAME" ] && [ ! -f "alexey-materials/media/$FILENAME" ]; then
    echo "❌ STOP: Media file missing: $FILENAME"
    exit 1
  fi
done
```

### After Push:

```bash
# 5. Проверка что GitHub видит новый commit
LATEST_COMMIT=$(git ls-remote origin main | awk '{print $1}')
LOCAL_COMMIT=$(git rev-parse HEAD)

if [ "$LATEST_COMMIT" != "$LOCAL_COMMIT" ]; then
  echo "⚠️  WARNING: GitHub не синхронизирован с локалкой"
  echo "Local:  $LOCAL_COMMIT"
  echo "Remote: $LATEST_COMMIT"
fi
```

---

## 📋 Sanitize Filename Function

```bash
sanitize_filename() {
  local filename="$1"
  
  # Удалить/заменить опасные символы
  filename="${filename//[:<>\"\\|?*]/}"  # Windows запрещённые
  filename="${filename//[\/]/}"          # Unix path separator
  
  # Заменить пробелы на underscores
  filename="${filename// /_}"
  
  # Ограничить длину (max 255 chars)
  if [ ${#filename} -gt 255 ]; then
    EXT="${filename##*.}"
    BASE="${filename%.*}"
    BASE="${BASE:0:250}"
    filename="${BASE}.${EXT}"
  fi
  
  echo "$filename"
}
```

---

## 🔄 Автоматизация (cron job)

### Вариант 1: Immediate (после каждого нового поста)

```bash
# В heartbeat.sh на Aeza добавить:
if [ -f "/opt/tg-export/.github-sync-enabled" ]; then
  NEW_COUNT=$(check_new_posts_count)  # функция сравнения с последним sync
  
  if [ "$NEW_COUNT" -gt 0 ]; then
    bash /opt/tg-export/github-sync.sh >> /opt/tg-export/github-sync.log 2>&1
  fi
fi
```

### Вариант 2: Hourly (каждые 6 часов)

```bash
# crontab
0 */6 * * * bash /opt/tg-export/github-sync.sh >> /opt/tg-export/github-sync.log 2>&1
```

---

## 📊 Monitoring

### Dashboard в Telegram уведомлении

Каждые 6 часов (вместе с sync):

```
📈 Parser → GitHub Sync Status

Last sync: 2026-04-24 14:00 UTC
New posts since last sync: 3
Total posts in GitHub: 154

✅ All systems operational
- Parser uptime: 8 days
- GitHub repo size: 142 MB
- Last commit: 2 hours ago

Next sync: in 4 hours
```

---

## 🚨 Error Handling

### Если sync failed:

```bash
# НЕ паниковать, НЕ делать git reset --hard
# Просто откатить к backup:

cp ~/telegram-archive/alexey-materials/metadata/library_index.json.backup.* \
   ~/telegram-archive/alexey-materials/metadata/library_index.json

git checkout -- alexey-materials/

# Отправить alert в Telegram:
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=⚠️ GitHub sync FAILED. Rolled back to backup. Check /opt/tg-export/github-sync.log"

# Логировать ошибку:
echo "$(date -u) | SYNC FAILED | Error: $ERROR_MESSAGE" >> /opt/tg-export/github-sync-errors.log
```

---

## ✅ Success Criteria

После каждого sync проверяй:

1. ✅ `git status` чистый (no uncommitted changes)
2. ✅ `library_index.json` валидный (`jq empty`)
3. ✅ `total_posts` увеличился на `NEW_IDS.length`
4. ✅ Все новые медиа файлы существуют в `media/`
5. ✅ Все новые транскрипты существуют в `transcripts/`
6. ✅ `_manifest.json` обновлён
7. ✅ GitHub push успешен
8. ✅ Telegram уведомление отправлено

---

## 📖 Reference для исполнителей

**Вопросы задавать старому технарю (librarian-v4):**
- "Как sanitize filename с кириллицей?"
- "library_index.json показывает total_posts 0 после merge — что сломалось?"
- "Git push возвращает 403 Forbidden — проблема в токене?"

**Я дам:**
- Proven solutions из этого алгоритма
- Debugging команды
- Rollback инструкции

**Я НЕ БУДУ:**
- Запускать sync сам
- Чинить Git конфликты
- Создавать GitHub repo

---

**Версия:** 1.0  
**Создатель:** librarian-v4 (старый технарь)  
**Tested:** НЕТ (это reference, нужен исполнитель для теста)  
**Принцип #0:** Simplicity-First — перед merge проверь можно ли просто append в конец массива
