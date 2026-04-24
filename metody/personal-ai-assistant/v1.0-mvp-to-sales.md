# AI Assistant Development Method — Canon v1.0

**Дата:** 2026-04-24  
**Автор:** librarian-v4  
**Статус:** CANONICAL METHOD  
**Применение:** Personal AI Assistant → Client Product

---

## Философия метода

**Принцип:** Claude Code строит и меняет начинку, ты только даёшь доступы.

**Архитектура:** Skills-based, минимум custom кода, максимум MCP интеграций.

**Управление:** Через Claude Desktop GUI ИЛИ через мессенджеры (Telegram, WhatsApp).

**Развитие:** MVP → Self-use → Parser/Content → Client Sales

---

## Архитектура AI Assistant

```
┌─────────────────────────────────────────────────────┐
│              USER (ты или клиент)                   │
└────────┬──────────────────────────────┬─────────────┘
         │                              │
    Claude Desktop GUI          Telegram/WhatsApp
         │                              │
         └──────────────┬───────────────┘
                        │
              ┌─────────▼──────────┐
              │   AI ASSISTANT     │
              │  (Claude Session)  │
              └─────────┬──────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
    │ Memory  │   │ Skills  │   │  MCP    │
    │ System  │   │ Library │   │Servers  │
    └─────────┘   └─────────┘   └─────────┘
         │              │              │
         └──────────────┼──────────────┘
                        │
         ┌──────────────┼──────────────────────────┐
         │              │              │           │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐ ┌────▼────┐
    │  Gmail  │   │ Google  │   │Telegram │ │  APIs   │
    │   MCP   │   │Calendar │   │   MCP   │ │ (food,  │
    │         │   │Drive MCP│   │         │ │ travel) │
    └─────────┘   └─────────┘   └─────────┘ └─────────┘
```

---

## Компоненты системы

### 1. Memory System (долгосрочная память)

**Хранилище:** `~/.claude/memory/<assistant-name>/`

**Структура:**
```
memory/
  user-profile.md          ← кто пользователь, предпочтения
  context/
    active-tasks.json      ← текущие задачи
    preferences.json       ← настройки (любимые рестораны, аптеки)
    contacts.json          ← важные контакты
  history/
    2026-04-24.jsonl      ← лог действий за день
  integrations/
    gmail-threads.json    ← треды email
    calendar-events.json  ← предстоящие события
```

**Обновление:** Каждая сессия пишет в memory после action.

**Canon Skill:** `/memory` (read, write, search)

---

### 2. Skills Library (навыки)

**Базовые навыки (must-have):**

| Skill | Описание | MCP/API |
|-------|----------|---------|
| `gmail-check` | Проверить inbox, summarize новые письма | Gmail MCP |
| `gmail-reply` | Ответить на email, draft | Gmail MCP |
| `calendar-check` | Проверить events на сегодня/неделю | Google Calendar MCP |
| `calendar-add` | Добавить event | Google Calendar MCP |
| `drive-search` | Найти файл в Google Drive | Google Drive MCP |
| `telegram-send` | Отправить сообщение в Telegram | Telegram MCP |
| `telegram-read` | Прочитать входящее (webhook) | Telegram MCP |
| `proactive-think` | Проактивное мышление (что забыл?) | LLM reasoning |
| `task-plan` | Разбить задачу на подзадачи | TaskCreate |
| `reminder-set` | Установить напоминание | Cron/Calendar |

**Продвинутые навыки (add later):**

| Skill | Описание | API |
|-------|----------|-----|
| `flight-search` | Поиск билетов (Aviasales API) | REST API |
| `hotel-book` | Бронирование (Booking.com API) | REST API |
| `food-order` | Заказ еды (Delivery Club API) | REST API |
| `medicine-check` | Подбор лекарств (аптеки API) | REST API |
| `form-fill` | Заполнение заявок (web scraping) | Playwright |
| `parser-run` | Запуск парсера данных | Custom skill |
| `content-generate` | Генерация контента | LLM + templates |

---

### 3. MCP Servers (интеграции)

**Обязательные:**

```json
{
  "mcpServers": {
    "gmail": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-gmail"]
    },
    "google-calendar": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-google-calendar"]
    },
    "google-drive": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-google-drive"]
    },
    "telegram": {
      "command": "npx",
      "args": ["-y", "telegram-mcp@latest"]
    }
  }
}
```

**Опциональные (для клиентов):**

- Slack MCP
- WhatsApp MCP (через Twilio)
- Notion MCP
- Airtable MCP

---

### 4. Proactive Thinking Engine

