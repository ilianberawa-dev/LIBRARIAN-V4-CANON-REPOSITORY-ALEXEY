---
date: 2026-04-27
role: Архитектор
topic: Enforcement-архитектура (slim CLAUDE.md + skills + SessionStart hook) + handoff преемнику
chat_model: claude-opus-4-7
session_status: completed
---

# Что сделано

**PR #10 (merged):** library foundation (CLAUDE.md, taxonomy, session-memory, permissions).
**PR #11 (merged):** 3 триггера разбора inbox + 3-темная структура (`dizain/`, `arhitektura/`, `prochee-idei/`).
**PR #12 (merged):** slim CLAUDE.md (319→106 строк) + 4 skills + SessionStart hook.
**Доп. коммит:** fix matcher hook (с `"startup|resume"` на `""` — Claude Code трактует matcher как exact string, не regex).

Итог: 3-слойная архитектура enforcement (CLAUDE.md + SessionStart hook + skills) — проверена в новом чате, работает.

# Метод (как пришли к решению)

**База:** CLAUDE.md один — рекомендательный (~40-60% соблюдения), у Ильи ушло из контекста за пару ходов.

**Запустили мульти-агентный поиск 3 направлений параллельно:**
1. Claude Code enforcement (hooks, skills, settings)
2. Industry inbox automation (PARA, Zettelkasten, Karpathy LLM Wiki)
3. Multi-agent shared KB patterns (single curator)

**Ключевые находки:**
- ~150-200 инструкций — потолок CLAUDE.md, выше — ВСЁ деградирует
- SessionStart hook = детерминированная инъекция контекста до первого ответа (~85%)
- PreToolUse hook = 100% блокировка вызовов инструментов
- Skills (`.claude/skills/*.md`) — НЕ обязательны (~20% надёжности), Клод сам решает
- Принцип "tool not text": хуки > проза в CLAUDE.md

**Реализовали слой 2 (SessionStart, 85%) + слой 1 (slim CLAUDE.md).**
Слой 3 (PreToolUse, 100%) припаркован как техдолг — пользователь поосторожничал.

# Решения и причины

1. **Slim CLAUDE.md (106 строк) vs полный (319)** — front-load топ-5 правил с "YOU MUST", детали в `.claude/skills/*.md`. Контекст не съедается, правила не теряются.
2. **SessionStart matcher = `""`** — пустая строка ловит все источники (startup/resume/compact/clear). `"startup|resume"` НЕ работает как regex, это exact match.
3. **Hook exit code 0 (non-blocking)** — печатает контекст в stdout, Клод обязан прочитать перед первым ответом. Если упадёт — сессия не блокируется.
4. **Один inbox в корне vs per-theme** — у людей всегда один. Группа по проекту, не по типу файла. Триаж — мандатный вопрос "один проект или несколько?".
5. **3 темы (`dizain`/`arhitektura`/`prochee-idei`)** — выбраны Ильёй как 3 главные сферы текущей работы. Расширим если появится новая.
6. **3 триггера human-in-the-loop:** chat auto-greeting (через hook), PowerShell desktop counter, GitHub Action → TG bot. Все три параллельно — где удобнее, там сработает.

# Попытки и почему не пошли

- ❌ **Просто добавить правил в CLAUDE.md** — упёрлись в ~150-инструкционный потолок, всё начало деградировать
- ❌ **PreToolUse hook (блокирующий 100%)** — Илья решил не рисковать ("если может всё сломать — пока тех долг")
- ❌ **Полный auto-sorter inbox** — отверг идею: проекты разлетятся по темам по типу файла. Заменили на ручной триаж с защитным вопросом
- ❌ **Skill как обязательный механизм** — оказались ~20% надёжности, Клод сам решает применять или нет. Отказались опираться на них для жёсткого enforcement
- ❌ **Matcher `"startup|resume"`** — Claude Code не парсит regex в matcher для SessionStart, нужна `""`

# Техдолги (для следующего чата)

1. **PreToolUse hook (100% слой)** — припаркован. Идея: блокировать `Write` в `inbox/projects/*` пока не задан вопрос "один проект или несколько?". Риск: может сломать обычный workflow. Перед реализацией — мини-тест.
2. **TG bot setup (Триггер 3)** — Илья должен создать бота через `@BotFather`, добавить `TG_BOT_TOKEN` + `TG_CHAT_ID` в GitHub Secrets. Инструкция: `.github/workflows/SETUP-TG-NOTIFY.md`
3. **PowerShell desktop shortcut (Триггер 2)** — Илья запускает `scripts/inbox-tools/setup-inbox-shortcut.md` инструкцию на Windows
4. **64 поста в `PRINCIPLES_BIZ`** — без явных тегов, перетегировать вручную
5. **`school-materials/` (31 файл)** + **`OLD-PARSER-STRUCTURE/` (420 КБ)** — не разобраны
6. **Дубли `N8N MCP` vs `n8n`** в `synonyms.json` склеены, в индексе остались как есть

