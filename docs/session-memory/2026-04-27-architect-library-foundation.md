---
date: 2026-04-27
role: Архитектор
topic: Заложить основу библиотеки и протоколов для всех будущих чатов
chat_model: claude-opus-4-7
session_status: completed
---

# Что сделано

## Артефакты, созданные в этой сессии
- `CLAUDE.md` (диспетчер: онбординг + 4 роли + 3-слойный поиск + сессионная память + анти-паттерны)
- `alexey-materials/metadata/taxonomy.json` (10 категорий)
- `alexey-materials/metadata/synonyms.json` (русский→канонические теги)
- `alexey-materials/metadata/index_compact.json` (105 КБ из 285 КБ)
- `alexey-materials/metadata/transcript_keys.json` (TF-IDF ключи 44 транскриптов)
- `kanon/memory-pyramid-principle.md` (извлечено из фото #167)
- `troubleshoot/claude-code-vscode-install.md` (из фото #111+#112)
- `dizain/` структура (README + inbox/ + projects/)
- `docs/session-memory/` (эта папка — введён протокол)
- `scripts/extract_transcript_keys.py` + `scripts/build_compact_index.py` + `scripts/search_transcripts.sh`
- `~/.claude/settings.json` (глобальный коридор разрешений с allow/deny/ask)
- `~/.bashrc` алиасы: `sync`, `upload-design`, `watch <msg_id>`

## Удалено (с подтверждением Алексея и/или верификацией)
- 16 декоративных/инструктивных фоток (контент сохранён в .md где нужно)
- `170_video.mp4` (транскрипт сохранён)
- Дубль `guides/skills-a-to-ya.pdf`
- 24 дублирующихся файла транскриптов в `aeza-archive/transcripts/`
- `_progress.log` файлы (служебные)

# Решения и причины (Уровень 1 пирамиды памяти)

1. **3-слойный поиск vs LightRAG** — выбрали 3-слойный (taxonomy → index_compact → transcripts grep) потому что:
   - 154 поста — мало для RAG
   - Работает на любой модели (Opus/Sonnet/Haiku) без серверов
   - При росте до 1000+ файлов мигрируем в LightRAG (он на Aeza уже стоит)

2. **Front-load permissions vs ad-hoc** — выбрали глобальный `~/.claude/settings.json` с allow/deny/ask потому что:
   - Пользователь не-программист, жмёт OK на всё → опасно
   - Перенесли защиту с человека на систему
   - rm/sudo/git reset --hard и т.д. — **запрещены полностью**

3. **Отдельный CLAUDE.md vs расширение _INDEX.md** — сделали `CLAUDE.md` как диспетчер для AI, `_INDEX.md` оставили как каталог для людей. Не путать.

4. **dizain/ создаём пустой** — у пользователя есть первый дизайн-проект, загрузит через `upload-design` алиас.

5. **Не переименовывать файлы транскриптов** (`170_video.mp4.transcript.txt`) — сломаем связку с `msg_id`. Вместо этого индекс делает их находимыми через `library_index.json`.

6. **Сессионная память — единая папка `docs/session-memory/`** — каждый чат пишет туда file с фронт-маттером. Следующий чат читает 3-5 последних. Решает проблему "каждый чат на свою полку".

# Открытые вопросы (для следующих сессий)

- 64 поста в категории `PRINCIPLES_BIZ` (без явных тегов) — нужно перетегировать вручную при следующем заходе
- Дубли тегов `N8N MCP` vs `n8n` — synonyms.json склеивает, но в индексе остались как есть
- `school-materials/` — 31 файл, возможно много мусора. Не разобрано — оставлено как "архив рабочей переписки"
- `OLD-PARSER-STRUCTURE/` — 420 КБ, вероятно архив. Не тронуто
- Стартовый протокол первого сообщения (4 вопроса в CLAUDE.md) — нужна обкатка с Алексеем, может избыточен
- Алексей вернётся через день практики — обновим по результатам

# Изменённые файлы
- `_INDEX.md` (добавлены подбиблиотеки + dizain + session-memory)
- `troubleshoot/README.md` (статус с "пусто" → 3 гайда)
- `.gitignore` (добавлены *.bak, IDE, node_modules, __pycache__, _progress.log)

# Следующий шаг

Когда Алексей вернётся через день практики — обновить:
1. По результатам реального использования `CLAUDE.md` — что лишнее, что не работает
2. Перетегировать `PRINCIPLES_BIZ` → раскидать в правильные категории
3. Добавить `dizain/projects/` первый дизайн-проект (после загрузки через `upload-design`)
4. Если "просим алиас" продолжается — добавить `/save-session` слэш-команду для удобной записи памяти

# Источники истины

- Канон Алексея: `kanon/alexey-11-principles.md`
- Пирамида памяти: `kanon/memory-pyramid-principle.md`
- Главный диспетчер: `CLAUDE.md`
- Карта папок: `_INDEX.md`
