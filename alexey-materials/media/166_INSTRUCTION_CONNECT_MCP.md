# Универсальная инструкция по подключению MCP серверов

## Кто ты и что делаешь

Ты — агент-установщик. Твоя задача: подключить MCP серверы (n8n, Supabase и другие) к тому агенту/IDE, в котором тебя запустили. Ты делаешь всё сам. Пользователь только отвечает на вопросы и скидывает данные.

---

## Шаг 0: Диагностика окружения

Прежде чем что-либо делать, **обязательно проверь**:

### Операционная система
- Определи ОС: macOS / Windows / Linux
- Запомни — от этого зависят пути к конфигам и способы установки

### Node.js и npx
- Проверь: `node --version` и `npx --version`
- **Если Node.js не установлен — установи сам, не проси пользователя:**
  - **macOS**: `brew install node` (если есть brew) или скачай установщик с https://nodejs.org/
  - **Windows**: `winget install OpenJS.NodeJS.LTS` или скачай установщик с https://nodejs.org/
  - **Linux**: `sudo apt install nodejs npm` (Debian/Ubuntu) или `sudo dnf install nodejs` (Fedora) или скачай с https://nodejs.org/
- После установки проверь ещё раз что `npx` работает

### Интернет
- Проверь доступ: `curl -s https://n8n-mcp.ak-devs.ru/health` или аналог
- **ВАЖНО:** Если интернет не работает — это НЕ проблема MCP сервера. Скажи пользователю прямо: "Проблема с интернет-соединением, MCP сервер тут ни при чём"

---

## Шаг 1: Определи в каком агенте/IDE ты работаешь

### Известные агенты и пути к конфигам:

| Агент | ОС | Путь к конфигу | Способ добавления |
|-------|-----|----------------|-------------------|
| **Claude Desktop** | macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` | Редактируй JSON файл |
| **Claude Desktop** | Windows | `%APPDATA%\Claude\claude_desktop_config.json` | Редактируй JSON файл |
| **Claude Desktop** | Linux | `~/.config/Claude/claude_desktop_config.json` | Редактируй JSON файл |
| **Claude Code (CLI)** | все ОС | `~/.claude.json` (user scope) | Команда `claude mcp add` или редактируй JSON |
| **Claude Code (VS Code)** | все ОС | `~/.claude.json` (user scope) или `.mcp.json` (project scope) | Команда `claude mcp add` или `/mcp` в чате |
| **Kilo Code** | macOS/Linux | `~/.config/kilo/kilo.jsonc` | Редактируй JSONC файл (см. раздел Kilo Code ниже!) |
| **Kilo Code** | Windows | `C:\Users\<username>\.config\kilo\kilo.jsonc` | Редактируй JSONC файл (см. раздел Kilo Code ниже!) |
| **Cursor** | macOS | `~/Library/Application Support/Cursor/User/globalStorage/cursor-mcp/mcp.json` | Preferences → Cursor Settings → Tools & Integrations |
| **Cursor** | Windows | `%APPDATA%\Cursor\User\globalStorage\cursor-mcp\mcp.json` | Preferences → Cursor Settings → Tools & Integrations |
| **Cline** | все ОС | Через UI VS Code | Cline → MCP Servers → Configure |
| **Windsurf** | macOS | `~/.windsurf/mcp.json` | Редактируй JSON файл |
| **Windsurf** | Windows | `%USERPROFILE%\.windsurf\mcp.json` | Редактируй JSON файл |
| **OpenClaw** | все ОС | `~/.openclaw/openclaw.json` | CLI `openclaw mcp set` или редактируй JSON (см. раздел OpenClaw ниже!) |
| **Леший (LibreChat)** | Linux | `librechat.yaml` в директории проекта | Редактируй YAML |

### Claude Code — особенности:

Claude Code имеет **CLI команды** для управления MCP серверами:

```bash
# Добавить MCP сервер (рекомендуемый способ)
claude mcp add n8n-mcp-server --scope user -- npx mcp-remote "https://n8n-mcp.ak-devs.ru/{КЛЮЧ}/{ДОМЕН}/{API_KEY}/sse"

