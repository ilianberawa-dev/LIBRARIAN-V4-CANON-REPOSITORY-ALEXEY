# Server inventory — Aeza VIEs-2 (grotesquecoffee.aeza.network)

**Первичный снимок:** 2026-04-19 04:53 UTC (read-only SSH через paramiko).
**Cleanup brain:** 2026-04-19 05:01 UTC — проект brain полностью снесён по запросу пользователя.
**Назначение файла:** реестр «что было на сервере ДО нас» и «что добавили мы». Обновляется после каждого значимого изменения.

---

## 0. СТАТУС НА 2026-04-19 05:20 UTC — СЕРВЕР ПОЛНОСТЬЮ ЧИСТЫЙ

**3 фазы сноса выполнены:**

### Фаза 1 (05:01 UTC) — основной снос brain
- ✅ Контейнеры brain_* (4 шт.) + тома brain_*_data (3 шт.) + сеть brain_brain_net + образы brain-brain/brain-watchdog/ollama/postgres:16-alpine (~12.6 GB)
- ✅ `/opt/brain/`, `/home/user/HYBRID-MEMORY-HUMAN-IN-THE-LOOP/`, `/root/.ssh/github_brain*`, `/root/.ssh/config`

### Фаза 2 (05:17 UTC) — residue: Claude Code cache, bash_history, Docker cache
- ✅ `/root/.env` (TELEGRAM_ADMIN_ID), `/root/CLAUDE_MEMORY.md`, `/root/.bash_history`, `/root/.lesshst`, `/root/.claude.json`
- ✅ `/root/.claude/{projects,file-history,history.jsonl,sessions,backups,cache,shell-snapshots,session-env,policy-limits.json}`
- ✅ TG-плагин `/root/.claude/plugins/.../external_plugins/telegram/`
- ✅ Docker builder prune -af: 1.175 GB освобождено
- ✅ Docker system prune -af --volumes
- ✅ journalctl --vacuum-time=1s: 316.7 MB архивных журналов

### Фаза 3 (05:20 UTC) — finish polish: логи, buildx refs, MOTD-garbage
- ✅ 3 MOTD-файла-огрызка в /root/ удалены
- ✅ `/root/.docker/buildx/` с 16 orphaned refs — удалены
- ✅ `journalctl --rotate && --vacuum-time=1s` — освобождено ещё 24.4 MB
- ✅ Truncated: /var/log/{syslog,syslog.1,auth.log,auth.log.1,daemon.log,daemon.log.1,kern.log,kern.log.1,user.log,user.log.1}
- ✅ `/var/log/auth.log.2.gz` содержал brain — удалён

### Финальная проверка (2026-04-19 05:20 UTC) — все тесты пройдены

| Проверка | Результат |
|---|---|
| `grep -rIlE 'brain\|paperclip\|ollama' /etc /opt /root /home /var/log /var/lib/docker` | **CLEAN** (пусто) |
| `grep -rIlE 'ghp_.\|sk-.\|bot[0-9]+:.\|[0-9]+:[A-Za-z0-9_-]{35}'` по всему FS | **CLEAN** (пусто) |
| `journalctl | grep brain` | **CLEAN** |
| `docker ps -a / volume ls / network ls / images` | **0/0/0 (default)** |
| `ps aux | grep brain/paperclip/ollama` | **CLEAN** |
| `ss -tlnp` (внешние порты) | только SSH 22 + systemd-resolve (localhost 53) |

**🚨 Остаётся на стороне пользователя:** revoke GitHub PAT `ghp_AxXmm...` в GitHub UI.

**Ресурсы после полной очистки:**
- RAM: 522 MiB used, **3.3 GB available**
- Disk: 4.8 GB used (9%), **54 GB free**
- Docker: 0 везде (чистое состояние)
- /opt/: только `containerd/` (системный)
- /root/: только стандартные дотфайлы (.bashrc, .cache/, .claude/{plans,plugins,settings.local.json}, .config/, .docker/, .local/, .npm/, .profile, .ssh/{known_hosts,known_hosts.old})
- /home/user/: пусто
- /srv/: пусто

**Итого освобождено за 3 фазы:** ~13.5 GB диска, ~300 MB RAM.

---

---

## 1. Идентификация сервера

