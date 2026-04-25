#!/usr/bin/env python3
"""Build 3 artifacts for vibe-coder school:
  1. library_index.json — all 154 Alexey channel posts (structured)
  2. school_manifest.json — curriculum (8 modules, lessons, principles, links)
  3. launcher_prompt.md — starter for new Claude Code chat (tutor role)
"""
import json, re
from pathlib import Path
from collections import defaultdict

BASE = Path("C:/work/realty-portal")
EXPORT = BASE / "docs/alexey-reference/export-2026-04-20"
DUMP = EXPORT / "result.json"
PRIORITY = EXPORT / "p4_priority.json"
SCHOOL = BASE / "docs/school"
SCHOOL.mkdir(parents=True, exist_ok=True)

CHANNEL_ID = 2653037830  # for URL generation
URL_BASE = f"https://t.me/c/{CHANNEL_ID}"

# ---------- 1. LIBRARY INDEX ----------

def extract_title(text: str) -> str:
    """Get the first meaningful line of the post as title."""
    if not text:
        return "[без текста]"
    # Strip emojis from start, take first line
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    for line in lines:
        clean = re.sub(r"^[\U0001F000-\U0001FFFF\u2000-\u26FF\s]+", "", line).strip()
        if len(clean) > 8:
            return clean[:120]
    return lines[0][:120] if lines else "[без текста]"

def extract_topics(text: str) -> list:
    """Identify canonical topics referenced in post."""
    topics = []
    text_l = (text or "").lower()
    topic_map = {
        "LightRAG": ["lightrag", "лайтраг"],
        "Paperclip": ["paperclip"],
        "OpenClaw": ["openclaw", "опенкло"],
        "Леший": ["леший"],
        "Kilo Code": ["kilo code", "kilocode"],
        "Claude Code": ["claude code", "клод код"],
        "Cursor": ["cursor"],
        "Gemini CLI": ["gemini cli", "gemini-cli"],
        "n8n": ["n8n"],
        "Supabase": ["supabase"],
        "Docker": ["docker"],
        "MCP": ["mcp", "model context protocol"],
        "RAG": ["rag", "rag"],
        "Контент-завод": ["контент-завод", "контент завод"],
        "Skills": ["скилл", "skill"],
        "Telegram": ["telegram", "телеграм"],
        "N8N MCP": ["n8n mcp"],
        "Supabase MCP": ["supabase mcp"],
        "DevOps": ["devops"],
        "Multi-agent": ["мультиагент", "multi-agent"],
        "Voice": ["голос", "voice"],
        "Baserow": ["baserow"],
        "Nginx": ["nginx"],
        "Portainer": ["portainer"],
    }
    for topic, keywords in topic_map.items():
        if any(kw in text_l for kw in keywords):
            topics.append(topic)
    return topics