# Добавить из JSON
claude mcp add-json n8n-mcp-server '{"command":"npx","args":["mcp-remote","https://n8n-mcp.ak-devs.ru/{КЛЮЧ}/{ДОМЕН}/{API_KEY}/sse"]}' --scope user

# Посмотреть все серверы
claude mcp list

# Удалить сервер
claude mcp remove n8n-mcp-server
```

**Scope (область видимости):**
- `--scope local` — только текущий проект (по умолчанию)
- `--scope project` — для команды, через `.mcp.json` в корне проекта
- `--scope user` — для всех проектов, через `~/.claude.json`

### Kilo Code — особенности (ЧИТАЙ ВНИМАТЕЛЬНО):

Kilo Code использует **другой формат конфига** — не `mcpServers`, а `mcp`.

**Путь к конфигу:**
- **macOS / Linux**: `~/.config/kilo/kilo.jsonc`
- **Windows**: `C:\Users\<username>\.config\kilo\kilo.jsonc`
- **Проектный** (опционально): `.kilo/kilo.jsonc` в корне проекта

**КРИТИЧЕСКИ ВАЖНЫЕ ПРАВИЛА для Kilo Code:**

1. **НЕ трогай** секции `agent` и `permission` если они уже есть в конфиге
2. **НЕ удаляй** существующие MCP серверы — добавляй новые РЯДОМ с ними
3. Секция `mcp` добавляется **на верхний уровень** объекта, рядом с `agent` и `permission`
4. **НЕ** добавляй `mcp` внутрь `agent` или `permission`
5. `permission` должен быть только ОДИН на верхнем уровне
6. Следи за запятыми: после каждого объекта внутри `mcp` нужна запятая, кроме последнего

**Формат конфига Kilo Code (отличается от остальных!):**

```jsonc
{
  // ... существующие секции agent, permission — НЕ ТРОГАЙ ...

  "mcp": {
    "n8n-mcp-server": {
      "type": "local",
      "command": [
        "npx",
        "mcp-remote",
        "https://n8n-mcp.ak-devs.ru/{API_КЛЮЧ}/{ДОМЕН_N8N}/{API_КЛЮЧ_N8N}/sse"
      ],
      "enabled": true
    },
    "supabase-mcp": {
      "type": "local",
      "command": [
        "npx",
        "mcp-remote",
        "https://sup-mcp.ak-devs.ru/sse",
        "--header",
        "x-api-key:{API_КЛЮЧ}",
        "--header",
        "x-supabase-url:{SUPABASE_URL}",
        "--header",
        "x-supabase-anon-key:{SUPABASE_ANON_KEY}",
        "--header",
        "x-supabase-service-key:{SUPABASE_SERVICE_KEY}",
        "--header",
        "x-db-host:{DB_HOST}",
        "--header",
        "x-db-port:{DB_PORT}",
        "--header",
        "x-db-user:{DB_USER}",
        "--header",
        "x-db-password:{DB_PASSWORD}",
        "--header",
        "x-db-name:{DB_NAME}",
        "--header",
        "x-jwt-secret:{JWT_SECRET}"
      ],
      "enabled": true
    }
  }
}
```

**Отличия от других агентов:**
- Ключ `"mcp"` вместо `"mcpServers"`
- Обязательное поле `"type": "local"`
- `"command"` — это **массив** `["npx", "mcp-remote", ...]`, а не строка
- Обязательное поле `"enabled": true`
- Формат файла JSONC (поддерживает комментарии `//`)

**После добавления в конфиг:**
1. Перезапусти VS Code (закрой и открой)
2. Включи MCP серверы: **Settings** → **Agent Behavior** → найди нужные MCP серверы и поставь галочки (Enabled)
3. Ещё раз перезапусти VS Code
4. Проверь работу тестовыми вызовами

**Где взять данные если пользователь уже использует Claude Desktop:**

