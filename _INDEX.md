# Claude Library — Persistent Knowledge Base

**Локация:** `C:\Users\97152\Documents\claude-library\`  
**GitHub:** https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY  
**Назначение:** Доступ из ЛЮБОГО Claude чата на этой машине  
**Создано:** 2026-04-24  
**Создатель:** librarian-v4  
**Номенклатура:** Транслит + Русские README (Git-friendly + Человеко-понятно)

---

## ⚡ ВАЖНО для нового чата

**Главный файл инструкций — `CLAUDE.md` в корне.** Чат читает его первым:
протокол первого сообщения, 4 роли, 3-слойный поиск в библиотеке, коридор разрешений.

`_INDEX.md` (этот файл) — для людей. `CLAUDE.md` — для AI.

---

## 🗂️ Категории (Маппинг транслит → русский)

### Основные знания
| Транслит | Русский | Emoji | Статус |
|----------|---------|-------|--------|
| `metody/` | МЕТОДЫ разработки | 📘 | ✅ 1 тема |
| `rukovodstva/` | РУКОВОДСТВА по компонентам | 📚 | ✅ 1 тема |
| `kanon/` | КАНОН (принципы) | 📜 | ✅ 3 документа (+ Memory Pyramid) |
| `navyki/` | НАВЫКИ (skills) | 🛠️ | ✅ 1 паттерн |
| `spravochniki/` | СПРАВОЧНИКИ | 📖 | ✅ 1 гайд (Skills A-to-Я) |
| `troubleshoot/` | РЕШЕНИЕ ПРОБЛЕМ | 🔧 | ✅ 3 гайда |
| `dizain/` | ДИЗАЙН/UI | 🎨 | ✅ inbox + структура |

### Подбиблиотеки (большие отдельные миры)
| Папка | Что внутри | Когда использовать |
|---|---|---|
| `alexey-materials/` | 154 поста + 44 транскрипта Алексея Колесова | **Через `metadata/index_compact.json`** |
| `aeza-archive/` | Бэкап продакшн-кода Aeza (`/opt/tg-export`) | Только при работе с tg-export |
| `school-materials/` | Архив переписки агентов (school/librarian/parser/secretary) | Не трогать без явной просьбы |

### Служебное
| Папка | Что | |
|---|---|---|
| `docs/handoff-from-chat/` | Inbox: материалы из обычного Клода | По команде "что нового" |
| `docs/session-memory/` | **Память сессий** (все чаты пишут сюда) | См. CLAUDE.md "СЕССИОННАЯ ПАМЯТЬ" |
| `scripts/` | Утилиты (extract_keys, search_transcripts) | По запросу |
| `OLD-PARSER-STRUCTURE/` | Архив старой структуры парсера | Архив |

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
      ├── telegram-parser-recreation.md (полный гайд воссоздания)
      └── aeza-server-tree-map.md (карта всего Aeza VPS)
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

### 6. Материалы Алексея

**Папка:** `alexey-materials/`  
**Файлов:** 21+  
**Размер:** 16MB

**Содержимое:**
- Транскрипты (8 файлов): 164, 165, 170, и др.
- Media (PDF, фото, видео)
- Metadata (library_index.json - 142 поста)
- Guides (Skills от А до Я PDF)

**Ключевой файл:** `metadata/library_index.json` - индекс всех постов Алексея

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

**Последнее обновление:** 2026-04-24 (полная синхронизация)  
**Источники:** Локальная машина + Aeza server  
**Backup:** Полный offline доступ к материалам

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

### 7.1 TROUBLESHOOTING / aeza-server-tree-map ✨ НОВОЕ

**Полное название:** Aeza Server — Complete Tree Map  
**Файл:** `troubleshoot/aeza-server-tree-map.md`  
**Размер:** ~800 строк

**О чём:**
- Полная карта всех папок на Aeza VPS (root@193.233.128.21)
- 4 основных директории: `/opt/tg-export` (104MB), `/opt/realty-portal` (293MB), `/opt/mcp_agent_mail` (340MB), `/opt/containerd` (12KB)
- 17 Docker контейнеров (Supabase stack, LightRAG, LiteLLM, Ollama, OpenClaw)
- Детальное описание каждой папки + файлов + proven metrics
- Системные ресурсы: 2 vCPU, 8GB RAM, 59GB disk (36GB used)
- Quick reference для SSH команд

**Применение:**
- Быстрая ориентация при SSH на сервер
- Понимание что где находится
- Reference для новых AI агентов

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\troubleshoot\aeza-server-tree-map.md
```

