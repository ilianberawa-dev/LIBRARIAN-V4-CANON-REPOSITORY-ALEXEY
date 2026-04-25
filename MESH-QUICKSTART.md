# Mesh Architecture — Quick Start

## Что это

4 специализированные Claude Code сессии работают параллельно, общаются через MCP Agent Mail.

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ librarian-v4 │  │  school-v4   │  │  parser-v4   │  │ ai-helper-v3 │
│    (Opus)    │  │    (Opus)    │  │   (Sonnet)   │  │   (Sonnet)   │
│              │  │              │  │              │  │              │
│ infra, docker│  │canon, orchest│  │ scraping     │  │generic tasks │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │                 │
       └─────────────────┴─────────────────┴─────────────────┘
                              │
                    MCP Agent Mail (Tailscale)
                    http://100.97.148.4:8765
```

---

## Запуск mesh (4 роли)

### Вариант A: Запуск всех сразу в Windows Terminal

Открой **4 новых таба** Windows Terminal (`Ctrl+Shift+T`), в каждом:

**Tab 1 (librarian):**
```powershell
cd C:\work\realty-portal
.\start-librarian.ps1
```

**Tab 2 (school):**
```powershell
cd C:\work\realty-portal
.\start-school.ps1
```

**Tab 3 (parser):**
```powershell
cd C:\work\realty-portal
.\start-parser.ps1
```

**Tab 4 (ai-helper):**
```powershell
cd C:\work\realty-portal
.\start-ai-helper.ps1
```

### Вариант B: Запуск по требованию

Запусти только нужные роли. Например, для работы с парсером:

```powershell
.\start-librarian.ps1  # всегда нужен (infra lead)
.\start-parser.ps1     # для парсинга
```

---

## Первый запуск (bootstrap)

Когда роль стартует впервые, она покажет bootstrap инструкции:

```
═══════════════════════════════════════════════════════
  Bootstrap instructions:
═══════════════════════════════════════════════════════

Ты — librarian-v4

1. Прочитай docs/school/handoff/librarian_v3.md для контекста
2. Выполни MCP bootstrap sequence:
   - health_check
   - ensure_project(project_key='/opt/realty-portal/docs/school')
   - register_agent(name='librarian-v4', ...)
   - request_contact с другими ролями
   - send presence ping в thread 'presence'
3. После bootstrap скажи: 'Bootstrap complete, ready for work'
```

**Просто скопируй эти инструкции в первое сообщение Claude:**

```
Выполни bootstrap sequence из инструкций выше
```

Claude автоматически:
- Прочитает handoff от предыдущей версии
- Зарегистрируется в MCP Agent Mail
- Установит contacts с другими ролями
- Будет готов к работе

---

## Переключение между ролями

**В Windows Terminal:** `Ctrl+Tab` или клик на таб

**Переименовать табы для удобства:**
1. Правый клик на таб → Settings
2. Title: добавить эмодзи `📘 librarian-v4`

---

## Как роли общаются

**Через MCP Agent Mail threads:**

```
librarian-v4 → school-v4:
  send_message(
    thread_id="librarian-to-school",
    content="Created new parser-lamudi-v1, approve?"
  )

school-v4 получает:
  fetch_inbox() → видит сообщение → одобряет
```

**Или через presence thread (broadcast всем):**

```
parser-v4:
  send_message(
    thread_id="presence",
    content="[PARSER-V4 ONLINE] ready for Rumah123 work"
  )

Все роли видят через fetch_inbox()
```

---

## Добавление новой роли

**Пример: создать parser-lamudi-v1**

### 1. Обновить agents.yaml

```yaml
agents:
  parser-lamudi-v1:
    role: parser
    version: v1
    launcher_file: docs/school/handoff/parser-lamudi-v1.md
    window_title: "🏠 parser-lamudi-v1"
    model: claude-sonnet-4-6
    working_directory: C:\work\realty-portal\scrapers
    lifecycle: short-lived  # закроется после работы
```

### 2. Создать launcher handoff

```bash
cp docs/school/handoff/parser-rumah123_v3.md docs/school/handoff/parser-lamudi-v1.md
# Отредактировать для Lamudi specifics
```

### 3. Создать shortcut

```powershell
# start-parser-lamudi.ps1
.\scripts\start-role.ps1 parser-lamudi-v1
```

### 4. Запустить

```powershell
.\start-parser-lamudi.ps1
```

---

## Handoff между версиями

Когда роль достигает 50% context:

### 1. Текущая версия пишет handoff

```markdown
# docs/school/handoff/parser-v4-to-v5.md

## Context snapshot
- 280 properties parsed from Rumah123
- Rate limit: 1 req/2s working
- Selector changed: article.card → div.property-item

## Active work
- Branch: parser/fix-pagination
- File: scrapers/rumah123/paginator.py (80% done)

## Next session TODO
1. Finish paginator.py error handling
2. Test on 50 properties
3. Full run 408 properties
```

### 2. Закрыть текущую сессию (`Ctrl+D`)

### 3. Запустить новую версию

```powershell
# Обновить agents.yaml: parser-v4 → parser-v5
.\start-parser.ps1
```

### 4. Новая версия читает handoff

```
Первое сообщение:
Ты parser-v5. Прочитай docs/school/handoff/parser-v4-to-v5.md
и продолжи работу с того места где остановился parser-v4.
```

---

## Troubleshooting

### MCP Agent Mail недоступен

```powershell
# Проверить Tailscale
tailscale status

# Должен показать:
# 100.97.148.4  aeza-realty  online

# Проверить MCP health
curl http://100.97.148.4:8765/mail/health
```

### Env vars не загружаются

```powershell
# Проверить SSH доступ к Aeza
ssh -i ~/.ssh/aeza_ed25519 root@193.233.128.21 "echo OK"

# Проверить .env файлы на сервере
ssh -i ~/.ssh/aeza_ed25519 root@193.233.128.21 "ls -la /opt/mcp_agent_mail/.env /opt/realty-portal/.env"
```

### Роль не видит других ролей

```
# В каждой роли проверить contacts:
list_contacts()

# Если пусто — сделать request_contact:
request_contact(agent_name="librarian-v4", duration_days=30)

# В другой роли одобрить:
respond_contact(request_id=..., approve=true)
```

---

## Архитектура mesh

Подробная спецификация: `docs/school/skills/autolauncher-architecture.md`

Реестр ролей: `agents.yaml`

Launcher engine: `scripts/start-role.ps1`
