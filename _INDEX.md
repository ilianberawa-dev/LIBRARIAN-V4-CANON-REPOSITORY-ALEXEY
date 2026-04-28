# Claude Library — Persistent Knowledge Base

**Локация:** `C:\Users\97152\Documents\claude-library\`  
**GitHub:** https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY  
**Назначение:** Доступ из ЛЮБОГО Claude чата на этой машине  
**Создано:** 2026-04-24  
**Создатель:** librarian-v4  
**Номенклатура:** Транслит + Русские README (Git-friendly + Человеко-понятно)

---

## 🗂️ Категории (Маппинг транслит → русский)

| Транслит | Русский | Emoji | Статус |
|----------|---------|-------|--------|
| `metody/` | МЕТОДЫ разработки | 📘 | ✅ 1 тема |
| `rukovodstva/` | РУКОВОДСТВА по компонентам | 📚 | ✅ 1 тема |
| `kanon/` | КАНОН (принципы) | 📜 | ✅ 2 документа |
| `navyki/` | НАВЫКИ (skills) | 🛠️ | ✅ 1 паттерн |
| `spravochniki/` | СПРАВОЧНИКИ | 📖 | ✅ 1 гайд |
| `troubleshoot/` | РЕШЕНИЕ ПРОБЛЕМ | 🔧 | ✅ 1 гайд |

---

## 📂 Структура библиотеки

```
claude-library/
  ├── _INDEX.md (этот файл)
  │
  ├── metody/              ← МЕТОДЫ
  │   ├── README.md
  │   └── personal-ai-assistant/
  │       ├── README.md
  │       ├── v1.0-mvp-to-sales.md (767 lines)
  │       └── CHANGELOG.md
  │
  ├── rukovodstva/         ← РУКОВОДСТВА
  │   ├── README.md
  │   └── self-learning-memory/
  │       ├── README.md
  │       ├── v1.0-lightrag.md (620 lines)
  │       └── CHANGELOG.md
  │
  ├── kanon/               ← КАНОН ✨ ОБНОВЛЕНО
  │   ├── README.md
  │   ├── alexey-11-principles.md (12 принципов)
  │   └── simplicity-first-principle.md (605 lines)
  │
  ├── spravochniki/        ← СПРАВОЧНИКИ ✨ ОБНОВЛЕНО
  │   ├── README.md
  │   └── skills-a-to-ya.md (108KB полный гайд)
  │
  ├── navyki/              ← НАВЫКИ ✨ ОБНОВЛЕНО
  │   ├── README.md
  │   └── heartbeat-telegram-pattern.md (proven pattern)
  │
  └── troubleshoot/        ← ПРОБЛЕМЫ ✨ ОБНОВЛЕНО
      ├── README.md
      └── telegram-parser-recreation.md (полный гайд воссоздания)
```

---

## 🎯 Как работает номенклатура

### ✅ Git-friendly:
- Папки: `metody`, `rukovodstva`, `kanon` (транслитом)
- Файлы: `v1.0-mvp-to-sales.md` (латиницей)
- Коммиты работают везде (Windows/Mac/Linux)

### ✅ Человеко-понятно:
- README.md в КАЖДОЙ папке на русском
- CHANGELOG.md на русском
- Этот _INDEX.md с маппингом

### Принцип:
```
СТРУКТУРА транслитом → ОПИСАНИЕ на русском
```

---

## 📚 Текущее содержимое

### 1. МЕТОДЫ / personal-ai-assistant

**Полное название:** Личный AI Ассистент  
**Файл:** `metody/personal-ai-assistant/v1.0-mvp-to-sales.md`  
**Размер:** 767 строк, ~27KB

**О чём:**
- 4 фазы: MVP → Self-Use → Parser/Content → Client Sales
- Архитектура: Memory + Skills + MCP
- 11 принципов Алексея
- Roadmap 20+ недель
- Pricing $49-299/month

---

### 2. РУКОВОДСТВА / self-learning-memory

**Полное название:** Самообучающаяся Память (RAG)  
**Файл:** `rukovodstva/self-learning-memory/v1.0-lightrag.md`  
**Размер:** 620 строк, ~20KB

**О чём:**
- RAG архитектура
- LightRAG integration
- Attribution (WHO/WHEN/WHERE)
- Learning loop
- Use cases

---

### 3. КАНОН / alexey-11-principles ✨ НОВОЕ

**Полное название:** 12 Принципов Алексея для AI-систем  
**Файл:** `kanon/alexey-11-principles.md`  
**Размер:** ~5KB

**О чём:**
- Принцип #0: Simplicity First (P0)
- Принципы #1-11: Portability → Architectural Privilege Isolation
- Для каждого: правило, почему, деньги, примеры
- Extracted from canon_training.yaml v0.5

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\kanon\alexey-11-principles.md
```

