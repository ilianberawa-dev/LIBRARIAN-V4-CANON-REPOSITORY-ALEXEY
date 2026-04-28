# Дерево библиотеки — полная номенклатура

**Назначение:** актуальная карта всех папок и ключевых файлов репо. Читают —
**Архитектор** и **Дизайнер** при выборе роли (см. `.claude/skills/onboarding.md`).
Узкому установщику и Не-программисту — НЕ нужно.

**Принцип актуальности:** этот файл — часть библиотеки и **обновляется вместе
с ней**. Если меняешь структуру (добавил папку / переименовал / удалил) —
обнови соответствующий блок ниже в том же коммите.

**Последнее обновление:** 2026-04-28 (удалены 5 устаревших корневых файлов)

---

## 📁 КОРЕНЬ — карта папок

| Папка | Что внутри | Когда трогать |
|---|---|---|
| `inbox/` | Свалка для новых файлов от Ильи | По команде «разбери inbox» |
| `kanon/` | 12 принципов Алексея + Memory Pyramid + Simplicity First | **Архитектор: всегда фон** |
| `alexey-materials/` | 154 поста + 88 транскриптов + media (15MB) | **Через `metadata/index_compact.json`** |
| `dizain/` | Тема «Дизайн / UI» | При разборе inbox по теме |
| `arhitektura/` | Тема «Архитектура» | При разборе inbox по теме |
| `prochee-idei/` | Тема «Прочее / идеи» | При разборе inbox по теме |
| `metody/` | МЕТОДЫ разработки (1 тема: personal-ai-assistant) | По запросу |
| `rukovodstva/` | РУКОВОДСТВА (1 тема: self-learning-memory) | По запросу |
| `navyki/` | НАВЫКИ-паттерны (heartbeat-telegram, parser-control) | По запросу |
| `spravochniki/` | СПРАВОЧНИКИ (skills-a-to-ya 108KB) | По запросу |
| `troubleshoot/` | Решения известных проблем | По запросу |
| `scripts/` | Утилиты (inbox-tools, helpers) | По запросу |
| `docs/` | session-memory + handoff между чатами | См. ниже |
| `aeza-archive/` | Бэкап Aeza VPS (4.4MB) | **Не трогать без явной просьбы** |
| `school-materials/` | Архив переписки агентов (692KB) | **Не трогать без явной просьбы** |
| `OLD-PARSER-STRUCTURE/` | Архив старого парсера (420KB) | **Не трогать без явной просьбы** |

---

## 🛠️ `.claude/` — конфигурация Claude Code

```
.claude/
├── settings.json              # permissions allow/deny/ask + SessionStart hook
├── hooks/
│   └── session-start.sh       # 12 строк динамики (inbox + 3 session-memory + указатели)
└── skills/                    # 5 lazy-loaded skills
    ├── onboarding.md          # ритуал старта (4 вопроса, роли)
    ├── library-search.md      # 3-слойный поиск + Слой 0 мульти-агент
    ├── state-check.md         # проверки до уточняющего вопроса (3 шага)
    ├── session-memory.md      # запись итога сессии
    └── inbox-triage.md        # разбор inbox по проектам (не по типу файла)
```

**Triggering:** все skills lazy-loaded через `description:` во frontmatter.
Архитектор не «заучивает» их содержимое — Claude Code подгружает по триггеру.

---

## 📜 `kanon/` — канон Алексея

