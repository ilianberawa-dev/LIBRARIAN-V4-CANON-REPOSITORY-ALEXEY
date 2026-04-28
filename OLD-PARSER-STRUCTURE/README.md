# OLD PARSER STRUCTURE — Archive

**Создано:** 2026-04-24  
**Статус:** Архив (reference only)  
**Назначение:** Сохранить знания о старой системе парсера перед воссозданием новой

---

## ⚠️ Важно

Это **архив старой структуры парсера** из Aeza tg-export.  
Используй как **reference** при воссоздании нового парсера.

**НЕ копируй слепо** — адаптируй под новые требования AI Assistant.

---

## 📂 Структура архива

```
OLD-PARSER-STRUCTURE/
├── README.md (этот файл)
├── scripts/        ← 7 рабочих скриптов
├── docs/           ← 3 документа (полная архитектура)
├── data/           ← 2 JSON файла (индекс + статус)
└── configs/        ← (резерв для будущих конфигов)
```

---

## 🛠️ Scripts (7 файлов)

**Основные компоненты:**

1. **sync_channel.mjs** (5.6K)  
   - Детект новых постов в канале Алексея  
   - Классификация по приоритетам (HIGH_CODE/SALES/MED/LOW)  
   - Запись в library_index.json

2. **download.mjs** (10K)  
   - Приоритетное скачивание P1→P2→P3→P4  
   - Human pacing (anti-ban): SHORT_PAUSE, BURST_BREAK, LONG_BREAK  
   - Retry логика с backoff