| Параметр | Значение |
|---|---|
| Hostname | `grotesquecoffee.aeza.network` |
| IP (public ens3) | `193.233.128.21` |
| Docker bridges | `172.17.0.1`, `172.18.0.1` (br-589a940004a7 — внутренняя сеть brain) |
| OS | Ubuntu 24.04.4 LTS (Noble Numbat), Linux 6.8.0-107 |
| CPU | 2 cores (x86_64) |
| RAM | 3.8 GiB total, 3.0 GiB available, 813 MiB used, 512 MiB swap |
| Disk | 59 GB root, 17 GB used (29%), 42 GB free |
| Uptime | 5 дней 19 часов |

---

## 2. Было до нас: проект `brain/` (СНЕСЁН 2026-04-19 05:01 UTC)

**Путь:** `/opt/brain/` (Python-скрипты + docker-compose + .git).

**Состав (Python scripts):**
- `paperclip.py` (20 KB) — ядро Paperclip-оркестратора
- `dispatcher.py` (27 KB) — диспетчер задач
- `scheduler.py`, `token_economy.py`, `watchdog.py`
- `telegram_bot.py` — интерфейс в TG
- `main.py`, `config.py`, `db.py`, `healthcheck.py`, `deploy.sh`
- `schema.sql`, `init.sql`, `requirements.txt`
- `agents/` папка
- `.git`, `.env`, `.env.example`

**Docker-ресурсы brain:**

| Контейнер | Образ | Порты | Статус |
|---|---|---|---|
| `brain_app` | `brain-brain` | — | Up 4 days |
| `brain_watchdog` | `brain-watchdog` | — | **Restarting (crash-loop)** |
| `brain_postgres` | `postgres:16-alpine` | 5432/tcp **internal only** | Up 5 days (healthy) |
| `brain_ollama` | `ollama/ollama:latest` | 11434/tcp **internal only** | Up 5 days (**unhealthy**) |

Тома: `brain_brain_logs`, `brain_ollama_data`, `brain_postgres_data`.
Сеть: `brain_brain_net` (bridge).

**Образы (занимают диск):**
- `ollama/ollama:latest` — 9.89 GB (!)
- `brain-brain:latest` — 1.17 GB
- `brain-watchdog:latest` — 1.17 GB
- `postgres:16-alpine` — 395 MB
- **Итого brain-образы: ~12.6 GB**

**Важно для нашей работы:**
- ❗ Ни один brain-контейнер **не биндит порты на host** (`docker port` пусто для всех). Всё общение — внутри `brain_brain_net`.
- Это значит: мы можем использовать **любые** порты (в т.ч. 5432, 8000, 3000), конфликта на хосте не будет — у brain только docker-internal.
- `brain_watchdog` в restart-loop, `brain_ollama` unhealthy — проект явно не в рабочем состоянии.

**Примечание по канону:** `paperclip.py` + multi-agent оркестратор — это ровно то, что Алексей в `architecture.md` просит **НЕ использовать** («Paperclip... не нужно. Ты застрял именно потому что пытался их поднять»). Наш `realty-portal` — полностью отдельный подход по дорожной карте Алексея. Мы brain/ НЕ трогаем, решения по нему — ваши.

---

## 3. Системные сервисы (running)

Стандартный минимум Ubuntu + Docker. Никаких неожиданных демонов:
`containerd`, `cron`, `dbus`, `docker`, `getty@tty1`, `multipathd`, `polkit`, `qemu-guest-agent`, `rsyslog`, `ssh`, `systemd-journald/logind/resolved/timesyncd/udevd`, `udisks2`, `user@0`.

**Crontab root:** пусто.

---

## 4. Порты (bindings на 0.0.0.0)

| Порт | Процесс | Наружу? |
|---|---|---|
| 22 | sshd | ✅ публично |
| 53 (127.0.0.53 / 127.0.0.54) | systemd-resolve | только localhost |

**Никакие HTTP/HTTPS/DB-порты наружу не проброшены.** Весь `brain` живёт в Docker internal networks.

---

## 5. Firewall

`ufw` **не установлен.** Значит нет пакетного файрвола на уровне хоста. Защита — только от того что порты Docker-контейнеров не биндятся на 0.0.0.0. Если будем выставлять что-то наружу — обязательно ставим ufw или правим iptables аккуратно.

---

## 6. Инструменты (sudo-level)