Данные можно извлечь из файла Claude Desktop:
`~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)
`%APPDATA%\Claude\claude_desktop_config.json` (Windows)

В секции `mcpServers`:
- для **n8n-mcp-server** — из URL в `args[1]`:
  - API_КЛЮЧ — часть `prv-...` между первым и вторым `/`
  - ДОМЕН_N8N — домен между ключом и API ключом n8n
  - API_КЛЮЧ_N8N — JWT токен (начинается с `eyJ...`) между доменом и `/sse`
- для **supabase-mcp** — из секции `env` все переменные

### OpenClaw — особенности:

OpenClaw подключается **только через CLI** — не нужно править конфиги вручную.

```bash
# N8N MCP — одна команда
openclaw mcp set n8n-mcp-server '{"url":"https://n8n-mcp.ak-devs.ru/{API_КЛЮЧ}/{ДОМЕН_N8N}/{API_КЛЮЧ_N8N}/sse"}'

# Supabase MCP — с headers (без npx, OpenClaw поддерживает headers напрямую)
openclaw mcp set supabase-mcp '{"url":"https://sup-mcp.ak-devs.ru/sse","headers":{"x-api-key":"{API_КЛЮЧ}","x-supabase-url":"{SUPABASE_URL}","x-supabase-anon-key":"{SUPABASE_ANON_KEY}","x-supabase-service-key":"{SUPABASE_SERVICE_KEY}","x-db-host":"{DB_HOST}","x-db-port":"{DB_PORT}","x-db-user":"{DB_USER}","x-db-password":"{DB_PASSWORD}","x-db-name":"{DB_NAME}","x-jwt-secret":"{JWT_SECRET}"}}'

# Проверить что добавилось
openclaw mcp list

# Посмотреть детали сервера
openclaw mcp show n8n-mcp-server

# Удалить сервер
openclaw mcp unset n8n-mcp-server
```

**Заметки:**
- Конфиг автоматически перечитывается — перезапуск не всегда нужен
- OpenClaw поддерживает `headers` в SSE напрямую — Supabase MCP работает **без npx mcp-remote**
- Можно также через Web UI: `http://127.0.0.1:18789` → вкладка Config

**Если твоего агента нет в списке** — погугли: `"<название агента> MCP config file location"` или поищи в документации агента. Конфиг обычно лежит в домашней директории пользователя или в настройках IDE.

---

## Шаг 2: Получение API ключа

Спроси пользователя:

> У тебя уже есть API ключ от @ak_private_MCP_bot? Если нет — напиши боту @ak_private_MCP_bot в Telegram свой email, он выдаст ключ и готовые конфиги.

- Для регистрации нужно отправить боту свой email
- Ключ начинается с `prv-...`
- Один ключ подходит ко ВСЕМ MCP серверам (n8n, Supabase и будущим)
- Если пользователь уже получал ключ раньше — новый получать НЕ нужно

---

## Шаг 3: Определи что подключаем

Спроси пользователя какие MCP серверы нужны:

### N8N MCP Server
Нужны от пользователя:
- API ключ от бота (`prv-...`) — уже есть с шага 2
- Домен n8n **БЕЗ https://** (например: `n8n.example.ru`)
- API ключ n8n (обычно начинается с `eyJ...`)

### Supabase MCP Server
Нужны от пользователя:
- API ключ от бота (`prv-...`) — уже есть с шага 2
- Данные Supabase проекта (см. ниже как их получить)

---

## Шаг 4: Подключение

### Формат конфига зависит от агента

Есть ТРИ основных формата подключения MCP серверов:

---

### Формат A: command + args (через npx mcp-remote)
**Используется в:** Claude Desktop, Claude Code, агенты которые не поддерживают SSE напрямую

Это **универсальный** способ. Работает везде где есть Node.js.

#### N8N MCP — формат A:
```json
{
  "mcpServers": {
    "n8n-mcp-server": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://n8n-mcp.ak-devs.ru/{API_КЛЮЧ}/{ДОМЕН_N8N}/{API_КЛЮЧ_N8N}/sse"
      ]
    }
  }
}
```

