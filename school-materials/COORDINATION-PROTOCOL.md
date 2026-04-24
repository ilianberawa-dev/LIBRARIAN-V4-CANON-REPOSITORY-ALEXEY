# Mesh Coordination Protocol — File-Based

**Дата создания:** 2026-04-24  
**Метод:** docs/school/handoff/ JSON files  
**Используется до:** установки MCP Agent Mail

---

## Принцип

Каждая роль ведёт свой `<role>-current.json` в `docs/school/handoff/`.  
Другие роли **читают эти файлы** для понимания статуса mesh.

---

## Структура файлов

```
docs/school/handoff/
  librarian-v4-current.json    ← librarian пишет, остальные читают
  school-v4-current.json        ← school пишет, остальные читают
  parser-v4-current.json        ← parser пишет, остальные читают
  ai-helper-v3-current.json     ← ai-helper пишет, остальные читают
```

---

## JSON Schema (обязательные поля)

```json
{
  "role": "librarian-v4",                    // REQUIRED
  "status": "bootstrapping|ready|working|blocked",  // REQUIRED
  "timestamp": "2026-04-24T15:30:00+08:00",  // REQUIRED (ISO 8601)
  "session_info": {
    "environment": "Claude Desktop Local",
    "working_directory": "C:\\work\\realty-portal",
    "model": "claude-opus-4-7",
    "context_level": "~5%"                   // self-reported
  },
  "current_task": "string или null",         // что сейчас делает
  "blocked_by": ["issue1", "issue2"],        // что блокирует (пусто если нет)
  "last_activity": "2026-04-24T15:30:00+08:00",
  "coordination_status": {
    "contacts": {
      "school-v4": "connected|pending|blocked",
      "parser-v4": "connected|pending|blocked"
    }
  }
}
```

---

## Протокол обновления

### Когда обновлять свой файл

1. **Bootstrap complete** → `status: "ready"`
2. **Начало задачи** → `current_task: "описание"`, `status: "working"`
3. **Задача завершена** → `current_task: null`, `status: "ready"`
4. **Blocker** → `status: "blocked"`, `blocked_by: ["причина"]`
5. **Каждые 15-30 мин** → обновить `last_activity` (heartbeat)

### Формат обновления

**Полная перезапись файла** (не append):
```bash
# Прочитать текущий
read C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json

# Изменить нужные поля в памяти
# Записать обратно целиком
write C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json
```

---

## Протокол чтения (discovery других ролей)

### Частота проверки

- **Перед началом задачи** — проверь статус других ролей
- **При blockers** — проверь кто может помочь
- **Каждые 30 мин** — heartbeat check

### Пример: school хочет узнать статус librarian

```bash
# 1. Прочитать файл
read C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json

# 2. Парсить JSON
- status = "ready" → можно делегировать задачу
- status = "working" → занят, проверь current_task
- status = "blocked" → проверь blocked_by, возможно школа может помочь
- status = "bootstrapping" → ещё не готов

# 3. Проверить last_activity
- если timestamp старше 2 часов → роль возможно offline
```

---

## Координация задач (без MCP Agent Mail)

### Способ 1: Задачи через файлы

**school создаёт задачу для librarian:**

```bash
# Создать файл задачи
write C:\work\realty-portal\docs\school\tasks\task-001-install-mcp.json

{
  "task_id": "task-001",
  "assigned_to": "librarian-v4",
  "created_by": "school-v4",
  "created_at": "2026-04-24T16:00:00+08:00",
  "priority": "high",
  "title": "Install MCP Agent Mail on Aeza",
  "description": "Follow 10-step plan from librarian_v3.md handoff",
  "status": "pending",
  "blocked_by": null
}
```

**librarian читает и принимает:**

```bash
# 1. Прочитать docs/school/tasks/*.json
# 2. Найти assigned_to = "librarian-v4"
# 3. Обновить task status
write C:\work\realty-portal\docs\school\tasks\task-001-install-mcp.json
# изменить "status": "in_progress"

# 4. Обновить свой current.json
write C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json
# добавить "current_task": "task-001: Install MCP Agent Mail"
```

### Способ 2: Сообщения через файлы

**librarian → school:**