| Файл | Строк | Назначение |
|---|---|---|
| `alexey-11-principles.md` | 162 | **12 принципов** (#0 Простота → #11 Architectural Privilege) |
| `memory-pyramid-principle.md` | 70 | Иерархия памяти агента (4 слоя) |
| `simplicity-first-principle.md` | 605 | Принцип #0 в деталях + чеклисты + кейсы |
| `README.md` | 55 | Описание раздела |

**Архитектор при первом заходе** — обязательно `alexey-11-principles.md`.
**Memory Pyramid** — фон для решений про память/контекст.

---

## 📦 `alexey-materials/` — материалы автора канона

```
alexey-materials/
├── INDEX.md                   # описание раздела
├── README.md
├── WHATS_NEW.md
├── metadata/                  # ВХОД ДЛЯ ПОИСКА
│   ├── index_compact.json     # → СНАЧАЛА СЮДА (компактный индекс 154 постов)
│   ├── library_index.json     # полный индекс (тяжёлый)
│   ├── taxonomy.json          # 10 категорий маршрутизации (см. ниже)
│   ├── synonyms.json          # синонимы для поиска
│   ├── transcript_keys.json   # ключи транскриптов
│   ├── p4_catalog.json        # каталог P4
│   ├── p4_priority.json       # приоритизация P4
│   └── result.json
├── transcripts/               # 88 файлов (.json + .txt) — расшифровки видео
├── media/                     # 5 файлов (PDF/фото)
└── Алексей Колесов - Private.md
```

**10 категорий taxonomy** (для маршрутизации Слой 1 поиска):
- `AI_AGENTS` — ИИ-агенты и фреймворки (OpenClaw, Claude Code, Cursor)
- `SKILLS_MCP` — Скиллы и MCP-серверы
- `WORKFLOW` — Воркфлоу и оркестрация (n8n)
- `DATA_STORAGE` — Базы данных и хранилища (Supabase, Baserow)
- `MEMORY_RAG` — Память агентов (LightRAG)
- `INFRA` — Инфраструктура и DevOps (Docker, Nginx)
- `COMMUNICATION` — Каналы коммуникации (Telegram)
- `PARSING` — Парсинг и скрейпинг
- `PRODUCTS_AK` — Продукты Алексея
- `PRINCIPLES_BIZ` — Принципы и монетизация

**Правило поиска:** см. `.claude/skills/library-search.md` — 3 слоя
(taxonomy → compact index → grep).

---

## 📚 `docs/` — память и передача между чатами

```
docs/
├── session-memory/            # BROADCAST всем чатам
│   └── YYYY-MM-DD-<role>-<topic>.md
├── handoff/                   # АДРЕСНАЯ передача преемнику
│   ├── README.md
│   └── 2026-04-27-architect-enforcement-handoff.md
└── handoff-from-chat/         # Inbox от другого Клода (web-Claude)
    └── README.md
```

| Папка | Тип | Кто читает |
|---|---|---|
| `session-memory/` | Broadcast | Все чаты при старте (hook печатает 3 последних) |
| `handoff/` | Адресная | Конкретный преемник через JSON в первом сообщении |
| `handoff-from-chat/` | Web-Claude → этот репо | См. `.claude/skills/onboarding.md` секцию «Web-Claude handoff» |

---

## 🔧 `troubleshoot/` — решения проблем

| Файл | Тема |
|---|---|
| `stale-snapshot.md` | **Чат работает на устаревшем снимке репо** (важно!) |
| `aeza-server-tree-map.md` | Карта Aeza VPS (193.233.128.21) |
| `claude-code-vscode-install.md` | Установка Claude Code в VS Code |
| `telegram-parser-recreation.md` | Воссоздание Telegram-парсера |
| `README.md` | — |

---

## 📋 Корневые файлы — справка

| Файл | Назначение |
|---|---|
| `CLAUDE.md` | **Главный диспетчер для AI** (4 правила YOU MUST + карта папок + правила поведения) |
| `_INDEX.md` | Этот файл (полное дерево, актуальное) |
| `PARSER-RESTORATION-MISSION.json`, `HANDOFF-TELEPORT-SESSION.json`, `PARSER-GITHUB-SYNC-ALGORITHM.md` | Артефакты предыдущих миссий |

---

## 🔄 Правило обновления `_INDEX.md`

**Когда:** при любом структурном изменении репо
- Добавил/переименовал/удалил папку в корне
- Добавил/удалил skill в `.claude/skills/`
- Добавил новый файл в `kanon/`
- Изменил структуру `alexey-materials/metadata/`

**Как:** обнови соответствующий блок выше + дату «Последнее обновление» вверху.
В коммите укажи: `docs(_INDEX): <что изменилось>`.

**Принцип:** дерево живёт вместе с библиотекой. Устаревший `_INDEX.md` —
такой же баг как устаревший CLAUDE.md (см. `troubleshoot/stale-snapshot.md`).