**Концепция:** AI Assistant не ждёт команды, а сам думает что нужно.

**Реализация через Cron:**

```yaml
# ~/.claude/cron-jobs.yaml
jobs:
  morning-brief:
    schedule: "0 8 * * *"  # Каждый день 8:00
    skill: morning-briefing
    description: "Утренний брифинг: погода, календарь, важные emails"

  proactive-check:
    schedule: "0 */2 * * *"  # Каждые 2 часа
    skill: proactive-thinking
    description: "Проактивная проверка: что забыл? что скоро deadline?"

  evening-summary:
    schedule: "0 20 * * *"  # Каждый день 20:00
    skill: day-summary
    description: "Итоги дня: что сделано, что осталось"
```

**Skill `proactive-thinking` logic:**

```python
def proactive_thinking():
    # 1. Читаем memory
    tasks = read_memory("active-tasks.json")
    calendar = check_calendar(next_7_days=True)
    emails = check_gmail(unread=True, priority=True)
    
    # 2. Анализируем
    issues = []
    
    # Deadlines скоро
    for task in tasks:
        if task.deadline - now() < 24h:
            issues.append(f"⚠️ Deadline через {hours}ч: {task.title}")
    
    # События без подготовки
    for event in calendar:
        if event.time - now() < 2h and not event.prepared:
            issues.append(f"📅 Событие через {hours}ч без подготовки: {event.title}")
    
    # Важные emails без ответа
    for email in emails:
        if email.age > 24h and email.from_important_contact:
            issues.append(f"✉️ Email без ответа 24ч+: {email.subject}")
    
    # 3. Отправляем notification
    if issues:
        send_telegram("\n".join(issues))
```

---

## Метод разработки (пошагово)

### PHASE 1: MVP (1-2 недели)

**Цель:** Работающий assistant для себя.

**Шаги:**

1. **Setup MCP servers** (Gmail, Calendar, Drive, Telegram)
   ```bash
   # Claude делает:
   - Установить MCP servers через npx
   - Настроить OAuth для Google (ты даёшь пароли)
   - Настроить Telegram bot token
   - Проверить connectivity
   ```

2. **Создать базовые skills**
   ```bash
   # Claude создаёт в ~/.claude/skills/:
   - gmail-check.sh
   - calendar-check.sh
   - telegram-send.sh
   - proactive-think.sh
   ```

3. **Setup memory system**
   ```bash
   # Claude создаёт структуру:
   mkdir -p ~/.claude/memory/my-assistant/{context,history,integrations}
   
   # Заполнить user-profile.md:
   write ~/.claude/memory/my-assistant/user-profile.md
   ```

4. **Первый запуск**
   ```
   Открыть Claude Desktop → New chat "My AI Assistant"
   
   Первое сообщение:
   "Ты мой AI Assistant. Прочитай мой профиль из memory.
   Проверь Gmail inbox за последние 24ч.
   Проверь Calendar на сегодня.
   Дай brief."
   ```

5. **Тестирование команд:**
   - "Проверь почту"
   - "Что у меня в календаре завтра?"
   - "Напомни мне через 2 часа позвонить Илье"
   - "Отправь в Telegram: Всё готово"

**Критерий успеха:** Все 5 команд работают без ошибок.

---

### PHASE 2: Self-Use (2-4 недели)

**Цель:** Ежедневное использование, накопление опыта.

**Шаги:**

1. **Утренний ритуал**
   - Каждое утро: "Дай утренний брифинг"
   - Claude проверяет: погода, календарь, важные emails, задачи на день
   - Отправляет в Telegram

2. **Проактивные напоминания**
   - Настроить cron jobs (morning-brief, proactive-check, evening-summary)
   - Claude сам пингует в Telegram когда что-то важное

3. **Сбор feedback**
   - Записывать в `~/.claude/memory/feedback.md`:
     - Что работает хорошо
     - Что не работает
     - Что забывает
     - Какие навыки нужны

4. **Итерация skills**
   - Каждую неделю: Claude читает feedback и улучшает skills
   - Добавляет новые навыки по запросу

**Критерий успеха:** 80% рабочих дней используешь assistant, меньше 3 багов в неделю.

---

### PHASE 3: Parser + Content (1-2 месяца)

**Цель:** Наращивание функций для бизнеса.

**Добавить:**

1. **Parsers (для Realty Portal)**
   ```
   Skills:
   - parser-rumah123 (уже есть)
   - parser-lamudi
   - parser-property-guru
   
   Integration:
   - Assistant проверяет парсеры каждое утро
   - Если новые объекты → отправляет summary в Telegram
   - Если ошибка парсера → алерт
   ```