---

### 4. КАНОН / simplicity-first-principle

**Полное название:** Принцип "Простота Прежде Всего"  
**Файл:** `kanon/simplicity-first-principle.md`  
**Размер:** 605 строк, ~28KB

**О чём:**
- Обязательный чеклист перед ответом AI
- Decision tree простых решений
- Anti-patterns overengineering
- "Бабушка-тест" (объяснить за 30 сек)
- Реальный кейс: 2 часа → 5 минут

**Применение:** ОБЯЗАТЕЛЬНО для всех AI перед ответом

---

### 5. СПРАВОЧНИКИ / skills-a-to-ya ✨ НОВОЕ

**Полное название:** Skills от A до Я  
**Файл:** `spravochniki/skills-a-to-ya.md`  
**Размер:** 108KB

**О чём:**
- Полный справочник по AI Skills
- От базовых до продвинутых
- Примеры использования
- Best practices

---

## 🔍 Как искать по теме

`synonyms.json` → теги → `index_compact.json` → транскрипт или preview  
Полная инструкция: `navyki/library-search.md`

---

## 🚀 Быстрый старт

### Новому Claude чату:

**Шаг 1 - Прочитай index:**
```
Read C:\Users\97152\Documents\claude-library\_INDEX.md
```

**Шаг 2 - Загрузи обязательный канон:**
```
Read C:\Users\97152\Documents\claude-library\kanon\simplicity-first-principle.md
```

**Шаг 3 - Выбери нужную тему:**
```
Read C:\Users\97152\Documents\claude-library\metody\personal-ai-assistant\v1.0-mvp-to-sales.md
```

---

## 🔄 Workflow обновлений

### Добавить новую версию:

1. Создай файл: `cp v1.0-old.md v1.1-new-feature.md`
2. Обнови CHANGELOG.md
3. Обнови README.md темы
4. Обнови _INDEX.md
5. `git add . && git commit && git push`

---

## 📋 Roadmap

### Ближайшее:

**Навыки:**
- [ ] `navyki/proactive-think/` - Проактивное мышление pattern
- [ ] `navyki/gmail-check/` - Проверка почты skill

**Справочники:**
- [ ] `spravochniki/mcp-servers-setup/` - Настройка MCP серверов
- [ ] `spravochniki/lightrag-api-reference/` - LightRAG API

**Troubleshooting:**
- [ ] `troubleshoot/lightrag-slow-queries/` - Оптимизация LightRAG
- [ ] `troubleshoot/cf-blocks-parser/` - Обход Cloudflare блокировок

---

## 📊 Статистика (оригинальные категории)

**Основных файлов:** 13 (metody, rukovodstva, kanon, spravochniki)  
**Всего строк:** 3500+  
**Категорий:** 6 (4 активные, 2 в roadmap)  
**Тем:** 5 (personal-ai-assistant, self-learning-memory, alexey-principles, simplicity-first, skills-a-to-ya)  
**Размер core контента:** ~180KB

---

## 🔒 Доступ и безопасность

**Доступ:** Только локальная машина + GitHub (private/public по выбору)  
**Git:** ✅ Git-friendly (транслит латиницей)  
**Backup:** GitHub auto-backup при каждом push

---

**Последнее обновление:** 2026-04-24  
**Создано:** librarian-v4  
**Формат:** Универсальный (Git + Человек)

---

## 📦 АРХИВЫ (новые категории)

### 6. Материалы Алексея ✅ ПОЛНАЯ СИНХРОНИЗАЦИЯ 2026-04-29

