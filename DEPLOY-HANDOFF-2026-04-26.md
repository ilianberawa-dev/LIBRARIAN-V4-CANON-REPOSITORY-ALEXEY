# DEPLOY-HANDOFF — 2026-04-26

**Назначение:** новой Claude-сессии для деплоя TG-парсера + Realty-стека на новый сервер.
**Источники:** PR #3 (merged), PR #6 (open), branches `realty-rescue/from-windows` и `parser-fixes/critical-v2`.

---

## 0. Сначала прочитай (5 минут)

```
git fetch --all
git checkout claude/resume-teleport-session-44ziu  # текущая работа
git checkout origin/realty-rescue/from-windows -- .  # копия прод-кода
```

Канон: `kanon/simplicity-first-principle.md` (605 строк) — обязательно ПЕРЕД действиями.

---

## 1. Состояние веток и PR

| Ветка | Где | Зачем |
|---|---|---|
| `main` | origin | Канон + библиотека + смёрджен PR #3 (a4ddf93) |
| `parser-fixes/critical-v2` | origin | **PR #6 (draft)** — патчи P4 lockout + msg.media fallback + install package |
| `realty-rescue/from-windows` | origin | **227 файлов** rescue с `/c/work/realty-portal/`. Содержит секреты в `docs/school/launcher_school_v4.json` и `docs/school/handoff/school_v3_to_v4_dump.md` — пользователь подтвердил замену секретов потом |
| `claude/resume-teleport-session-44ziu` | origin | Текущая рабочая (этот документ) |

**Проверь PR #6 статус** перед деплоем — возможно уже смёрджен.

---

## 2. Где живёт код для каждого компонента

### Parser 1 (TG канал Алексея)
- **Скрипты v1 (на Aeza):** `aeza-archive/{download.mjs, sync_channel.mjs, heartbeat.sh, transcribe.sh, notify.sh, verify.sh, ingest_transcripts.py, merge_transcripts.py, enumerate_p4.mjs}`
- **Install-package** (готов к деплою): `parser-install/` на ветке `parser-fixes/critical-v2`
  - `parser-install/install.sh` — one-command deploy
  - `parser-install/scripts/` — все 9 скриптов с PR #6 патчами
  - `parser-install/config/{.env.example, config.json5.example, package.json}`
  - `parser-install/cron.example` + `parser-install/github-sync.sh` + `README.md`
- **Patches в PR #6:**
  - `aeza-archive/heartbeat.sh` — ENV `MIN_PRIO`/`MAX_PRIO` (фикс P4 lockout)
  - `aeza-archive/sync_channel.mjs` — `msg.document || msg.media?.document` fallback (фикс потери документов)

### Parser 2 (rumah123/lamudi — Бали недвижимость)
- Всё на ветке `realty-rescue/from-windows`:
  - `scrapers/rumah123/{run.py, fetch_details.py, requirements.txt}`
  - `scrapers/lamudi/run.py`
  - 5 разведчиков `scrapers/_probe_*.py`, `_farsight_deep.py`

### Docker-стек (4 compose-проекта)
На `realty-rescue/from-windows`:
- `docker-compose.yml` — корневой, только сеть `realty_net`
- `lightrag/docker-compose.yml` + `lightrag/litellm_config.yaml`
- `openclaw/docker-compose.yml`
- `supabase/docker-compose.override.yml` + миграции SQL

### Deploy-скрипты
На `realty-rescue/from-windows`:
- `scripts/orchestrator.sh` — главный деплой
- `scripts/migrate.sh` — переезд server→server (`./scripts/migrate.sh root@new-server`)
- `scripts/{stack-lib.sh, backup.sh, restore.sh, doctor.sh, load-env.sh, run_with_env.sh}`
- `scripts/normalize_listings.py` — данные → Supabase

### Skills (для OpenClaw)
- `skills/EVL-CTX-001` ... `EVL-ORC-016` — 16 evaluation skills
- `skills/{market_snapshot, normalize_listing, parse_listings_web, search_properties, store_to_supabase}` — 5 ops skills

### Документация (изучить перед деплоем)
- `docs/architecture.md` — канон Алексея 2026-04-19
- `docs/secrets-policy.md` — единый сейф `.env`
- `docs/school/handoff/telegram_topology_school_v4.md` — TG топология
- `docs/school/skills/heartbeat-common.md` — 720 строк, канон heartbeat (Layer 1+2)
- `docs/school/skills/heartbeat-parser.md` — спецификация для parser-rumah123

---

## 3. Секреты — REVOKE перед деплоем

В `realty-rescue/from-windows` присутствуют ЖИВЫЕ ключи (пользователь сказал «заменим потом»):

| Что | Где | Дальше |
|---|---|---|
| Telegram MTProto sessionString | `docs/school/launcher_school_v4.json:248`, `docs/school/handoff/school_v3_to_v4_dump.md:282` | https://my.telegram.org → terminate ALL sessions; новый apiId/Hash |
| SSH root password Aeza | `docs/school/launcher_school_v4.json:233-234` | если хост жив — `passwd` |
| LITELLM_MASTER_KEY (`sk-27b4b513...`) | `launcher_school_v4.json` + dump.md | rotate в litellm UI или через docker exec |
| BOT_TOKEN (`8637638856:AAH0Hv...`) | те же 2 файла | @BotFather → `/revoke` → @PROPERTYEVALUATOR_bot |
| MCP agent tokens (×5) | `launcher_school_v4.json:73-77` | re-register через mcp_agent_mail |

