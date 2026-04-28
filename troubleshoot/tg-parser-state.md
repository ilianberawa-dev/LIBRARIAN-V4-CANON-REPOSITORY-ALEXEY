# TG-парсер: архитектура и состояние

**Дата:** 2026-04-28  
**Сервер:** 193.233.128.21  
**Репо:** ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY  

---

## Цепочка данных

```
Telegram-канал Алексея
    ↓ sync_channel.mjs (cron каждые 6ч)
alexey-materials/metadata/library_index.json  ← каталог постов
    ↓ download.mjs
/opt/tg-export/media/  ← ВРЕМЕННО, только на время транскрипции
    ↓ transcribe_all_clean.mjs (cron daily 03:00)
/opt/tg-export/transcripts/  → alexey-materials/transcripts/
    ↓ github-sync.sh (cron каждый час)
GitHub репо  ← ФИНАЛЬНОЕ место хранения
```

**Правило:** видео (`mp4`, `wav`, `m4a`) в GitHub **никогда**. Только транскрипты + метадата + PDF.

---

## Номенклатура файлов в репо

| Тип | Путь | Формат имени |
|---|---|---|
| Транскрипт JSON | `alexey-materials/transcripts/` | `{msg_id}_{filename}.transcript.json` |
| Транскрипт TXT | `alexey-materials/transcripts/` | `{msg_id}_{filename}.transcript.txt` |
| Полный индекс | `alexey-materials/metadata/library_index.json` | — |
| Компактный индекс | `alexey-materials/metadata/index_compact.json` | — |
| Ключи транскриптов | `alexey-materials/metadata/transcript_keys.json` | — |
| PDF / важные доки | `alexey-materials/media/` | `{msg_id}_{filename}.pdf` |

---

## Обязательные поля транскрипта (`.transcript.json`)

```json
{
  "msg_id": 170,
  "telegram_url": "https://t.me/{channel_username}/170",
  "source_filename": "video.mp4",
  "language": "ru",
  "duration": 59.11,
  "text": "полный текст одной строкой",
  "words": [{"text": "...", "start": 0.0, "end": 0.5}]
}
```

**Правило:** `telegram_url` **обязательна и не пустая**. Если не удалось получить — STOP, не сохранять, логировать ошибку. Формат: `https://t.me/{TELEGRAM_CHANNEL}/{msg_id}`.

---

## После каждого нового транскрипта — 5 шагов

1. Положить `.transcript.json` + `.transcript.txt` → `alexey-materials/transcripts/`
2. Обновить `library_index.json` (добавить запись с `telegram_url`)
3. Регенерировать `index_compact.json` из `library_index.json`
4. Обновить `transcript_keys.json`
5. Обновить строку `alexey-materials/` в `_INDEX.md` — актуальные числа:
   - **транскриптов** = `ls *.transcript.json | wc -l` (не `ls | wc -l` — это даст ×2)
   - **media** = `du -sh alexey-materials/media/`
   - **дату «Последнее обновление»** в шапке `_INDEX.md`

Затем `github-sync.sh` пушит всё в репо.

**Проверка после push:** `git log origin/main --oneline -1` должен показать новый sync-коммит. Если нет — `github-sync.sh` упал, смотри логи cron.

---

## Динамичное дерево для Архитекторов

**Архитектор при поиске** читает `alexey-materials/metadata/index_compact.json` (Слой 1 поиска). Этот файл — живой индекс, обновляется парсером после каждого нового поста/транскрипта.

**`_INDEX.md`** — статичное дерево всего репо. Парсер обновляет строку `alexey-materials/` с актуальными счётчиками.

---

## Известные проблемы (диагностика 2026-04-28)

### 🔴 Критичные (блокируют транскрипцию)

| # | Проблема | Причина | Решение |
|---|---|---|---|
| 1 | 11 видео >2GB не скачиваются | Node.js `Buffer.alloc` limit = 2^31-1 байт | Stream-download (chunks) + `ffmpeg -f segment` для разбивки |
| 2 | Видео удалены с диска (0 mp4 на сервере) | Уже удалены вручную | Скачивать заново по списку из `library_index.json` |
| 3 | Старый IP БД в `transcribe_all_clean.mjs` | Hardcoded `172.18.0.17` | Применить Dynamic DB IP discovery как в realty-scraper |

### 🟡 Важные (влияют на качество данных)

| # | Проблема | Причина | Решение |
|---|---|---|---|
| 4 | 44 транскрипта без `telegram_url` | Поле не добавлялось при создании | Ретро-фикс: пробежать все `.transcript.json`, добавить `msg_id` + `telegram_url` |
| 5 | 20+ файлов с именем `video.mp4` | Telegram не даёт уникальные имена | В `sync_channel.mjs` префиксовать `msg_id` ДО записи в `library_index.json` |
| 6 | 7 файлов с `filename=null` | GramJS не определил расширение | Определять MIME из `mime_type` поля Telegram media object |
| 7 | Хардкод в `notify_v2.sh` строки 18-26 | Написан вручную в апреле 2026 | Переписать `notify_real.sh` с runtime подсчётом, удалить v1/v2/v3/v4 |

### 🟢 Инфраструктурные

| # | Проблема | Решение |
|---|---|---|
| 8 | 4 версии `notify_*.sh` | Оставить только канонический (тот что в cron), удалить остальные |
| 9 | Диск 60GB — после скачивания 51GB видео останется 9GB | Pipeline: download → transcribe → delete сразу, не накапливать |

---

## Статус на 2026-04-28

| Компонент | Статус |
|---|---|
| `sync_channel.mjs` | ✅ Работает (cron 6ч) |
| `download.mjs` для файлов <2GB | ✅ Работает |
| `download.mjs` для файлов >2GB | ❌ Падает (Buffer limit) |
| `transcribe_all_clean.mjs` | ⚠️ Работает, но старый IP БД |
| `ingest_transcripts.py` → Supabase | ✅ 43 записи |
| `github-sync.sh` | ✅ Cron каждый час |
| `notify_v2.sh` — отчёт в Telegram | ❌ Захардкожен |
| `telegram_url` в транскриптах | ❌ Отсутствует (44 ретро-фикс нужен) |
| Транскриптов в репо | 44 из ~88 ожидаемых |
| Медиа-файлов скачано | 53 из 117 (0.13% по объёму) |