3. **transcribe.sh** (2.6K)  
   - Grok STT транскрибация (https://api.x.ai/v1/stt)  
   - Chunking для больших файлов (>25MB)  
   - Стоимость: $0.10/hour audio

4. **heartbeat.sh** (3.7K)  
   - Watchdog каждые 10 минут (cron)  
   - Auto-restart при idle >15 минут  
   - Log rotation >50MB  
   - Запись _status.json

5. **notify.sh** (2.9K)  
   - Telegram push каждые 2 часа  
   - Cost tracking (audio_hours × $0.10)  
   - HTML форматирование

6. **verify.sh** (1.8K)  
   - Health checks (process, files, connectivity)  
   - Используется heartbeat для проверок

7. **enumerate_p4.mjs** (2.4K)  
   - Приоритизация постов в P4  
   - Подсчёт статистики

---

## 📚 Docs (3 файла)

1. **telegram-parser-recreation.md** (18KB)  
   - Полная архитектура 7 компонентов  
   - Proven metrics: 7 дней uptime, $0.72 cost  
   - 3 варианта воссоздания (Quick Clone / Desktop Integration / Full Recreation)

2. **claude-bot-parser-control.md** (16KB)  
   - Управление парсером через Claude Desktop  
   - 5 bash skills (status/sync/download/logs/transcribe)  
   - Open in Terminal workflow

3. **heartbeat-telegram-pattern.md** (9KB)  
   - Self-healing pattern с Telegram уведомлениями  
   - Proven в продакшне (7 дней, 3 auto-restarts, 0 false positives)  
   - Адаптация для AI Assistant

---

## 💾 Data (2 файла)

1. **library_index.json** (273KB)  
   - Индекс 142 постов из канала Алексея  
   - Структура: id, text, media, hasCode, priority, downloaded, processed, timestamp

2. **_status.json** (295 bytes)  
   - Последний снимок состояния  
   - last_check, downloads_today, transcriptions_done, audio_hours, cost

---

## 🎯 Как использовать этот архив

### При воссоздании парсера:

**1. Читай docs/telegram-parser-recreation.md ПЕРВЫМ**  
Там полная архитектура + 3 варианта воссоздания.

**2. Используй scripts/ как reference**  
- Не копируй слепо — адаптируй под новые требования  
- Обрати внимание на human pacing константы (анти-бан)  
- Grok STT endpoint + chunking логика  
- Приоритизация P1-P4

**3. Heartbeat pattern — универсальный**  
docs/heartbeat-telegram-pattern.md — применим для любых long-running процессов.

**4. Claude Desktop integration**  
docs/claude-bot-parser-control.md — готовые bash skills для управления.

---

## ⚙️ Proven Metrics (Aeza production)

**Работало 7 дней без ручного вмешательства:**
- 48 файлов скачано (P1: 27, P2: 7, P3: 16)  
- 15 транскриптов (7.18ч аудио)  
- Стоимость Grok STT: $0.72  
- 3 auto-restarts (все корректные)  
- 0 false positives  
- Uptime: 100%

**Heartbeat:**
- Проверки каждые 10 минут  
- Уведомления каждые 2 часа  
- Idle detection: 15 минут  
- Log rotation: >50MB

---

## 🔗 Связь с новым парсером

**Старая структура (этот архив):**
- Монолитный подход  
- Скрипты в /opt/tg-export  
- Прямой доступ к Telegram API  
- Manual priority assignment

**Новая структура (to be created):**
- Модульная архитектура  
- Skills-based control (через Claude Desktop)  
- MCP Telegram plugin integration  
- AI-assisted priority detection  
- LightRAG integration для контента

---

## 📋 Что НЕ вошло в архив

**Не включено (intentionally):**
- `.env` файлы (credentials)  
- Скачанные медиа файлы (>1GB)  
- Логи (>100MB)  
- node_modules (dependencies)  
- Транскрипты (уже в alexey-materials/)

**Где найти:**
- Credentials: спроси у пользователя или на Aeza сервере  
- Media: root@193.233.128.21:/opt/tg-export/downloads/  
- Logs: root@193.233.128.21:/opt/tg-export/*.log  
- Dependencies: package.json в scripts/ (npm install)

---

## 🚀 Next Steps

**Для воссоздания парсера:**

1. **Прочитай docs/telegram-parser-recreation.md** (выбери вариант)
2. **Определи архитектуру** (Skills vs Scripts vs Hybrid)
3. **Настрой MCP Telegram** (вместо прямого API доступа?)
4. **Адаптируй heartbeat pattern** (для AI Assistant)
5. **Интегрируй с LightRAG** (индексация контента)
6. **Setup Claude Desktop skills** (управление через чат)

**Вопросы перед началом:**
- Нужен ли прямой доступ к Telegram API или через MCP?  
- Какие компоненты AI Assistant будут использовать парсер?  
- Где хостить: Aeza (с текущей инфраструктурой) или локально?  
- Нужна ли real-time синхронизация или batch processing?

---

## 📊 Архивная статистика

**Scripts:** 7 файлов, ~30KB  
**Docs:** 3 файла, 43KB  
**Data:** 2 файла, 273KB  
**Общий размер архива:** ~306KB (без media/logs)

**Source:** Aeza /opt/tg-export (скопировано 2026-04-24)  
**Working period:** 2026-04-17 до 2026-04-24 (7 дней)  
**Total posts processed:** 142  
**Download success rate:** 100% (48/48)

---

**Последнее обновление:** 2026-04-24  
**Создано:** teleport session (librarian-v4)  
**Назначение:** Reference для воссоздания нового парсера

---

## 🔍 Quick Reference

**Ключевые файлы для быстрого старта:**

| Задача | Файл |
|--------|------|
| Понять архитектуру | docs/telegram-parser-recreation.md |
| Скопировать heartbeat | scripts/heartbeat.sh → adapt |
| Интеграция с Claude Desktop | docs/claude-bot-parser-control.md |
| Telegram уведомления | scripts/notify.sh → adapt |
| Grok STT транскрибация | scripts/transcribe.sh → adapt |
| Human pacing (anti-ban) | scripts/download.mjs → constants |
| Приоритизация постов | scripts/sync_channel.mjs → keywords |

**Canon references:**
- Принцип #0: Simplicity-First → есть ли готовое решение?  
- Принцип #1: Portability → Docker образы, не custom setup  
- Принцип #2: Minimal Integration Code → Skills > Scripts  
- Принцип #4: Skills Over Agents → Логика в SKILL.md

✅ Архив готов к использованию