def build_library():
    dump = json.load(open(DUMP, encoding="utf-8"))
    prio_cat = json.load(open(PRIORITY, encoding="utf-8"))
    prio_by_id = {p["msg_id"]: p for p in prio_cat["items"]}

    msgs = dump["messages"]
    entries = []
    for m in msgs:
        text = m.get("text") or ""
        mid = m["id"]
        prio_item = prio_by_id.get(mid, {})

        # Determine type
        msg_type = "text"
        if mid in prio_by_id:
            ext = prio_item.get("ext", "")
            if ext in {".mp4", ".mov", ".webm", ".mkv", ".avi"}:
                msg_type = "video"
            elif ext in {".wav", ".mp3", ".m4a", ".ogg", ".flac"}:
                msg_type = "audio"
            else:
                msg_type = "media"

        entry = {
            "msg_id": mid,
            "date": m.get("date", ""),
            "title": extract_title(text),
            "type": msg_type,
            "url": f"{URL_BASE}/{mid}",
            "topics": extract_topics(text),
            "text_full": text,
            "text_preview": text[:400] if text else "",
        }
        if prio_item:
            entry["filename"] = prio_item.get("filename", "")
            entry["size_mb"] = prio_item.get("size_mb", 0)
            entry["priority"] = prio_item.get("category", "")

        entries.append(entry)

    entries.sort(key=lambda e: -e["msg_id"])

    out = {
        "channel": "Алексей Колесов | Private",
        "channel_id": CHANNEL_ID,
        "generated": "2026-04-21",
        "total_posts": len(entries),
        "posts": entries,
    }
    (SCHOOL / "library_index.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # Also produce markdown version
    md_lines = [
        "# Алексей Колесов — Библиотека канала",
        "",
        f"**Channel ID:** {CHANNEL_ID}",
        f"**URL base:** {URL_BASE}/<msg_id>",
        f"**Total posts:** {len(entries)}",
        f"**Generated:** 2026-04-21",
        "",
        "## Канонические темы",
        "",
    ]

    # Group by topic
    by_topic = defaultdict(list)
    for e in entries:
        for t in e["topics"]:
            by_topic[t].append(e)
        if not e["topics"]:
            by_topic["_ОЩие"].append(e)

    for topic in sorted(by_topic.keys(), key=lambda t: (-len(by_topic[t]), t)):
        items = by_topic[topic]
        md_lines.append(f"### {topic} ({len(items)} постов)")
        md_lines.append("")
        for e in sorted(items, key=lambda x: -x["msg_id"])[:30]:
            type_emoji = {"video": "🎥", "audio": "🎙", "media": "📎", "text": "📝"}.get(
                e["type"], "•"
            )
            prio = e.get("priority", "")
            prio_badge = f" [{prio}]" if prio.startswith("HIGH") else ""
            size = f" ({e['size_mb']} МБ)" if e.get("size_mb", 0) > 1 else ""
            md_lines.append(
                f"- {type_emoji} [msg {e['msg_id']}]({e['url']}){prio_badge} **{e['title']}**{size}"
            )
        md_lines.append("")

    (SCHOOL / "library_index.md").write_text("\n".join(md_lines), encoding="utf-8")

    print(f"library_index.json: {len(entries)} posts")
    print(f"library_index.md: {len(by_topic)} topics indexed")
    return entries

# ---------- 2. SCHOOL MANIFEST ----------

PRINCIPLES = [
    {
        "id": "portability",
        "name": "Переносимость",
        "summary": "Только официальные образы, никаких самописных костылей. Любой сервис поднимается одним docker-compose up -d на свежем VPS за минуты.",
        "source_refs": ["msg_11 (Настройка сервера и docker с 0)", "msg_13 (n8n установка)", "msg_15 (Supabase установка)", "msg_55 (Baserow)", "msg_136 (OpenClaw VPS)"],
    },
    {
        "id": "minimal_integration",
        "name": "Минимум интеграционного кода",
        "summary": "Вместо кастомного кода — готовые ноды, скиллы, MCP серверы. Бизнес-логика живёт в конфигах, не в обвязке.",
        "source_refs": ["msg_71 (N8N MCP release)", "msg_94 (n8n MCP мультиагентность)", "msg_95 (Supabase MCP)", "msg_97 (Подключение Supabase MCP)"],
    },
    {
        "id": "simple_nodes",
        "name": "Простые ноды",
        "summary": "Каждая нода в workflow делает одну вещь. Сложное поведение = композиция нод, не один монстр.",
        "source_refs": ["msg_66 (2339 n8n workflows)", "msg_76 (N8N MCP архитектура промптов)", "msg_101 (Контент-завод)"],
    },
    {
        "id": "max_in_skills",
        "name": "Максимум в скиллах",
        "summary": "Skill > Agent > Hardcoded prompt. Скиллы редактируются, версионируются, делятся между проектами. Агент без скиллов — болтун.",
        "source_refs": ["msg_172 (Skills + DevOps победил)", "msg_174 (Гайд Skills от А до Я)", "msg_178 (Telegram Skill)"],
    },
    {
        "id": "minimal_agent_commands",
        "name": "Минимальные чёткие команды агентам",
        "summary": "Коридор без фантазий. Инструкции — короткие, императивные, с чёткими ветвлениями. Fail-loud на неожиданных данных. Без простора для галлюцинаций.",
        "source_refs": ["feedback_alexey_skills_philosophy.md", "msg_178 (Telegram Skill INSTALL.md)", "msg_76 (N8N MCP промпт-архитектура)"],
    },
    {
        "id": "single_secret_vault",
        "name": "Один секрет-vault",
        "summary": "Все ключи/токены в одном .env файле. Никогда не дублировать, один ввод — одно место. Ротация не должна требовать поиска по десяти местам.",
        "source_refs": ["feedback_single_secret_vault.md"],
    },
    {
        "id": "offline_first",
        "name": "Offline-first где возможно",
        "summary": "Работа через собственный сервер/локалку. Cloud только где действительно нужен. Self-host LightRAG, n8n, Supabase, Леший — всё своё.",
        "source_refs": ["msg_39 (Леший установка)", "msg_48 (Леший в облаке для приватки)", "msg_158 (LightRAG мозг для агентов)"],
    },
    {
        "id": "validate_before_automate",
        "name": "Подписка-триал перед автоматизацией",
        "summary": "Месяц подписки → проверить ценность → решить продление. Не вкладываться в долгие автоматизации на непроверенных данных.",
        "source_refs": ["project_alexey_subscription_plan.md"],
    },
    {
        "id": "human_pacing",
        "name": "Человеческий ритм API",
        "summary": "Не насилуй API. Случайные паузы 1-5 мин + длинные перерывы 30-90 мин. Не бёрстить даже если есть квота. Takeout где доступен.",
        "source_refs": ["наш опыт Grok/Telegram: download.mjs скрипт"],
    },
    {
        "id": "content_factory_model",
        "name": "Модель «контент-завод»",
        "summary": "Парсинг чужого контента → фильтр по качеству → пересборка в свой стиль → автопубликация. Масштабируется через скиллы, не через увеличение кол-ва людей.",
        "source_refs": ["msg_101 (Контент-завод для Telegram)", "msg_102 (Файлы по ТГ Контент-Заводу)", "msg_103 (За кулисами контент-завода)"],
    },
]

CURRICULUM = [
    {
        "level": 0,
        "id": "L0",
        "title": "Философия vibe-кодинга (зачем и почему)",
        "goal": "Понять что такое vibe-кодинг, чем отличается от классического, и почему подход Алексея работает для non-developer бизнес-владельцев.",
        "lessons": [
            {
                "id": "L0.1",
                "title": "Что такое vibe-кодинг",
                "materials": {"posts": [68, 69, 57, 58, 172, 174], "transcripts": [170]},
                "exercise": "Найди в канале пост где Алексей описывает своё первое впечатление от AI-агентов. Что его зацепило?",
            },
            {
                "id": "L0.2",
                "title": "Канон: Skills > Agents > Prompts",
                "materials": {"posts": [172, 174, 178], "memory": ["feedback_alexey_skills_philosophy.md"]},
                "exercise": "Выбери один свой проект. Опиши что в нём сейчас — хардкод-промпт, агент, или скилл? Как переделать в скилл?",
            },
            {
                "id": "L0.3",
                "title": "Портабельность и минимум интеграционного кода",
                "materials": {"posts": [11, 13, 15, 55, 136], "memory": ["feedback_portable_stack.md"]},
            },
        ],
    },
    {
        "level": 1,
        "id": "L1",
        "title": "Инструменты vibe-кодера",
        "goal": "Освоить 4 главных инструмента: Claude Code, Kilo Code, Cursor, Gemini CLI. Знать когда какой выбирать.",
        "lessons": [
            {"id": "L1.1", "title": "Claude Code: главный рабочий инструмент", "materials": {"posts": [111, 58]}},
            {"id": "L1.2", "title": "Kilo Code: альтернатива + подписная модель", "materials": {"posts": [80, 82, 111]}},
            {"id": "L1.3", "title": "Gemini CLI: бесплатная альтернатива", "materials": {"posts": [56, 57, 58]}},
            {"id": "L1.4", "title": "VS Code + AI-зоопарк за копейки", "materials": {"posts": [68, 69]}},
        ],
    },
    {
        "level": 2,
        "id": "L2",
        "title": "Базовая инфраструктура (VPS + Docker + n8n + Supabase)",
        "goal": "Поставить и настроить базовый стек на собственном VPS. Понимать как каждый компонент работает.",
        "lessons": [
            {"id": "L2.1", "title": "VPS с 0: выбор, регистрация, докер", "materials": {"posts": [11, 12], "files": ["configs_instructions.zip"]}},
            {"id": "L2.2", "title": "Установка n8n", "materials": {"posts": [13], "files": ["n8n.zip"]}},
            {"id": "L2.3", "title": "Установка Supabase", "materials": {"posts": [15], "files": ["supabase.zip"]}},
            {"id": "L2.4", "title": "Nginx Proxy Manager + Portainer", "materials": {"posts": [14, 11]}},
            {"id": "L2.5", "title": "Baserow (таблицы как сервис)", "materials": {"posts": [55], "files": ["baserow.zip"]}},
        ],
    },
    {
        "level": 3,
        "id": "L3",
        "title": "MCP серверы — расширение агента",
        "goal": "Понять MCP-протокол. Подключить n8n MCP, Supabase MCP, LightRAG MCP. Использовать как инструменты агента.",
        "lessons": [
            {"id": "L3.1", "title": "Что такое MCP и зачем", "materials": {"posts": [166], "files": ["INSTRUCTION_CONNECT_MCP.md"]}},
            {"id": "L3.2", "title": "N8N MCP Server: архитектура + release", "materials": {"posts": [63, 64, 71, 72, 76, 77, 78, 94], "files": ["devops_team.zip", "agent_template.zip"]}},
            {"id": "L3.3", "title": "Supabase MCP Server", "materials": {"posts": [95, 97], "files": ["sup_mcp_docs.zip"]}},
            {"id": "L3.4", "title": "LightRAG — мозг агента", "materials": {"posts": [156, 157, 158, 160], "files": ["lightrag.zip"]}},
        ],
    },
    {
        "level": 4,
        "id": "L4",
        "title": "Агентные системы",
        "goal": "Построить многоагентную систему. Понять когда нужна и когда НЕ нужна.",
        "lessons": [
            {"id": "L4.1", "title": "Когда нужны multi-agent системы", "materials": {"posts": [170], "transcripts": [165]}},
            {"id": "L4.2", "title": "Леший — LibreChat fork", "materials": {"posts": [37, 39, 42, 46, 47, 48, 53]}},
            {"id": "L4.3", "title": "OpenClaw — ИИ-агент 24/7", "materials": {"posts": [133, 134, 136, 137]}},
            {"id": "L4.4", "title": "Paperclip — AI-компания без людей", "materials": {"posts": [142, 143, 144, 146, 147, 148, 149], "files": ["Paperclip_install.zip"]}},
        ],
    },
    {
        "level": 5,
        "id": "L5",
        "title": "Skills — формат Алексея (canonical)",
        "goal": "Научиться писать скиллы по канону Алексея: минимальные, чёткие, точные, fail-loud.",
        "lessons": [
            {"id": "L5.1", "title": "SKILL.md — структура", "materials": {"posts": [172, 174, 178], "files": ["Skills от А до Я.pdf", "telegram.zip", "claude_prompt.md"]}},
            {"id": "L5.2", "title": "INSTALL.md для агента — как Алексей делает", "materials": {"posts": [178], "files": ["telegram.zip"]}},
            {"id": "L5.3", "title": "Практика: напиши свой скилл", "exercise": "Выбери простой use-case из твоего бизнеса. Напиши 1 SKILL.md + 1 INSTALL.md по канону."},
        ],
    },
    {
        "level": 6,
        "id": "L6",
        "title": "Автоматизация контента (Content Factory)",
        "goal": "Построить контент-завод: парсинг доноров → анализ → генерация → публикация.",
        "lessons": [
            {"id": "L6.1", "title": "Архитектура контент-завода", "materials": {"posts": [101, 102, 103, 104]}},
            {"id": "L6.2", "title": "TGStat парсер каналов-доноров", "materials": {"posts": [102, 103], "files": ["content_zavod_tg.zip"]}},
            {"id": "L6.3", "title": "Supabase как хранилище постов", "materials": {"posts": [19, 20, 21, 22]}},
        ],
    },
    {
        "level": 7,
        "id": "L7",
        "title": "Продакшн и масштабирование",
        "goal": "Деплой, безопасность, мониторинг. Как масштабировать команду AI-агентов вместо найма людей.",
        "lessons": [
            {"id": "L7.1", "title": "DevOps-команда из 8 агентов", "materials": {"posts": [91, 93], "files": ["devops_team.zip"]}},
            {"id": "L7.2", "title": "Закулисье: нюансы, грабли, безопасность", "materials": {"posts": [137]}},
            {"id": "L7.3", "title": "AI-продавец — реальный бизнес-кейс", "materials": {"posts": [17, 19, 20, 21, 22], "files": ["ai_seller_rag.zip"]}},
        ],
    },
]

def build_school_manifest():
    manifest = {
        "school_name": "Vibe Coder School (canon Алексея)",
        "version": "1.0",
        "generated": "2026-04-21",
        "audience": "начинающий vibe-coder без технического бэкграунда (но с бизнес-опытом)",
        "teacher_role": "Claude Code в роли наставника. Следовать канону Алексея, адаптироваться под уровень ученика, использовать материалы библиотеки.",
        "principles": PRINCIPLES,
        "curriculum": CURRICULUM,
        "library_index": "library_index.json (same dir)",
        "knowledge_paths": {
            "posts_dump": "../alexey-reference/export-2026-04-20/result.json",
            "transcripts": "../alexey-reference/export-2026-04-20/transcripts/",
            "priority_catalog": "../alexey-reference/export-2026-04-20/p4_priority.json",
            "downloaded_files": "../alexey-reference/export-2026-04-20/media/ (локально после rsync; сейчас на Aeza /opt/tg-export/media/)",
        },
        "protocol": {
            "session_start": "Прочитать этот manifest + library_index.json. Спросить у ученика цель сессии (если ещё не знает): \"Хочешь пройти Module L0 философии? Или у тебя конкретная задача?\"",
            "teaching_style": "Сократовский метод: задать вопрос → получить ответ → скорректировать. Не читать лекцию.",
            "canon_enforcement": "Если ученик предлагает решение противоречащее принципам Алексея — остановить, показать принцип + msg_id где он описан, переубедить.",
            "progress_tracking": "В конце каждого модуля — 3 вопроса проверки. Сохранять прогресс в docs/school/progress_<student>.md.",
            "escalate_to_videos": "Если вопрос ученика лучше разбирается в одном из Alexey видео — дать ссылку и цитату из транскрипта.",
        },
    }

    (SCHOOL / "school_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"school_manifest.json: {len(PRINCIPLES)} principles, {len(CURRICULUM)} modules")

# ---------- 3. LAUNCHER PROMPT ----------

def build_launcher():
    text = """# Vibe Coder School — стартер для нового Claude Code чата

## Контекст (отдашь этот текст в новом чате)

Ты — наставник в **Vibe Coder School** по канону Алексея Колесова.

**Ученик:** Илья (брокер с 20-летним опытом Дубай/Сочи/Бали, его первый SaaS, технически неопытен, бизнесно очень опытен). Переменная — значит в будущем сюда придут другие ученики.

**Твоя задача:** Учить vibe-кодингу **на материалах канала Алексея** (приватка, оплаченная подписка). Не придумывать своё — использовать КАНОН Алексея как источник правды.

## Обязательно перед первым ответом

1. **Прочитай manifest:** `docs/school/school_manifest.json`
   - Это главный документ. В нём 10 принципов Алексея, 8 модулей curriculum, и ссылки на все материалы.

2. **Прочитай библиотеку:** `docs/school/library_index.json`
   - Все 154 поста канала проиндексированы: title, дата, тип, URL, темы, превью.
   - Используй для поиска релевантных материалов когда ученик задаёт вопрос.

3. **При необходимости — транскрипты:** `docs/alexey-reference/export-2026-04-20/transcripts/`
   - 3 файла уже готовы (4.6ч аудио): 164 (встреча), 165 (Телемост), 170 (маленький).
   - По мере транскрибации HIGH_CODE видео в фоне, транскриптов станет больше.

4. **Канон memory:** `~/.claude/memory/canon_alexey_library_index.md`
   - Главное правило: все продакшн-решения — через базу Алексея.

## Первое сообщение ученику (шаблон)

```
Привет, Илья. Я наставник Vibe Coder School по канону Алексея Колесова.

У нас 8 модулей:
L0 — Философия vibe-кодинга
L1 — Инструменты (Claude Code, Kilo, Cursor, Gemini CLI)
L2 — Инфраструктура (VPS + Docker + n8n + Supabase)
L3 — MCP серверы (расширение агента)
L4 — Агентные системы (Леший, OpenClaw, Paperclip)
L5 — Skills (канон Алексея)
L6 — Content Factory (автоматизация контента)
L7 — Продакшн и масштабирование

Варианты старта:
(а) Пройти с L0 по порядку
(б) У тебя есть конкретная задача — разберём её через призму канона
(в) Диагностика: короткий блиц-опрос что ты уже знаешь, построю трек

Что выбираешь?
```

## Стиль работы

- **Сократовский диалог:** задать вопрос → дать подумать → скорректировать. Не лекция.
- **Иллюстрируй:** каждое утверждение снабжай `msg_<id>` ссылкой из library_index или цитатой из транскрипта.
- **Канон-энфорсмент:** если ученик хочет «сделать по-своему» и это против принципа — стоп, покажи принцип из школьного манифеста.
- **Прогресс:** после каждого модуля — 3 вопроса проверки + запись в `docs/school/progress_ilya.md`.

## Тон

Прямой. Без воды. Без "excellent question!". Ученик — взрослый бизнесмен, уважаем его время. Но при этом учитываем: он non-dev, объясняем понятно. Алексей в своих видео матерится и шутит — можно легко копировать этот стиль для близости (но не переборщить).

## Важные ограничения

- Материалы Алексея **только для личного обучения Ильи**. Не публиковать, не пересылать, не коммитить в git (канал платный).
- Если Алексей в посте говорит «это инсайд только для подписчиков» — уважать и не распространять.
- Если транскрипт для поста ещё не готов — сказать «видео msg-X транскрибируется, пока опирайся на текст + файлы».

## Как стартовать

В новом Claude Code чате, открытом в папке `realty-portal/`:
1. Вставь всё выше начиная с "# Контекст" как первое сообщение
2. Claude прочитает manifest + library_index
3. Начнётся обучение
"""

    (SCHOOL / "launcher_prompt.md").write_text(text, encoding="utf-8")
    print(f"launcher_prompt.md: {len(text)} chars")

# ---------- MAIN ----------
if __name__ == "__main__":
    print("== Building library index ==")
    build_library()
    print("\n== Building school manifest ==")
    build_school_manifest()
    print("\n== Building launcher prompt ==")
    build_launcher()
    print(f"\nAll 3 files in: {SCHOOL}")