---

### 8. НАВЫКИ / claude-bot-parser-control ✨ НОВОЕ

**Полное название:** Claude Desktop — Parser Control
**Документация:** `navyki/claude-bot-parser-control.md` (600+ строк)
**Установочный пакет:** `navyki/claude-skills/telegram-parser/` ✨ installable skill
**Размер:** 600+ строк docs + 5 executable scripts + installer

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

**Как установить (одна команда):**
```bash
# Из клона репо:
bash navyki/claude-skills/telegram-parser/install.sh

# Или через curl (без клона):
curl -fsSL https://raw.githubusercontent.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/main/navyki/claude-skills/telegram-parser/install.sh | bash
```

Скопирует 5 скриптов + SKILL.md в `~/.claude/skills/telegram-parser/`.
Детали — `navyki/claude-skills/telegram-parser/README.md`.

---

## 🎯 МИССИИ для агентов

### PARSER-RESTORATION-MISSION.json ✨ НОВОЕ

**Полное название:** Parser Infrastructure Control Mission  
**Файл:** `PARSER-RESTORATION-MISSION.json`  
**Размер:** 557 строк, comprehensive briefing

**О чём:**
- Полный briefing для агента который берёт под контроль Telegram парсер на Aeza VPS
- 4 фазы: Reconnaissance → Control → Runtime Restoration → Monitoring
- Инвентаризация: 1902 файла, 152 поста, 52 медиа, 15 транскриптов, 17 Docker контейнеров
- Proven metrics: 7 дней uptime, $0.72 cost, 0 сбоев
- Пошаговые команды (copy-paste ready)
- Decision tree для troubleshooting
- Critical warnings + success criteria

**Использование:**
```
Прочитай briefing и выполни mission:
C:/Users/97152/Documents/claude-library/PARSER-RESTORATION-MISSION.json

Начни с Phase 1 Reconnaissance.
```

**Роль библиотекаря:**
- Старый технарь = reference expert, НЕ исполнитель
- Другие агенты выполняют миссии, библиотекарь даёт советы

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\PARSER-RESTORATION-MISSION.json
```

---

## 📦 АРХИВЫ (reference only)

### OLD-PARSER-STRUCTURE/ ✨ НОВОЕ

**Полное название:** Archive of Working Parser from Aeza Production  
**Папка:** `OLD-PARSER-STRUCTURE/`  
**Размер:** 15 файлов, ~306KB (без media/logs)

**Содержимое:**
- `README.md` — comprehensive guide по использованию архива
- `scripts/` — 7 рабочих скриптов (sync, download, transcribe, heartbeat, notify, verify, enumerate)
- `docs/` — 3 документа (полная архитектура + Claude Desktop integration + heartbeat pattern)
- `data/` — 2 JSON файла (library_index.json 273KB + _status.json)
- `configs/` — резерв для конфигов

**Proven metrics из продакшна:**
- 7 дней uptime без ручного вмешательства
- 48 файлов скачано, 15 транскриптов (7.18ч audio)
- Стоимость: $0.72 (Grok STT)
- 3 auto-restarts (все корректные), 0 false positives

**Назначение:**
- Reference для воссоздания парсера
- Working code patterns
- Proven anti-ban logic (human pacing)
- Grok STT integration examples

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\OLD-PARSER-STRUCTURE\README.md
```

**Source:** root@193.233.128.21:/opt/tg-export  
**Archived:** 2026-04-24

---

**Последнее обновление:** 2026-04-24 (добавлены MISSIONS + ARCHIVES)  
**Всего категорий:** 8 (6 оригинальных + 2 новые)