# Открытые вопросы

- **"Репо для всех областей жизни"** — Илья хочет расширить за пределы AI/Realty. Сравнение с claude.ai Projects: claude.ai Projects = одно место, шарят всю папку, нет hooks/skills, нет git. Наш репо = git + hooks + версионирование, но требует терминал. Гибрид: claude.ai Projects смотрит в этот же репо через файл-загрузку.
- **Переписать `~/.bashrc` `sync` алиас** — Илья отказался от удаления `upload-design`, но `sync` нужно проверить что делает `git pull && ls inbox/`
- **Первый дизайн-проект** в `dizain/projects/` ещё не загружен через inbox

# Руководство преемнику (как поддерживать библиотеку)

**Старт чата (всегда):**
1. SessionStart hook автоматически напечатает контекст — прочитай его внимательно
2. Прочитай 3 последних файла в `docs/session-memory/` — особенно с матчингом ролью
3. Задай 4 вопроса онбординга (если задача не очевидно узкая)
4. Подтверди роль и продолжай

**Изменение архитектуры enforcement:**
- НЕ раздувай `CLAUDE.md` выше ~150 строк — деградирует ВСЁ
- Новые правила сначала в `.claude/skills/<name>.md` со своим front-matter
- Только если правило обязательное → добавить YOU MUST в CLAUDE.md + ссылку на skill
- Изменения в `.claude/hooks/session-start.sh` — тестировать `bash .claude/hooks/session-start.sh` перед коммитом

**Триаж inbox (правила):**
- 0 файлов → стоп
- 1 файл → определи тему, переложи, отчитайся
- 2+ файлов → **ОБЯЗАТЕЛЬНО спроси:** "один проект или несколько? как назвать?"
- ОДИН проект = ОДНА папка. Не разбивай по типу файла
- После: `<папка>/README.md` с описанием, удалить из `inbox/` через Edit

**Запись session-memory (в конце сессии):**
- Файл `docs/session-memory/<YYYY-MM-DD>-<role>-<topic>.md`
- Front-matter обязателен (date, role, topic, chat_model, session_status)
- Записывай **верхушку пирамиды**: решения и причины, не код. 10 фактов > 1000 строк
- При записи большого файла (>5 КБ) — пиши секциями через Write+Edit, иначе stream timeout

**3-слойный поиск (для архитектурных вопросов):**
1. `alexey-materials/metadata/synonyms.json` → каноничные теги
2. `alexey-materials/metadata/taxonomy.json` → 1 категория из 10
3. `index_compact.json` → отфильтровать по category, найти 1-3 поста, прочитать preview
4. Только если в preview не очевидно → `bash scripts/search_transcripts.sh "<запрос>"`

**Безопасность (коридор разрешений в `~/.claude/settings.json`):**
- ЗАПРЕЩЕНО: `rm*`, `sudo*`, `chmod*`, `chown*`, `git push --force`, `git reset --hard`
- СПРАШИВАЕТ: `git push`, `npm publish`, `docker build`, MCP create_pr
- При обходе — НЕ используй `--no-verify`, разбирайся с причиной

# Источники истины (главные файлы)

- `CLAUDE.md` — slim диспетчер (106 строк)
- `.claude/skills/onboarding.md` — 4 вопроса + поведение ролей
- `.claude/skills/inbox-triage.md` — протокол разбора
- `.claude/skills/library-search.md` — 3-слойный поиск
- `.claude/skills/session-memory.md` — формат памяти
- `.claude/hooks/session-start.sh` — детерминированная инъекция контекста
- `.claude/settings.json` — конфиг хуков (репо-локальный)
- `~/.claude/settings.json` — глобальный коридор разрешений
- `kanon/alexey-11-principles.md` — Принцип #0 Простота, Fail Loud
- `kanon/memory-pyramid-principle.md` — что писать в session-memory

# Следующий шаг (для преемника)

1. Подождать первый "тестовый" заход Ильи — он обещал. Не делать структурных изменений до этого
2. Если Илья подтвердит работоспособность — обсудить идею "репо для всех областей жизни" (предложить: либо отдельный репо с тем же шаблоном, либо подпапка `life/` здесь)
3. Если просит триаж inbox — следовать протоколу: спросить "один проект или несколько?"
4. Не реализовывать PreToolUse hook без явной команды — припаркован сознательно
5. После завершения сессии — записать новый файл в `docs/session-memory/`