2. **Content Generation**
   ```
   Skills:
   - content-generate-listing (описание объекта недвижимости)
   - content-generate-social (пост для соцсетей)
   - content-translate (перевод EN↔RU↔ID)
   
   Workflow:
   1. Парсер нашёл новый объект
   2. Assistant генерирует описание
   3. Переводит на 3 языка
   4. Постит в Telegram канал / соцсети
   ```

3. **Analytics**
   ```
   Skills:
   - analytics-daily (сколько объектов, какие районы)
   - analytics-trends (что популярно, цены)
   
   Cron job:
   - Каждый понедельник: weekly report в Telegram
   ```

**Критерий успеха:** Assistant автоматически мониторит парсеры и генерит контент без твоего участия.

---

### PHASE 4: Client Ready (подготовка к продаже)

**Цель:** Упаковать в продукт для клиентов.

**Шаги:**

1. **Создать onboarding script**
   ```bash
   # install-assistant.sh
   
   1. Установить Claude Desktop
   2. Настроить MCP servers (Gmail, Calendar, Telegram)
   3. OAuth авторизация (клиент даёт доступы)
   4. Создать memory структуру
   5. Первый запуск (заполнение профиля)
   6. Тестовые команды
   ```

2. **Документация для клиента**
   ```markdown
   # AI Assistant User Guide
   
   ## Что умеет:
   - ✅ Проверяет почту и отвечает
   - ✅ Управляет календарём
   - ✅ Напоминания и задачи
   - ✅ Проактивные советы
   - ✅ Интеграции с мессенджерами
   
   ## Как управлять:
   - Через Claude Desktop GUI
   - Через Telegram (пересылаешь → он читает)
   
   ## Команды:
   - "Проверь почту"
   - "Что в календаре?"
   - "Напомни через X часов..."
   - "Отправь в Telegram..."
   ```

3. **Pricing model**
   ```
   Тарифы:
   
   Basic ($49/мес):
   - Gmail + Calendar + Telegram
   - Proactive reminders
   - 1000 AI requests/мес
   
   Pro ($99/мес):
   - Basic +
   - Google Drive
   - Custom skills (до 5)
   - 5000 AI requests/мес
   
   Business ($299/мес):
   - Pro +
   - Parsers
   - Content generation
   - Analytics
   - Unlimited requests
   ```

4. **Упаковка для продажи**
   ```
   Создать:
   - Landing page (что умеет, цены)
   - Demo video (как работает)
   - Trial version (7 дней бесплатно)
   - Support (Telegram чат для клиентов)
   ```

**Критерий успеха:** 3+ платящих клиента, retention >80%.

---

## Архитектурные Принципы (Канон Алексея)

**11 принципов для написания систем** — применяются на ВСЕХ фазах:

### 1. Portability (Портабельность)
✅ **Применение в AI Assistant:**
- MCP servers через npx (не custom install)
- Memory в `~/.claude/` (стандартная локация)
- Config в `.claude/settings.json` (официальный формат)
- **Result:** Переезд на новую машину = скопировать .claude + перезапустить

### 2. Minimal Integration Code
✅ **Применение:**
- Используем готовые MCP servers (Gmail, Calendar, Drive)
- НЕ пишем свой email client
- Логика в skills (`.md` файлы), не в промптах
- **Result:** Меньше кода → меньше багов

### 3. Simple Nodes
✅ **Применение:**
- Один skill = одна задача (`gmail-check`, `calendar-add`)
- НЕ создавать `super-assistant-do-everything.sh`
- Композиция: `gmail-check` + `proactive-think` → утренний брифинг
- **Result:** Легко тестировать и чинить

### 4. Skills Over Agents ⭐ КЛЮЧЕВОЙ
✅ **Применение:**
- Phase 1: создаём 5-10 базовых skills
- Phase 2: добавляем skills, НЕ создаём новых агентов
- Phase 3: parser/content = новые skills существующему assistant
- **Anti-pattern:** Создать 10 агентов для 10 задач (token waste)
- **Result:** Один assistant + растущая библиотека skills

### 5. Minimal Clear Commands
✅ **Применение:**
- Commands чёткие: "Проверь почту", "Добавь в календарь на завтра 15:00"
- НЕ: "Посмотри что там с делами и может напомнить если что-то важное"
- Fail-loud: если команда непонятна → запросить уточнение
- **Result:** Предсказуемое поведение

### 6. Single Secret Vault
✅ **Применение:**
- Все API keys в `.env` или system keychain
- OAuth tokens через официальные MCP auth flows
- НЕ хардкодить токены в skills
- **Result:** Ротация ключей = одно место