**Папка:** `alexey-materials/`  
**Размер:** 15MB (56 полных транскриптов + metadata)

**Что ЗДЕСЬ (в claude-library) ✅ СИНХРОНИЗИРОВАНО:**
- **Транскрипты:** 56 файлов (112 файлов: .json + .txt, полная копия из Aeza)
  - #164 "Аудио запись встречи 06.03.26" (встреча с основателем)
  - #165 "Встреча в Телемосте 05.04.26" (LightRAG routing 06:40-09:10) ⭐
  - #170 "видео"
  - + 53 дополнительных файла (полный репертуар Алексея 103-170)
- **Metadata:** 
  - `library_index.json` — **ИСТОЧНИК ИСТИНЫ** (154 поста, все метаданные, size_mb, priority)
  - `taxonomy.json` — 10 категорий маршрутизации
  - `index_compact.json` — быстрый поиск
- **Media:** PDF, фото (17MB, в отдельной папке)

**Архитектура (решено 2026-04-29):**
- 🔍 **Источник истины:** `/opt/tg-export/library_index.json` на Aeza (154 поста)
- 📂 **claude-library:** 56 полных транскриптов (git backup + быстрый доступ)
- 🗄️ **Aeza /transcripts/:** 56 полных файлов (working copy)
- 🧠 **UpCloud LightRAG:** 56 indexed документов (основной поиск через RAG-engine, Stage 2)
- 📤 **GitHub:** все 56 синхронизированы (коммит 491ca11, push 2026-04-29)

---

### 7. Архив Aeza

**Папка:** `aeza-archive/`  
**Файлов:** 420+  
**Размер:** ~35MB

**Содержимое:**
- Полная копия /opt/tg-export с сервера
- Скрипты (heartbeat.sh, download.mjs, notify.sh)
- Логи работы системы
- Расширенная коллекция транскриптов
- JSON статусы и metadata

**Backup:** Offline копия критической инфраструктуры

---

### 8. School координация

**Папка:** `school-materials/`  
**Файлов:** 30+  
**Размер:** 700KB

**Содержимое:**
- canon_training.yaml (основной канон)
- Handoff файлы ролей
- Mailbox communication
- Task definitions
- Coordination protocols

---

## 📊 ФИНАЛЬНАЯ СТАТИСТИКА

**Всего файлов в Git:** 155 (после уборки)  
**Общий размер:** 42MB (было 51MB)  
**Категорий:** 9 (6 оригинальных + 3 архива)  
**Активного контента:** 7 категорий

**Breakdown:**
- Канон/принципы: 3 файла
- Методы: 4 файла
- Руководства: 4 файла
- Справочники: 2 файла (включая 108KB skills guide)
- Навыки: 1 файл (Heartbeat Telegram pattern)
- Материалы Алексея: 22 файла (canonical копии)
- Aeza архив: 85 файлов (после удаления дубликатов)
- School материалы: 31 файл
- Troubleshooting: roadmap

**Удалено при уборке (22 файла):**
- __MACOSX мусор (5 файлов)
- .DS_Store системные файлы
- .pid runtime артефакты (2 файла)
- Дубликаты медиа (7 файлов, сохранены в alexey-materials)
- Дубликаты транскриптов (6 файлов, canonical в alexey-materials)
- 171_media_171 (0 байт, битый файл)

**Исключено из Git (безопасность):**
- aeza-archive/.env (credentials)
- aeza-archive/_mcp_mail_eval (embedded repository)

---

**Последнее обновление:** 2026-04-29  
**Источники:** Локальная машина + Aeza server + GitHub  
**Backup:** Полный offline доступ к материалам

---

## 🔴 ТЕКУЩИЙ СТАТУС ЗАДАЧ (2026-04-29)

| Задача | Статус | Где |
|--------|--------|-----|
| 56 транскриптов в claude-library | ✅ ГОТОВО | Windows локально |
| Aeza LightRAG работает | ✅ Up 28h | 193.233.128.21:9621 |
| Aeza LightRAG ingestion | ⚠️ 15/56 (27%) | нет cron, ручной |
| UpCloud LightRAG deploy | ✅ Stage 1 готов | 213.163.207.84 |
| UpCloud LightRAG ingestion | ❌ Stage 2 не начат | ждёт запуска |
| ingest cron / webhook | ❌ не настроен | нужен на Aeza |

