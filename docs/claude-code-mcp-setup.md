# Локальный Claude Code → MCP (Supabase + LightRAG)

Этот документ описывает, как на ноутбуке Ильи (Windows 11) подключить Claude Code к двум MCP-серверам, живущим внутри OpenClaw на сервере Aeza. Всё читается через SSH — **секреты на диск ноутбука не пишутся**.

## Что это даёт

После настройки в Claude Code можно задавать вопросы в обычном чате:
- *«покажи все объявления в Чангу за последний день»* → Claude ходит в Supabase через MCP
- *«что обычно стоит вилла в Семиньяке»* → Claude ходит в LightRAG через MCP
- *«сколько сейчас активных объектов в базе»* → Supabase MCP `queryDatabase`

## Требования на ноутбук

| Компонент | Проверка | Как поставить |
|---|---|---|
| Windows 11 OpenSSH | `ssh -V` в PowerShell должен показать `OpenSSH_for_Windows_...` | Обычно уже есть. Иначе: `Settings → Apps → Optional features → OpenSSH Client` |
| Node.js LTS (≥ 20) | `node --version` | https://nodejs.org/ — LTS installer |
| Claude Code | `claude --version` | https://docs.anthropic.com/en/docs/claude-code/setup |

## Одноразовая настройка (~10 минут)

### 1. Создать `.mcp.json` в корне локального проекта

Файл: `C:\Users\97152\Новая папка\realty-portal\.mcp.json`

```json
{
  "mcpServers": {
    "realty-supabase": {
      "command": "npx",
      "args": ["-y", "--package=supabase-mcp@1.5.0", "supabase-mcp-claude"],
      "env": {
        "SUPABASE_URL": "http://localhost:8000",
        "SUPABASE_ANON_KEY": "${ANON_KEY}",
        "SUPABASE_SERVICE_ROLE_KEY": "${SERVICE_ROLE_KEY}",
        "MCP_API_KEY": "${MCP_API_KEY}"
      }
    },
    "realty-lightrag": {
      "command": "npx",
      "args": ["-y", "lightrag-mcp@1.0.11"],
      "env": {
        "LIGHTRAG_BASE_URL": "http://localhost:9621",
        "LIGHTRAG_API_KEY": "${LIGHTRAG_API_KEY}"
      }
    }
  }
}
```

**Версии запинены** (`1.5.0` и `1.0.11`), чтобы npm-обновления не ломали MCP.

### 2. Создать PowerShell-скрипт одной сессии

Файл: `C:\Users\97152\Новая папка\realty-portal\scripts\claude-session.ps1`