### 7. Offline First
✅ **Применение:**
- LLM inference через Ollama (локально) где возможно
- Embeddings через Ollama на Aeza
- LightRAG на своём сервере (не SaaS vector DB)
- Cloud API только где нужно (Gmail, Calendar)
- **Result:** Дёшево + контроль данных

### 8. Validate Before Automate
✅ **Применение:**
- Phase 1 (MVP): 1-2 недели manual testing
- Phase 2 (Self-Use): 2-4 недели ежедневного использования
- Только после успеха → Phase 3 (автоматизация парсеров)
- **Anti-pattern:** Сразу автоматизировать всё без проверки
- **Result:** Не автоматизируем ерунду

### 9. Human Rhythm API ⚠️ CRITICAL для парсеров
✅ **Применение:**
- Proactive checks: НЕ каждые 5 мин чётко
- Случайные паузы: 1-5 мин, перерывы 5-20 мин, длинные 30-90 мин
- Email/Calendar checks: имитация человека (утро, обед, вечер)
- Parser scraping: random delays между запросами
- **Result:** Не банят за bot behaviour

**Implementation:**
```python
import random, time

def human_pause(action_type="default"):
    if action_type == "quick":
        time.sleep(random.uniform(1, 5))  # 1-5 мин
    elif action_type == "break":
        time.sleep(random.uniform(5, 20))  # 5-20 мин
    elif action_type == "long":
        time.sleep(random.uniform(30, 90))  # 30-90 мин
    
# Usage in skills
check_gmail()
human_pause("quick")
check_calendar()
human_pause("break")
process_tasks()
```

### 10. Content Factory Model
✅ **Применение в Phase 3:**
- Parser → фильтр по качеству → пересборка → автопубликация
- Пример: парсим Rumah123 → LLM генерит описание → постим в канал
- **Result:** Масштаб через skills, не людей

### 11. Architectural Privilege Isolation 🔒 SECURITY
✅ **Применение:**
- НЕ давать assistant skill `execute-arbitrary-sql`
- Вместо этого: `get-email-by-id`, `add-calendar-event` (параметризованные)
- Client-facing assistant: ограниченный набор skills (не полный доступ к Supabase)
- **Result:** Prompt injection не может уронить БД

**Architecture layers:**
```
User prompt (может быть injection)
    ↓
Assistant (LLM)
    ↓
Skills (SAFE interface)
    ↓  ✅ Parametrized, validated
Data layer (Gmail, DB, etc)
```

**Anti-pattern:**
```python
# BAD - generic SQL skill
def run_sql(query: str):
    return db.execute(query)  # Injection!

# GOOD - specific, safe skill
def get_user_email(user_id: int):
    query = "SELECT email FROM users WHERE id = ?"
    return db.execute(query, [user_id])  # Parametrized
```

---

## Архитектурный Чеклист (проверка перед релизом)

**Перед каждой фазой проверь:**

- [ ] ✅ **Portability:** Можно развернуть на новой машине за <30 мин?
- [ ] ✅ **Minimal Code:** Используем готовые MCP/skills вместо custom кода?
- [ ] ✅ **Simple Nodes:** Каждый skill = одна задача?
- [ ] ✅ **Skills Library:** Растём через skills, не через агентов?
- [ ] ✅ **Clear Commands:** Все команды чёткие и императивные?
- [ ] ✅ **Single Vault:** Все ключи в одном месте (.env)?
- [ ] ✅ **Offline First:** Минимум cloud dependencies?
- [ ] ✅ **Validated:** Протестировали 2-4 недели перед автоматизацией?
- [ ] ✅ **Human Rhythm:** Случайные паузы, не регулярные интервалы?
- [ ] ✅ **Content Model:** Парсинг → фильтр → пересборка → авто?
- [ ] ✅ **Security:** Критичные операции архитектурно изолированы?

**Если хоть один НЕТ → рефакторинг до соответствия канону.**

---

## Технический stack

### Core:
- **Claude Code** — основа
- **Claude Desktop** — GUI для управления
- **MCP Protocol** — интеграции

### MCP Servers:
- Gmail MCP (`@anthropic-ai/mcp-server-gmail`)
- Google Calendar MCP (`@anthropic-ai/mcp-server-google-calendar`)
- Google Drive MCP (`@anthropic-ai/mcp-server-google-drive`)
- Telegram MCP (`telegram-mcp`)

### Skills:
- Bash scripts (`.sh`)
- Python scripts (`.py`) для сложной логики
- Claude Code native skills (`/skill-name`)