| Инструмент | Есть? | Путь/версия |
|---|---|---|
| Docker | ✅ | v29.4.0 |
| Docker Compose (plugin) | ✅ | v5.1.1 |
| docker-compose (legacy) | ❌ | не требуется, используем plugin |
| git | ✅ | 2.43.0 |
| curl | ✅ | `/usr/bin/curl` |
| rsync | ✅ | `/usr/bin/rsync` (нужен для `migrate.sh`) |
| tar | ✅ | `/usr/bin/tar` (нужен для `backup.sh`) |
| python3 | ✅ | 3.12.3 |
| htop, vim, nano | ✅ | все есть |
| ufw | ❌ | не установлен |
| sshpass | ❌ | не требуется |

**Вывод:** всё необходимое для нашего стека (Docker + Compose + git + rsync + tar) уже есть. `apt install` не потребуется.

---

## 7. Содержимое `/opt/`, `/srv/`, `/home/`

- `/opt/brain/` — проект brain (см. выше)
- `/opt/containerd/` — системный Docker runtime
- `/srv/` — пусто
- `/home/user/` — пользователь `user` (не root), пустой профиль
- `/root/` — домашка root: `.claude/`, `.claude.json`, `CLAUDE_MEMORY.md`, `.env`, `.ssh/`, `.docker/`

**`/opt/realty-portal/` — свободно, создадим для себя.**

---

## 8. Изоляционная карта Realty Portal (наше будущее присутствие)

Всё с префиксом `realty_`, не пересекается с brain:

| Ресурс | Имя | Зачем |
|---|---|---|
| Корневая папка | `/opt/realty-portal/` | код, docker-compose, .env, backups |
| Docker project | `realty` (через `name:` в compose) | изолирует `docker compose ...` команды |
| Сеть | `realty_net` (bridge) | отдельная от `brain_brain_net`, `bridge`, `br-589a...` |
| Тома | `realty_supabase_db`, `realty_supabase_storage`, `realty_lightrag_data`, `realty_openclaw_data` | не пересекаются с `brain_*_data` |
| Контейнеры | `realty_supabase_*` (9+ шт), `realty_lightrag`, `realty_openclaw` | префикс `realty_`, уникально |
| Порты наружу на старте | **никакие** (только SSH 22) | доступ к Supabase Studio через SSH tunnel |

**Порты внутри Docker (докер-internal, без конфликта с brain):**
- Supabase Postgres: 5432 (внутри сети realty_net; brain_postgres тоже 5432 — в своей сети, они не видят друг друга)
- Supabase Kong: 8000
- Supabase Studio: 3000
- LightRAG API: 9621 (дефолт HKUDS/LightRAG)
- OpenClaw: TBD после ответа Алексея

**Если позже понадобится выставить наружу** (например, Supabase Studio для удалённого доступа) — делаем через SSH tunnel с локальной машины (`ssh -L 3000:localhost:3000 root@193.233.128.21`), а не через `0.0.0.0:3000`.

---

## 9. Ресурсы — предупреждения

**RAM 3.8 GB — тесно для полного стека:**
- brain сейчас: ~813 MiB (idle)
- Supabase self-hosted: ~2-2.5 GB (9 контейнеров)
- LightRAG: ~500 MB
- OpenClaw: ~500 MB (примерно)
- Итого если ВСЁ работает: ~4.3-4.5 GB → **мы упрёмся**

**Варианты (решение за пользователем):**
- (A) Остановить brain-контейнеры (`docker stop brain_app brain_watchdog brain_postgres brain_ollama`) — освободит ~800 MB, мы помещаемся в 4 GB.
- (B) Апгрейд Aeza RAM с 4 → 8 GB (слайдер в ЛК, ~€3/мес).
- (C) Удалить brain полностью — освободит ~12.6 GB диска + всю RAM. Канон Алексея рекомендует НЕ использовать Paperclip; если brain — остаток предыдущей попытки, его можно снести. Только по вашему решению.

**Дисковое пространство:** 42 GB свободно — хватит с запасом (наш стек ~5-8 GB).

---

## 10. Добавили мы (2026-04-19 05:40 UTC — после Этапа 1.1-1.5)