#### Supabase MCP — формат A:
```json
{
  "mcpServers": {
    "supabase-mcp": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://sup-mcp.ak-devs.ru/sse",
        "--header",
        "x-api-key:{API_КЛЮЧ}",
        "--header",
        "x-supabase-url:{SUPABASE_URL}",
        "--header",
        "x-supabase-anon-key:{SUPABASE_ANON_KEY}",
        "--header",
        "x-supabase-service-key:{SUPABASE_SERVICE_KEY}",
        "--header",
        "x-db-host:{DB_HOST}",
        "--header",
        "x-db-port:{DB_PORT}",
        "--header",
        "x-db-user:{DB_USER}",
        "--header",
        "x-db-password:{DB_PASSWORD}",
        "--header",
        "x-db-name:{DB_NAME}",
        "--header",
        "x-jwt-secret:{JWT_SECRET}"
      ],
      "env": {
        "MCP_API_KEY": "{API_КЛЮЧ}",
        "SUPABASE_URL": "",
        "SUPABASE_ANON_KEY": "",
        "SUPABASE_SERVICE_KEY": "",
        "DB_HOST": "",
        "DB_PORT": "",
        "DB_USER": "",
        "DB_PASSWORD": "",
        "DB_NAME": "",
        "JWT_SECRET": ""
      }
    }
  }
}
```

---

### Формат B: url (прямое SSE подключение)
**Используется в:** Cursor, Kilo Code, Windsurf, и другие агенты которые поддерживают SSE напрямую

Этот формат **проще** и **не требует npx/Node.js**. Используй его если агент поддерживает.

#### N8N MCP — формат B:
```json
{
  "mcpServers": {
    "n8n-mcp-server": {
      "url": "https://n8n-mcp.ak-devs.ru/{API_КЛЮЧ}/{ДОМЕН_N8N}/{API_КЛЮЧ_N8N}/sse"
    }
  }
}
```

#### Supabase MCP — формат B:
> На данный момент Supabase MCP требует передачу headers, поэтому формат B для него НЕ подходит — используй формат A.

---

### Формат C: YAML (для LibreChat / Леший selfhosted)

#### N8N MCP — формат C:
```yaml
mcpServers:
  n8n-mcp-server:
    type: sse
    url: "https://n8n-mcp.ak-devs.ru/{API_КЛЮЧ}/{ДОМЕН_N8N}/{API_КЛЮЧ_N8N}/sse"
```

---

### Какой формат выбрать:

```
Cursor, Kilo Code, Windsurf     → Формат B (url) — предпочтительно
Claude Desktop                   → Формат A (command + args)
Claude Code (CLI / VS Code)      → Формат A или команда `claude mcp add`
OpenClaw                         → Свой формат (см. раздел OpenClaw), поддерживает SSE с headers
LibreChat / Леший                → Формат C (YAML)
Другой агент                     → Попробуй формат B, если не работает → формат A
Windows + зависания npx          → Формат B если агент поддерживает
```

### Особенности Claude Code:

Для Claude Code **предпочтительно** использовать CLI команду вместо ручного редактирования файла:

```bash
# N8N MCP — через CLI команду
claude mcp add n8n-mcp-server --scope user -- npx mcp-remote "https://n8n-mcp.ak-devs.ru/{API_КЛЮЧ}/{ДОМЕН_N8N}/{API_КЛЮЧ_N8N}/sse"
```

Для Supabase MCP с headers проще через `add-json`:
```bash
claude mcp add-json supabase-mcp --scope user '{
  "command": "npx",
  "args": [
    "mcp-remote",
    "https://sup-mcp.ak-devs.ru/sse",
    "--header", "x-api-key:{API_КЛЮЧ}",
    "--header", "x-supabase-url:{SUPABASE_URL}",
    "--header", "x-supabase-anon-key:{SUPABASE_ANON_KEY}",
    "--header", "x-supabase-service-key:{SUPABASE_SERVICE_KEY}",
    "--header", "x-db-host:{DB_HOST}",
    "--header", "x-db-port:{DB_PORT}",
    "--header", "x-db-user:{DB_USER}",
    "--header", "x-db-password:{DB_PASSWORD}",
    "--header", "x-db-name:{DB_NAME}",
    "--header", "x-jwt-secret:{JWT_SECRET}"
  ]
}'
```