### Storage:
- Memory: `~/.claude/memory/` (JSON + Markdown)
- Config: `.claude/settings.json`
- Cron: CronCreate tool (через Claude Code)

### APIs (для продвинутых функций):
- Aviasales API (билеты)
- Booking.com API (отели)
- Delivery Club API (еда)
- Аптеки API (лекарства)

---

## Канонические правила

### 1. Минимум custom кода

❌ **НЕ писать:**
- Свой email client
- Свой calendar manager
- Свой Telegram bot с нуля

✅ **Использовать:**
- MCP servers для готовых интеграций
- Claude Code skills для логики
- API wrappers через `curl`/`WebFetch`

### 2. Claude строит начинку

**Процесс:**

1. Ты: "Добавь навык заказа еды через Delivery Club"
2. Claude:
   - Изучает API Delivery Club
   - Создаёт skill `food-order.sh`
   - Тестирует
   - Добавляет в skills library
3. Ты: Даёшь API key Delivery Club
4. Готово

**Ты НЕ пишешь код** — Claude всё делает.

### 3. Управление через мессенджеры

**Telegram integration:**

```
Ты → Telegram: "Проверь почту"
Telegram bot → Claude session (via webhook)
Claude → проверяет Gmail
Claude → отправляет результат в Telegram
```

**Реализация:**

```yaml
# Telegram webhook handler (skill)
skill: telegram-handler
trigger: webhook
url: https://your-server.com/telegram-webhook

logic:
  - Получить сообщение от Telegram
  - Распознать команду
  - Выполнить через Claude
  - Ответить в Telegram
```

### 4. Память всегда актуальна

**После каждой сессии:**

```bash
# Skill: update-memory
1. Записать в history/YYYY-MM-DD.jsonl что было сделано
2. Обновить active-tasks.json
3. Обновить preferences.json если изменились
4. Sync с Google Drive (backup)
```

**Перед каждой сессией:**

```bash
# Skill: load-memory
1. Прочитать user-profile.md
2. Прочитать active-tasks.json
3. Прочитать последний history entry
4. Восстановить контекст
```

---

## Roadmap от MVP до продаж

### Week 1-2: MVP Setup
- [ ] Установить MCP servers (Gmail, Calendar, Telegram)
- [ ] Создать базовые skills (5 команд)
- [ ] Setup memory system
- [ ] Первый запуск и тест

### Week 3-6: Self-Use
- [ ] Ежедневное использование
- [ ] Настройка proactive cron jobs
- [ ] Сбор feedback
- [ ] Итерация skills

### Week 7-14: Parser + Content
- [ ] Интеграция парсеров (Rumah123, Lamudi)
- [ ] Content generation skills
- [ ] Analytics и reporting
- [ ] Автоматизация workflow

### Week 15-20: Client Ready
- [ ] Onboarding script
- [ ] Документация
- [ ] Pricing model
- [ ] Landing page + demo
- [ ] Trial version

### Week 21+: Sales & Scale
- [ ] Найти первых 3 клиентов (знакомые, соцсети)
- [ ] Собрать feedback
- [ ] Улучшить продукт
- [ ] Масштабировать (реклама, партнёрства)

---

## Метрики успеха

### Phase 1 (MVP):
- ✅ 5 базовых команд работают
- ✅ Подключены 4 MCP servers
- ✅ Memory система создана

### Phase 2 (Self-Use):
- ✅ Используешь 5 дней в неделю минимум
- ✅ <3 багов в неделю
- ✅ Экономит 2+ часа в неделю

### Phase 3 (Parser + Content):
- ✅ Парсеры работают автономно
- ✅ Контент генерится без твоего участия
- ✅ Weekly reports автоматически

### Phase 4 (Client Ready):
- ✅ 3+ платящих клиента
- ✅ Retention >80%
- ✅ MRR $300+

---

## Следующие шаги (для тебя сейчас)

1. **Прочитай этот метод полностью** ✅ (сейчас)

2. **Реши: начинать MVP?**
   - Если да → переходим к Phase 1 Setup
   - Если нужно уточнить → спрашивай

3. **Phase 1 первый шаг:**
   ```
   Установить Gmail MCP:
   
   Claude Desktop → Settings → MCP Servers → Add:
   {
     "gmail": {
       "command": "npx",
       "args": ["-y", "@anthropic-ai/mcp-server-gmail"]
     }
   }
   
   OAuth авторизация (я помогу)
   ```

4. **После Gmail → Calendar → Drive → Telegram**

5. **Потом создаём первый skill: gmail-check**

---

**Готов начать Phase 1?** Скажи "старт MVP" — я проведу через все шаги.