Также утекли (старые) в `aeza-rescue/from-windows` — ветка удалена, но reflog/forks/cache GitHub могут хранить:
- xAI key `xai-Znu...`
- GitHub PAT `github_pat_11C...`
- Тот же BOT_TOKEN

Список нужных ключей для нового деплоя — см. `realty-rescue/from-windows/.env.example` (30+ переменных, все CHANGE_ME).

---

## 4. План деплоя (укрупнённо)

### Шаг 1 — подготовка нового сервера
- Ubuntu 22.04+ или 24.04, 8GB RAM, 60GB disk минимум
- `apt install -y nodejs npm python3 python3-pip ffmpeg jq bc curl git docker.io docker-compose-plugin`
- node 18+ (`nodesource setup_18.x`)

### Шаг 2 — клонировать realty-rescue
```bash
git clone https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY.git /opt/librarian
cd /opt/librarian
git checkout realty-rescue/from-windows
# Скопировать только нужное в /opt/realty-portal/
mkdir -p /opt/realty-portal
cp -r scripts scrapers skills lightrag openclaw supabase docs/school .env.example .gitignore docker-compose.yml /opt/realty-portal/
```

### Шаг 3 — заполнить `.env`
```bash
cd /opt/realty-portal
cp .env.example .env
chmod 600 .env
nano .env  # заполнить все CHANGE_ME (после revoke см. секцию 3)
```

### Шаг 4 — запустить стек через `migrate.sh`
```bash
./scripts/migrate.sh root@new-server
# или вручную: bash scripts/orchestrator.sh
```

### Шаг 5 — TG-парсер v1 (`/opt/tg-export/`)
```bash
mkdir -p /opt/tg-export
cd /opt/librarian
git checkout parser-fixes/critical-v2  # ветка с PR #6 + install package
bash parser-install/install.sh  # копирует в /opt/tg-export/
# Заполнить /opt/tg-export/.env и config.json5
# Скопировать существующий library_index.json чтобы избежать full re-sync:
cp /opt/librarian/alexey-materials/metadata/library_index.json /opt/tg-export/
```

### Шаг 6 — cron
Из `parser-install/cron.example`:
```cron
*/10 * * * * cd /opt/tg-export && bash heartbeat.sh
0 */2 * * *  cd /opt/tg-export && bash notify.sh
15 */6 * * * cd /opt/tg-export && node sync_channel.mjs
30 2 * * *   cd /opt/tg-export && bash verify.sh
0 * * * *    cd /opt/librarian && bash parser-install/github-sync.sh
```

### Шаг 7 — verify
```bash
cd /opt/realty-portal && bash scripts/doctor.sh
cd /opt/tg-export && cat _status.json | jq
```

---

## 5. Что я НЕ делал и что осталось

- ❌ Не пушил коммитов с патчами — это сделала другая сессия (PR #6)
- ❌ Не запускал deploy на новом сервере — нет к нему SSH из sandbox
- ❌ Не верифицировал rumah123/lamudi код в исполнении — только syntax
- ❌ Не проверял Supabase миграции на исполнение — только YAML валиден
- ❌ Не считал «долг по Алексею» — нужны актуальные данные канала (последний msg_id)
- ❌ Не ротировал секреты — пользовательская задача

---

## 6. Известные проблемы

1. **rate-limit Grok STT** — параллельная транскрибация может ловить 429. Текущая логика серийная.
2. **Auto-restart heartbeat** в v1 хардкодил `MAX_PRIO=3` → P4 видео не восстанавливались. Фикс в PR #6.
3. **Document classification bug** — посты с медиа в `msg.media.document` (а не `msg.document`) попадали как `type:'text'`. Фикс в PR #6.
4. **One gramjs client** на канал — второй с той же sessionString разлогинит оба. Не запускать параллельно!
5. **`rm -f $src` в transcribe.sh** — видео удаляется после транскрибации (есть safety check, но `.trash/` нет).

---

## 7. Контекст-якоря

- Пользователь: Илья (брокер, vibe-coder по канону Алексея, не technical-deep)
- Принципы: Simplicity-First (#0), Portability (#1), Minimal Integration Code (#2), Skills Over Agents (#4)
- Aeza VPS 193.233.128.21 (`grotesquecoffee.aeza.network`) — статус неоднозначный (по словам пользователя «умерла», но на main коммиты с этого хоста до 25.04 04:00 UTC)
- GitHub репо: https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY (public)

---

## 8. Что прочитать в порядке приоритета

1. `kanon/simplicity-first-principle.md` — canon
2. `kanon/alexey-11-principles.md` — canon
3. Этот файл целиком
4. `docs/architecture.md` (на ветке `realty-rescue/from-windows`)
5. `docs/school/skills/heartbeat-common.md` (там же)
6. `docs/school/handoff/telegram_topology_school_v4.md` (там же)
7. PR #6 description
8. `parser-install/README.md` (на ветке `parser-fixes/critical-v2`)

---

**Создано:** 2026-04-26 на ветке `claude/resume-teleport-session-44ziu`
**Автор:** Claude Opus 4.7 (teleport session)