### Файлы
- `/opt/realty-portal/` — корень проекта, chmod 700 root:root
- `/opt/realty-portal/.env` — единый сейф секретов, chmod 600 root:root, 96 строк (сгенерирован на сервере, НИКУДА не экспортирован)
- `/opt/realty-portal/.env.example`, `README.md`, `.gitignore`, `docker-compose.yml`
- `/opt/realty-portal/docs/` — architecture.md (копия канона), secrets-policy.md, server_inventory.md (этот файл)
- `/opt/realty-portal/scripts/` — backup.sh / restore.sh / migrate.sh (chmod 755)
- `/opt/realty-portal/supabase/migrations/0001_init.sql` — наша миграция с 4 таблицами канона
- `/opt/realty-portal/supabase/upstream/` — sparse-клон https://github.com/supabase/supabase (только `docker/`, ~408K)
- `/opt/realty-portal/supabase/upstream/docker/docker-compose.override.yml` — наш override (project=realty_supabase, network=realty_net, ports=127.0.0.1)

### Docker-ресурсы
- **Сеть:** `realty_net` (bridge, external) — используется всеми сервисами стека
- **Проект:** `realty_supabase` (compose project name)
- **Контейнеры (13 шт., все Up, 11 healthy + 2 без healthcheck):**
  - supabase-db (postgres 15.8), supabase-kong, supabase-auth, supabase-rest (postgrest), supabase-realtime, supabase-storage, supabase-imgproxy, supabase-meta, supabase-edge-functions, supabase-analytics (logflare), supabase-vector, supabase-pooler (supavisor), supabase-studio
- **Тома Docker (named):** `realty_supabase_db_config` + bind-mounts из `supabase/upstream/docker/volumes/`
- **Образы (~11 GB):** 13 официальных Supabase образов

### Публичные порты (проверено `ss -tlnp`)
- **22** — SSH (как было)
- **53** — systemd-resolve (localhost)
- **127.0.0.1:8000** — Kong HTTP (доступ только через SSH-tunnel)
- **127.0.0.1:8443** — Kong HTTPS
- **127.0.0.1:5432** — PostgreSQL через supavisor
- **127.0.0.1:6543** — supavisor pooler

**Никакие Supabase-порты НЕ выставлены в интернет.** Доступ с ноутбука — через `ssh -L 8000:127.0.0.1:8000 -L 5432:127.0.0.1:5432 root@193.233.128.21`.

### SQL schema (таблицы канона)
- `public.raw_listings` — создана
- `public.properties` — создана, индексы district/type/price/is_active
- `public.market_snapshots` — создана
- `public.sources` — создана, 3 seed-записи (rumah123_bali active; olx_bali и balirealty inactive как заглушки)

### Ресурсы сервера
- RAM: 2.2 GB used / 1.7 GB available (из 3.8 GB total)
- Disk: 16 GB used / 43 GB free (из 59 GB)

### После Этапа 1.6 добавлено (LightRAG)
- **LightRAG** (`ghcr.io/hkuds/lightrag:latest`, 2.34 GB) — контейнер `realty_lightrag`, порт `127.0.0.1:9621`, тома `realty_lightrag_data` + `realty_lightrag_inputs`
- **LiteLLM proxy** (`ghcr.io/berriai/litellm:main-latest`) — `realty_litellm`, только internal (4000), транслирует OpenAI↔Anthropic для LightRAG
- **Ollama embedding-only** (`ollama/ollama:latest` + `all-minilm` 45 MB) — `realty_ollama`, только internal (11434), исключительно для 384-dim эмбеддингов, НЕ используется как LLM
- Том `realty_ollama_models` для кэша эмбеддинг-модели

### После Этапа 1.7 добавлено (OpenClaw)
- **OpenClaw self-hosted** (`ghcr.io/openclaw/openclaw:latest`, 3.54 GB) — `realty_openclaw`, порт `127.0.0.1:18789` (Control UI)
- Тома: `realty_openclaw_data` (конфиг `~/.openclaw/openclaw.json`) + `realty_openclaw_workspace` (скиллы и crons)
- Модель агента: `anthropic/claude-haiku-4-5-20251001` через ANTHROPIC_API_KEY из /opt/realty-portal/.env
- 52 bundled скилла доступно, свои Realty Portal скиллы добавятся в Этапе 2
- Секреты: `OPENCLAW_GATEWAY_TOKEN` в единый .env

### RAM upgrade
Aeza VIEs-2 обновлена 4 → 8 GB RAM (€3-4/мес). Остальные параметры без изменений (CPU 2, диск 60 GB). Текущее: 2.6 GB used / 5.2 GB available / 0 swap.

### После Этапа 1.8 добавлено (MCP интеграция) — 2026-04-19 ~07:40 UTC