## ⚠️ ИЗВЕСТНЫЕ КОСЯКИ (зафиксированы в memory)

1. **_INDEX.md врёт** — всегда проверяй локально: `ls alexey-materials/transcripts/*.json | wc -l`
2. **cosine_threshold 0.2** на Aeza — слишком низкий, поднять до 0.4 при миграции
3. **Нет алерта** при провале ingestion (нарушение Принципа #5 Fail Loud)
4. **GitHub ≠ локальная папка** — после push парсера нужен git pull на Windows

---

### 6. НАВЫКИ / heartbeat-telegram-pattern ✨ НОВОЕ

**Полное название:** Self-Healing Heartbeat через Telegram  
**Файл:** `navyki/heartbeat-telegram-pattern.md`  
**Размер:** 334 строки

**О чём:**
- Proven pattern из tg-export (7 дней uptime в продакшне)
- heartbeat.sh: watchdog каждые 10 мин (auto-restart, log rotation)
- notify.sh: Telegram push notifications каждые 2ч
- _status.json: state snapshot
- Адаптация для AI Assistant (memory-sync, proactive-think)

**Применение:** Long-running процессы, AI Assistant monitoring

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\navyki\heartbeat-telegram-pattern.md
```


---

### 7. TROUBLESHOOTING / telegram-parser-recreation ✨ НОВОЕ

**Полное название:** Telegram Parser — Recreation Guide  
**Файл:** `troubleshoot/telegram-parser-recreation.md`  
**Размер:** 1300+ строк, ~150KB

**О чём:**
- Полная архитектура Telegram парсера (7 компонентов)
- sync_channel.mjs: детект новых постов + классификация (HIGH_CODE/SALES/MED/LOW)
- download.mjs: приоритетное скачивание P1-P4 + human pacing (anti-ban)
- transcribe.sh: Grok STT транскрибация + chunking для больших файлов
- heartbeat.sh: watchdog с auto-restart + log rotation
- notify.sh: Telegram уведомления каждые 2ч
- verify.sh: health checks
- enumerate_p4.mjs: приоритизация постов

**Proven metrics (Aeza production):**
- 7 дней uptime без ручного вмешательства
- 48 файлов скачано (P1: 27, P2: 7, P3: 16)
- 15 транскриптов (7.18ч аудио)
- Стоимость Grok STT: $0.72
- 3 auto-restarts (все корректные)
- 0 false positives

**3 варианта воссоздания:**
1. **Quick Clone** (10 минут) — copy с Aeza + setup
2. **Claude Desktop Integration** (30 минут) — управление через skills
3. **Full Recreation** (1 час) — с нуля, адаптация под свой канал

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\troubleshoot\telegram-parser-recreation.md
```

---

### 8. НАВЫКИ / claude-bot-parser-control ✨ НОВОЕ

**Полное название:** Claude Desktop — Parser Control  
**Файл:** `navyki/claude-bot-parser-control.md`  
**Размер:** 600+ строк, ~80KB

**О чём:**
- Управление Telegram парсером через Claude Desktop чат
- 5 bash skills: status/sync/download/logs/transcribe
- Open in Terminal workflow
- 5 диалогов использования (примеры)
- MCP skill definition
- Setup за 5 минут

**Workflow:**
```
User: "Скачай все скрипты из канала Алексея"
Claude: [runs download.sh 0 1 1, opens Terminal, monitors progress]
```

**Skills created:**
- `~/.claude/skills/telegram-parser/status.sh` — показать _status.json
- `~/.claude/skills/telegram-parser/sync.sh` — detect new posts
- `~/.claude/skills/telegram-parser/download.sh` — start download
- `~/.claude/skills/telegram-parser/logs.sh` — show logs
- `~/.claude/skills/telegram-parser/transcribe.sh` — start transcribe

**Применение:**
- AI Assistant content parsing
- Автоматизация скачивания материалов канала
- Мониторинг через чат вместо SSH

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\navyki\claude-bot-parser-control.md
```