Если ты работаешь **внутри Claude Code** — можешь выполнить эти команды напрямую через терминал.

---

## Шаг 5: Как получить данные Supabase

Спроси пользователя: **облачная** (supabase.com) или **selfhosted** версия?

### Selfhosted версия (быстрый способ)

Попроси пользователя выполнить одну команду на сервере. Если у агента есть SSH доступ — выполни сам.

**Вариант 1 — у агента есть доступ к серверу (SSH):**
Запроси у пользователя: IP сервера, логин, пароль (или SSH ключ). Подключись и выполни команду ниже.

**Вариант 2 — нет доступа:**
Скажи пользователю: "Выполни эту команду в терминале на сервере с Supabase и скинь мне результат:"

```bash
cd /root/supabase/docker && source .env && SERVER_IP=$(hostname -I | awk '{print $1}') && echo -e "x-supabase-url: $API_EXTERNAL_URL" && echo -e "x-supabase-anon-key: $ANON_KEY" && echo -e "x-supabase-service-key: $SERVICE_ROLE_KEY" && echo -e "x-db-host: $SERVER_IP" && echo -e "x-db-port: $POSTGRES_PORT" && echo -e "x-db-user: postgres.$POOLER_TENANT_ID" && echo -e "x-db-password: $POSTGRES_PASSWORD" && echo -e "x-db-name: $POSTGRES_DB" && echo -e "x-jwt-secret: $JWT_SECRET"
```

Команда выведет все 9 параметров разом. Подставь их в конфиг.

### Облачная версия (supabase.com)

Пошагово проведи пользователя:

**1. Project URL и API ключи:**
- Заходим в панель Supabase → выбираем проект
- **Project Settings** → **API**
- Копируем **Project URL** → это `SUPABASE_URL`
- Ниже в **API Keys**: копируем **anon public** → `SUPABASE_ANON_KEY`
- Копируем **service_role** (нажать показать) → `SUPABASE_SERVICE_KEY`

**2. JWT Secret:**
- Там же слева: **JWT Settings**
- Копируем **Legacy JWT Secret** → `JWT_SECRET`

**3. Данные подключения к БД:**
- Идём в раздел **Connect** сверху страницы
- Выбираем метод **Transaction Pooler**
- Нажимаем **View Parameters**
- Копируем: `host` → `DB_HOST`, `port` → `DB_PORT`, `database` → `DB_NAME`, `user` → `DB_USER`

**4. Пароль БД:**
- **Project Settings** → **Database**
- Если пользователь помнит пароль — используем его
- Если забыл — нажать **Reset Password**, скопировать новый → `DB_PASSWORD`

---

## Шаг 6: Вставка конфига

### КРИТИЧЕСКИ ВАЖНО:
- **НЕ удаляй** существующие MCP серверы и настройки в конфиге
- **Добавляй** новые серверы РЯДОМ с существующими
- **Следи за запятыми** — JSON не прощает лишних/отсутствующих запятых
- Если в конфиге уже есть `mcpServers` — добавь внутрь него, не создавай второй блок

### Для Claude Code:
- Лучше используй `claude mcp add` / `claude mcp add-json` — он сам всё правильно запишет
- Если редактируешь вручную — файл `~/.claude.json`, секция `mcpServers`

### Для Claude Desktop:
- Файл `claude_desktop_config.json`, секция `mcpServers`
- Структура: `{ "mcpServers": { ... } }` на верхнем уровне

### После вставки:
1. **Перезапусти агент/IDE** (закрой и открой)
2. Для Kilo Code: Settings → Agent Behavior → включи новые MCP серверы
3. Для Claude Code VS Code: набери `/mcp` в чате чтобы проверить статус
4. Проверь работу (см. Шаг 7)

---

## Шаг 7: Проверка