**Итог:** оба MCP-сервера работают end-to-end stdio внутри OpenClaw, пакеты через npm.

| MCP | Пакет (pinned) | Tools | Status |
|---|---|---|---|
| **Supabase** | `supabase-mcp@1.5.0` (cappahccino, npm) | 5 CRUD: queryDatabase, insertData, updateData, deleteData, listTables | ✅ E2E подтверждён (queryDatabase на `sources` вернул 3 seed записи) |
| **LightRAG** | `lightrag-mcp@1.0.11` (d8corp, npm) | 26: insert_text, query_text (6 режимов), knowledge graph CRUD, system status | ✅ E2E подтверждён (initialize + tools/list) |

**Финальный `/home/node/.openclaw/openclaw.json` mcp-блок:**

```json
"supabase": {
  "command": "sh",
  "args": ["-c", "SUPABASE_URL=http://supabase-kong:8000 SUPABASE_ANON_KEY=$ANON_KEY SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY MCP_API_KEY=$MCP_API_KEY exec npx -y --package=supabase-mcp@1.5.0 supabase-mcp-claude"]
},
"lightrag": {
  "command": "sh",
  "args": ["-c", "LIGHTRAG_BASE_URL=http://realty_lightrag:9621 LIGHTRAG_API_KEY=$LIGHTRAG_API_KEY exec npx -y lightrag-mcp@1.0.11"]
}
```

**История поломок и решения (для будущих миграций):**
1. Прошлая сессия галлюцинировала имена пакетов (`@henkdz/selfhosted-supabase-mcp`, `daniel-lightrag-mcp`) — они существуют на GitHub, но **не на npm**. 404 при старте.
2. Правильные замены найдены: cappahccino CRUD MCP (npm) + d8corp LightRAG MCP (npm) — вариант «из коробки» по канону Алексея.
3. `npx -y supabase-mcp@<ver> supabase-mcp-claude` запускает **main HTTP binary** (неверный transport). Правильно: `npx -y --package=supabase-mcp@<ver> supabase-mcp-claude` — даёт stdio.
4. `cappahccino/supabase-mcp` требует `MCP_API_KEY` env var — добавлен в единый `/opt/realty-portal/.env` (random hex-64), также в `.env.example`.

### Единый .env — что добавлено в Этапе 1.8
- `MCP_API_KEY` — stdio auth для `supabase-mcp-claude`, random hex-64, chmod 600 сохранён

### Локальная настройка Claude Code (ноутбук Ильи)
- [docs/claude-code-mcp-setup.md](claude-code-mcp-setup.md) — полная инструкция
- [.mcp.json](../.mcp.json) — конфиг для локального Claude Code (использует `${VAR}` подстановку, секреты не хранит)
- [scripts/claude-session.ps1](../scripts/claude-session.ps1) — обёртка PowerShell: SSH-tunnel + env pull из сервера → `claude` → cleanup

### Открытые вопросы надёжности (P1/P2)
- `OPENCLAW_GATEWAY_TOKEN` — в `openclaw.json` зашит конкретным значением, но в `/opt/realty-portal/.env` отсутствует (handoff был неточным). Не блокер — OpenClaw работает, но противоречит принципу единого сейфа. Починить при случае.
- `/home/node/.npm/_npx/` не в Docker volume → npx-кэш пропадает при `docker compose up --force-recreate` → первый вызов MCP после recreate качает пакеты заново (~5 сек при наличии интернета). При оффлайн-режиме — сломается. P1.
- 4 compose-проекта (`realty`, `realty_supabase`, `realty_lightrag`, `realty_openclaw`) — `migrate.sh` должен знать про все 4 (проверить). P1.

### Бэкапы openclaw.json (на случай отката)
- `/home/node/.openclaw/openclaw.json.backup-20260419-153524` (до патча пакетов)
- `/home/node/.openclaw/openclaw.json.backup-20260419-*-pin` (до пиннинга версий)

### Проверки изоляции (от других программ)
- ✅ Всё в `/opt/realty-portal/` или `realty_supabase` compose project
- ✅ Единственная кастомная Docker-сеть — `realty_net`
- ✅ Все тома либо prefixed `realty_supabase_*` либо bind-mounts в `supabase/upstream/docker/volumes/`
- ✅ Конфликта с brain-проектом нет (brain полностью удалён — см. секцию 2)
- ✅ Ни один сервис не биндится на 0.0.0.0 (кроме SSH 22)