```bash
write C:\work\realty-portal\docs\school\messages\msg-2026-04-24-1530-librarian-to-school.md

---
from: librarian-v4
to: school-v4
timestamp: 2026-04-24T15:30:00+08:00
priority: normal
---

School,

Bootstrap complete. Ready to start MCP Agent Mail installation.
Waiting for Ilya "старт" command per handoff instructions.

Current blockers:
- Need user approval to begin 35-40 min installation

Next actions after approval:
1. SSH to Aeza
2. Run 10-step installation
3. Create SSH tunnel
4. Test connectivity

Please advise.

— librarian-v4
```

**school читает:**

```bash
# Читать все docs/school/messages/msg-*-to-school.md
# Парсить, обрабатывать
# Отвечать через новый файл msg-*-school-to-librarian.md
```

---

## Presence heartbeat

Каждая роль обновляет `last_activity` каждые 15-30 мин:

```json
{
  "role": "librarian-v4",
  "status": "ready",
  "last_activity": "2026-04-24T16:00:00+08:00"  ← UPDATE THIS
}
```

Другие роли могут видеть кто online:
- `last_activity` свежее 1 часа → online
- `last_activity` старше 2 часов → возможно offline

---

## Миграция на MCP Agent Mail

Когда MCP Agent Mail установлен:

1. **Все роли обновляют coordination_status**:
```json
{
  "coordination_status": {
    "mcp_agent_mail": "CONNECTED",
    "coordination_method": "MCP Agent Mail (SSE)",
    "fallback": "docs/school/ files"
  }
}
```

2. **Файлы остаются как fallback** на случай если MCP недоступен

3. **Основная коммуникация через MCP threads**, но статус дублируется в JSON

---

## Примеры использования

### Пример 1: school проверяет готовность всех ролей

```bash
# Читать все 4 файла
read C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json
read C:\work\realty-portal\docs\school\handoff\school-v4-current.json
read C:\work\realty-portal\docs\school\handoff\parser-v4-current.json
read C:\work\realty-portal\docs\school\handoff\ai-helper-v3-current.json

# Парсить status всех ролей
# Если все "ready" → mesh готов к работе
# Если кто-то "bootstrapping" → ждать
```

### Пример 2: parser сообщает о завершении работы

```bash
# Обновить свой статус
write C:\work\realty-portal\docs\school\handoff\parser-v4-current.json
{
  "role": "parser-rumah123-v4",
  "status": "completed",
  "current_task": null,
  "result": "Scraped 408 properties from Rumah123",
  "output_location": "data/scraped/rumah123_2026-04-24.json"
}

# School прочитает при следующей проверке
```

### Пример 3: librarian блокирован, уведомляет school

```bash
write C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json
{
  "role": "librarian-v4",
  "status": "blocked",
  "blocked_by": ["Waiting for Ilya approval to install MCP Agent Mail"],
  "current_task": "MCP Agent Mail installation (paused)"
}

# Создать сообщение для school
write C:\work\realty-portal\docs\school\messages\msg-2026-04-24-1600-librarian-to-school.md
```

---

## Troubleshooting

### Проблема: Роль не видит обновления

**Причина:** Файл не обновляется или неправильный путь

**Решение:**
```bash
# Проверить наличие файла
ls -la C:\work\realty-portal\docs\school\handoff\*.json

# Проверить timestamp
cat C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json | grep timestamp
```

### Проблема: JSON невалидный

**Причина:** Синтаксическая ошибка при записи

**Решение:**
```bash
# Валидировать JSON
cat C:\work\realty-portal\docs\school\handoff\librarian-v4-current.json | jq .

# Если ошибка → исправить и перезаписать
```

### Проблема: Конфликт одновременной записи

**Причина:** Две роли пытаются писать в один файл

**Решение:** 
- Каждая роль пишет **только в свой файл**
- librarian-v4 → librarian-v4-current.json
- school-v4 → school-v4-current.json
- Никаких пересечений

---

## Итого

✅ **Каждая роль владеет своим JSON**  
✅ **Читает чужие для координации**  
✅ **Обновляет при изменении статуса**  
✅ **Heartbeat каждые 15-30 мин**  
✅ **Миграция на MCP без breaking changes**
