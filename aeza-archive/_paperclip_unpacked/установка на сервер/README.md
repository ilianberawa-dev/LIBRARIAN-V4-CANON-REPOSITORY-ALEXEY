# Paperclip AI — установка на VPS

Панель управления AI-агентами. Запускается из исходников, раздаёт UI через Caddy (HTTPS).

---

## Требования

- Ubuntu 22.04+ / Debian
- Node.js **v22+** (через nvm: `nvm install 22 && nvm use 22`)
- sudo без пароля: `echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER`
- DNS A-запись домена уже смотрит на IP сервера (Caddy не получит TLS без этого)

---

## Подготовка: домен и DNS

Скрипт автоматически получает HTTPS-сертификат через Let's Encrypt. Для этого **до запуска скрипта** нужно настроить DNS.

Пример: хочешь открывать Paperclip по адресу `mc.example.com`.

### Вариант А — Cloudflare

1. Войди в [dash.cloudflare.com](https://dash.cloudflare.com) → выбери домен
2. **DNS** → **Records** → **Add record**:
   - Type: `A`
   - Name: `mc`
   - IPv4 address: IP твоего VPS
   - Proxy status: **DNS only** (серое облачко, НЕ оранжевое — иначе Let's Encrypt не получит сертификат)
3. Save

### Вариант Б — любой другой регистратор (Namecheap, REG.RU, Beget и др.)

1. Войди в панель управления доменом → раздел **DNS** / **Управление DNS**
2. Добавь запись:
   - Тип: `A`
   - Хост / Субдомен: `mc`
   - Значение / IP: IP твоего VPS
   - TTL: 300 (или минимальный)
3. Сохрани

---

Подожди пока DNS применится. На cloudflare несколько минут, у регистраторов может быть до 24ч. Проверь:
```bash
ping mc.example.com
# должен отвечать IP твоего VPS
```

---

## Загрузка скрипта на сервер (через Termius)

1. Открой **Termius** → подключись к серверу
2. Нажми **SFTP** (иконка папки в боковом меню)
3. В правой панели (сервер) перейди в домашнюю директорию (`/home/openclaw/`)
4. Перетащи файл `install_paperclip.sh` из локальной папки в правую панель
5. В терминале Termius:
```bash
chmod +x install_paperclip.sh
bash install_paperclip.sh
```
Скрипт спросит домен — введи тот что настроил в DNS.

Или передай домен переменной сразу:
```bash
PC_DOMAIN=app.example.com bash install_paperclip.sh
```

---

## Установка

```bash
PC_DOMAIN=app.example.com bash install_paperclip.sh

# или интерактивно (спросит домен):
bash install_paperclip.sh
```

Скрипт делает всё сам:
1. Устанавливает зависимости (pnpm, g++, Caddy, Claude Code CLI)
2. Клонирует репо `paperclipai/paperclip`
3. `pnpm install` + **`pnpm build`** (без билда Vite dev блокирует внешние хосты)
4. `paperclipai onboard --yes` — создаёт БД, секреты, конфиг
5. Прописывает домен в config.json (`host=0.0.0.0`, `allowedHostnames`, `publicBaseUrl`)
6. Создаёт systemd сервис с `PAPERCLIP_UI_DEV_MIDDLEWARE=false`
7. Настраивает Caddy → `localhost:3100` + Let's Encrypt автоматом

---

## Onboarding: что выбирать

Во время `paperclipai onboard` скрипт остановится и покажет интерактивное меню.

**Выбери:** `Advanced setup`

Дальше жми **Enter** на всех пунктах, кроме четырёх:

| Пункт | Выбери |
|-------|--------|
| Deployment mode | `Authenticated` |
| Exposure profile | `Public internet` |
| Public base URL | `https://mc.example.com` ← твой домен с https:// |
| Start Paperclip now? | `No` |

Остальное — дефолт, просто Enter.

---

## После установки: авторизация Claude Code

Paperclip запускает агентов через локальный Claude Code. Без авторизации агенты не работают.

**1. Запусти Claude Code и войди:**
```bash
claude
```
Внутри claude выполни:
```
/login
```
Нужна подписка **Pro или выше**.

**2. Проверь что claude виден из systemd:**
```bash
sudo -u $USER /usr/local/bin/claude --version
```

**3. Перезапусти Paperclip:**
```bash
sudo systemctl restart paperclip
```

> Скрипт автоматически создаёт симлинк `~/.local/bin/claude → /usr/local/bin/claude`,
> потому что systemd использует урезанный PATH без `~/.local/bin`.

---

## Получить ссылку для регистрации

Invite URL выводится один раз при установке. Если потерял — сгенерируй заново:

```bash
cd ~/paperclip && pnpm paperclipai auth bootstrap-ceo --force
```

Выдаст одноразовую ссылку вида `https://домен/invite/pcp_bootstrap_...` — перейди по ней и создай аккаунт.

---

## После регистрации: закрыть регу

После того как создал свой аккаунт — закрой регистрацию:

```bash
python3 -c "
import json
path = '$HOME/.paperclip/instances/default/config.json'
with open(path) as f: d = json.load(f)
d['auth']['disableSignUp'] = True
with open(path, 'w') as f: json.dump(d, f, indent=2)
print('disableSignUp = True')
"
sudo systemctl restart paperclip
```

---

## Разрешить агенту выполнять команды без подтверждений

Нужно создать рабочую папку и прописать её в настройках агента:

**1. Создай папку:**
```bash
mkdir ~/paperclip_projects
```
Путь: `/home/openclaw/paperclip_projects`

**2. Создай Project в Paperclip UI:**

Paperclip UI → **Projects** → New Project → укажи путь:
```
/home/openclaw/paperclip_projects
```

**3. Укажи Project в настройках агента:**

Agent → Configuration → поле **Project** → выбери созданный проект.

После этого агент получает рабочую директорию и перестаёт запрашивать разрешения.

> `~/.claude/settings.json` с `permissions` блоком **не работает** для агентов Paperclip —
> Paperclip запускает claude через `spawn()` минуя интерактивный режим.

---

## Подключение OpenClaw к Paperclip

Paperclip не нужно вручную вписывать URL и токен. Делается через инвайт:

1. Открой Paperclip → **Settings → Invites**
2. Нажми **Generate an OpenClaw agent invite snippet**
3. Скопируй сгенерированный сниппет
4. Отправь этот сниппет агенту **в OpenClaw** (в чат или как задачу)
5. Агент сам зарегистрируется в Paperclip

### Если агент получил ошибку `pairing required`

```
pairing required. Approve the pending device in OpenClaw
(openclaw_gateway_pairing_required)
```

Paperclip подключился к OpenClaw gateway, но устройство ещё не одобрено.

**Что делать:** напиши агенту в Telegram — он видит pending pairing и одобрит.
После одобрения нажми **Retry** в Paperclip на упавшем таске.

### Тест после подключения

Попроси агента через Telegram поставить задачу CEO в Paperclip, а CEO — поставить задачу обратно агенту. Если обмен прошёл — всё работает.

---

## Известные нюансы

### Vite dev-режим блокирует внешние хосты
`pnpm paperclipai run` из исходников автоматически включает `PAPERCLIP_UI_DEV_MIDDLEWARE=true`,
что запускает Vite dev-сервер. Он блокирует все запросы с хостом кроме localhost.

**Фикс:** переменная `PAPERCLIP_UI_DEV_MIDDLEWARE=false` в systemd-сервисе + собранный `ui/dist` (`pnpm build`).

### Paperclip слушает на внешнем IP, не localhost
По умолчанию `server.host` в конфиге = IP сервера, а не `0.0.0.0` или `127.0.0.1`.
Caddy не может достучаться до `localhost:3100` в таком случае.

**Фикс:** скрипт прописывает `host: "0.0.0.0"` — тогда Caddy соединяется через `localhost:3100`.

### Claude не виден в systemd
`claude` устанавливается в `~/.local/bin/` которого нет в PATH у systemd.

**Фикс:** скрипт создаёт симлинк `sudo ln -sf ~/.local/bin/claude /usr/local/bin/claude`.

### Caddy: permission denied на /var/lib/caddy
На свежих серверах директория принадлежит root.

**Фикс:** `sudo chown -R caddy:caddy /var/lib/caddy`

### Зависший postgres при перезапуске
Если paperclip упал неожиданно, встроенный postgres остаётся висеть на порту 54329.
При следующем старте paperclip пишет `WARN: Embedded PostgreSQL already running; reusing`.
Обычно это нормально — он переиспользует процесс.

Если же `CONNECT_TIMEOUT`:
```bash
kill $(ss -tlnp | grep :54329 | grep -oP 'pid=\K[0-9]+')
sudo systemctl restart paperclip
```

---

## Управление

```bash
# Статус
sudo systemctl status paperclip caddy

# Логи в реальном времени
journalctl -u paperclip -f

# Перезапуск
sudo systemctl restart paperclip

# Обновление до новой версии
cd ~/paperclip
git pull
pnpm install
pnpm build
sudo systemctl restart paperclip
```

---

## Удаление

```bash
sudo systemctl stop paperclip caddy
sudo systemctl disable paperclip caddy
sudo rm -f /etc/systemd/system/paperclip.service /etc/caddy/Caddyfile
sudo systemctl daemon-reload
rm -rf ~/paperclip ~/.paperclip
```

---

## Файлы

| Путь | Что |
|------|-----|
| `~/.paperclip/instances/default/config.json` | Основной конфиг |
| `~/.paperclip/instances/default/db/` | PostgreSQL данные |
| `~/.paperclip/instances/default/data/storage/` | Файлы агентов |
| `~/.paperclip/instances/default/logs/` | Логи сервера |
| `/etc/caddy/Caddyfile` | Caddy конфиг |
| `/etc/systemd/system/paperclip.service` | Systemd юнит |