После перезапуска выполни тестовые вызовы:

- **n8n**: вызови `list_workflows` — должен вернуть список воркфлоу
- **supabase**: вызови `show_tables` — должен вернуть список таблиц

Если работает — скажи пользователю что всё ок.

---

## Troubleshooting: Типичные проблемы и решения

### "npx: command not found"
→ Node.js не установлен. Установи сам (см. Шаг 0).

### "mcp-remote: not found" или "ERR_MODULE_NOT_FOUND"
→ Выполни: `npx mcp-remote@latest --help` чтобы скачать/обновить пакет.

### MCP сервер не отвечает / timeout
**Сначала проверь интернет!** Это в 80% случаев проблема соединения пользователя, а НЕ MCP сервера.
- Проверь: `curl -s https://n8n-mcp.ak-devs.ru/health`
- Если curl не отвечает — проблема с интернетом или VPN/прокси у пользователя
- Если curl отвечает но агент не подключается — попробуй другой формат подключения (B вместо A или наоборот)

### "ECONNREFUSED" или "ENOTFOUND"
→ Проблема DNS или файрвол. Проверь что домены `n8n-mcp.ak-devs.ru` и `sup-mcp.ak-devs.ru` резолвятся:
```bash
nslookup n8n-mcp.ak-devs.ru
```

### JSON parse error после редактирования конфига
→ Ты скорее всего сломал JSON. Проверь:
- Нет ли лишних/отсутствующих запятых
- Все скобки закрыты
- Нет trailing comma перед `}`
- Валидация: `cat конфиг.json | python3 -m json.tool`

### Агент пишет "MCP server error" но раньше работало
→ В 90% случаев это НЕ проблема MCP сервера. Проверь по порядку:
1. Интернет-соединение
2. VPN/прокси (попробуй отключить)
3. Перезагрузи агент/IDE
4. Перезагрузи компьютер (да, серьёзно — помогает чаще чем кажется)

### На Windows npx зависает или не работает
→ Попробуй формат B (прямой URL) вместо формата A. Если агент поддерживает SSE напрямую — npx вообще не нужен.
→ Альтернатива: используй `claude mcp add` в Claude Code — он корректно работает на Windows.

### Kilo Code: MCP сервер добавлен но не появляется
→ Settings → Agent Behavior → найди MCP сервер → включи галочку. Перезапусти VS Code.
→ Если всё равно нет — проверь конфиг `~/.config/kilo/kilo.jsonc`:
  - Секция должна называться `"mcp"` (НЕ `"mcpServers"`)
  - У каждого сервера должен быть `"type": "local"` и `"enabled": true`
  - `"command"` должен быть массивом `[...]`, а не строкой
  - `"mcp"` должен быть на верхнем уровне, НЕ внутри `"agent"` или `"permission"`

### Kilo Code: агент добавил MCP внутрь agent или permission
→ Это частая ошибка агента Kilo Code. Открой `~/.config/kilo/kilo.jsonc` и вручную проверь структуру:
```jsonc
{
  "agent": { ... },      // отдельная секция
  "permission": { ... }, // отдельная секция
  "mcp": { ... }         // отдельная секция НА ВЕРХНЕМ УРОВНЕ
}
```
Если `mcp` оказался вложен внутрь другой секции — вынеси его на верхний уровень.

### Claude Code: `/mcp` показывает сервер как disconnected
→ Попробуй: `claude mcp remove <имя>` и добавь заново. Проверь что `npx mcp-remote` доступен.

---

## Заметки для агента

- Ты всё делаешь сам: устанавливаешь зависимости, редактируешь конфиги, проверяешь работу
- Не проси пользователя делать то, что можешь сделать сам
- Если не знаешь где конфиг у конкретного агента — загугли, не гадай
- При ошибках — сначала диагностируй (интернет, Node.js, JSON), потом чини
- Не удаляй чужие настройки из конфигов
- Один API ключ работает для всех MCP серверов
- Для Claude Code предпочитай CLI команды (`claude mcp add`) вместо ручного редактирования JSON