```powershell
# Один запуск = одна сессия Claude Code с подключенными MCP
# Не оставляет секретов на диске.

$ErrorActionPreference = "Stop"
$server = "root@193.233.128.21"

Write-Host "→ подтягиваю секреты с сервера (по SSH)..."
$envBlock = ssh $server 'grep -E "^(ANON_KEY|SERVICE_ROLE_KEY|LIGHTRAG_API_KEY|MCP_API_KEY)=" /opt/realty-portal/.env'
if (-not $envBlock) { throw "не удалось получить .env с сервера" }

foreach ($line in ($envBlock -split "`n")) {
    if ($line -match '^([A-Z_]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

Write-Host "→ открываю SSH-tunnel (8000=Supabase, 9621=LightRAG)..."
$tunnel = Start-Process ssh -ArgumentList "-N", "-L", "8000:127.0.0.1:8000", "-L", "9621:127.0.0.1:9621", $server -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2

try {
    Write-Host "→ запускаю Claude Code (Ctrl-C или /quit чтобы выйти)..."
    Set-Location "C:\Users\97152\Новая папка\realty-portal"
    claude
}
finally {
    Write-Host "→ закрываю tunnel..."
    if ($tunnel -and -not $tunnel.HasExited) { Stop-Process -Id $tunnel.Id -Force }

    # Очистка env vars процесса — не оставляем в памяти shell
    "ANON_KEY","SERVICE_ROLE_KEY","LIGHTRAG_API_KEY","MCP_API_KEY" | ForEach-Object {
        [Environment]::SetEnvironmentVariable($_, $null, "Process")
    }
}
```

**Что делает скрипт:**
1. SSH-подключается на сервер, читает `/opt/realty-portal/.env`, парсит 4 нужные переменные в env текущего процесса PowerShell
2. Запускает SSH-туннель в фоне (`127.0.0.1:8000` → Supabase Kong, `127.0.0.1:9621` → LightRAG)
3. Запускает `claude` — он читает `.mcp.json`, подставляет `${ANON_KEY}` и др. из env процесса, спаунит `npx` подпроцессы для MCP
4. При выходе из Claude — убивает туннель и чистит env-переменные

**Секреты никогда не пишутся на диск.** Они живут только в памяти процесса PowerShell, пока Claude Code запущен.

### 3. Проверить что SSH ходит без пароля (удобство)

Чтобы скрипт не спрашивал пароль трижды (grep + tunnel + в claude-session), одноразово:

```powershell
# Создать ключ (если ещё нет)
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519"

# Залить публичный ключ на сервер (введёт пароль один раз)
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" | ssh root@193.233.128.21 "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

После этого SSH будет ходить по ключу, пароль больше не спрашивается.

## Ежедневное использование

```powershell
cd "C:\Users\97152\Новая папка\realty-portal"
.\scripts\claude-session.ps1
```

Внутри Claude Code можно спросить, например:
- `покажи все записи из таблицы sources`
- `вставь в raw_listings тестовый объект с source_name='rumah123_bali'`
- `сколько документов в LightRAG?`

Claude сам выберет нужный MCP-tool и покажет результат.

## Проверочный тест (первый запуск)

После старта `.\scripts\claude-session.ps1` и появления приглашения Claude, введи:

```
Используя realty-supabase MCP, вызови tool listTables и покажи список таблиц.
```

Ожидаемый ответ — 4 таблицы канона: `raw_listings`, `properties`, `market_snapshots`, `sources`.

Затем:

```
Используя realty-lightrag MCP, вызови tool get_document_status_counts.
```

Ожидаемый ответ — JSON со счётчиками (на старте все нули, пока мы не загрузили knowledge в Этапе 3).

Если обе команды отработали — MCP настроены правильно.

## Что делать при проблемах

| Симптом | Причина | Решение |
|---|---|---|
| `Missing required environment variables` в логах MCP | env vars не пришли в процесс Claude | проверь вывод `$env:ANON_KEY` в PowerShell — не пусто? |
| `connect ECONNREFUSED 127.0.0.1:8000` | SSH-tunnel не поднялся или упал | проверь `netstat -ano | Select-String 8000` — порт слушает? |
| `Error: supabaseUrl is required` | `.mcp.json` не подставил переменную | убедись что `$env:ANON_KEY` задано ДО запуска `claude` |
| `ENOTFOUND registry.npmjs.org` | нет интернета | MCP подтягивает npm-пакеты при первом вызове |
| `Permission denied (publickey)` | не настроен SSH-ключ | пройди шаг 3 выше |

## Что НЕ делать

- ❌ Не копировать `.env` с сервера на ноутбук целиком
- ❌ Не прописывать значения секретов в `.mcp.json` напрямую (только `${VAR}` синтаксис)
- ❌ Не коммитить `.mcp.json` в публичный репозиторий если добавишь туда реальные токены — в нашем виде `${VAR}` безопасно

## Связанные файлы

- [secrets-policy.md](secrets-policy.md) — правила единого сейфа секретов
- [architecture.md](architecture.md) — канон Алексея (раздел «Подключение MCP»)
- [server_inventory.md](server_inventory.md) — текущее состояние сервера
- `openclaw/docker-compose.yml` — как OpenClaw сам использует те же MCP внутри сервера (другой env, через `$VAR` из контейнера)
