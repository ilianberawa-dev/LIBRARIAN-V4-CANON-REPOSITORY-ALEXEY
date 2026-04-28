# HANDOFF: Stage 8 Installer — 2026-04-26

**Для:** агент-установщик (worker L-3)
**Ветка:** `claude/setup-library-access-FrRfh`
**Репо:** `LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY`

---

## Что уже сделано (в репо, commit d1dc216)

Все файлы в `metody/personal-ai-assistant/implementation/stage-8/`:
- `install-stage-8.sh` — идемпотентный деплой-скрипт (Docker + GOWA + systemd)
- `wa-listener.mjs` — Node.js webhook receiver (GOWA → Telegram уведомления)
- `personal-assistant-gowa.service` — systemd unit для Docker-контейнера
- `personal-assistant-wa-listener.service` — systemd unit для wa-listener.mjs
- `TASK-WA-LISTENER-2026-04-26.md` — полное ТЗ (читай если нужны детали)

**Отсутствует — нужно создать:**
- `migrations/002-add-wa-messages.sql`

## Твоя задача

### Шаг 1 — создать миграцию (в репо, не на сервере)

Создай файл `migrations/002-add-wa-messages.sql`:

```sql
-- Stage 8: WhatsApp incoming messages
CREATE TABLE IF NOT EXISTS wa_messages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  phone       TEXT,
  name        TEXT,
  kind        TEXT DEFAULT 'text',
  text        TEXT,
  raw_json    TEXT,
  received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  forwarded   INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_wa_messages_received_at ON wa_messages(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_wa_messages_phone       ON wa_messages(phone);

INSERT OR REPLACE INTO schema_version (version, applied_at)
VALUES ('1.4', datetime('now'));
```

### Шаг 2 — коммит миграции

```bash
git add metody/personal-ai-assistant/implementation/stage-8/migrations/
git commit -m "feat(stage-8): add wa_messages migration 002"
git push origin claude/setup-library-access-FrRfh
```

### Шаг 3 — деплой на сервер

Сервер: UpCloud, пользователь `root` → `/opt/personal-assistant/`.

```bash
# На сервере (root):
cd /tmp
git clone https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY \
  --branch claude/setup-library-access-FrRfh --depth 1 repo
cd repo/metody/personal-ai-assistant/implementation/stage-8
chmod +x install-stage-8.sh
bash install-stage-8.sh
```

### Шаг 4 — QR-сканирование (один раз)

```bash
docker logs gowa   # QR в ASCII
```

WhatsApp Business → Settings → Linked Devices → Link a Device → сканируй.

### Шаг 5 — acceptance test

```bash
systemctl is-active personal-assistant-gowa         # active
systemctl is-active personal-assistant-wa-listener  # active
# Отправить тестовое WA → в TG-бот должно прийти уведомление за <10 сек
sqlite3 /opt/personal-assistant/assistant.db \
  "SELECT id,name,text FROM wa_messages ORDER BY id DESC LIMIT 1;"
```

---

## Контекст проекта (минимум)

| Параметр | Значение |
|----------|----------|
| App dir | `/opt/personal-assistant` |
| DB | `/opt/personal-assistant/assistant.db` |
| Config | `/opt/personal-assistant/config.env` |
| Secrets | vault.mjs → `getSecret('bot-token')` |
| GOWA port | `127.0.0.1:3001` (только localhost) |
| wa-listener port | `127.0.0.1:3005` (только localhost) |
| GOWA data dir | `/opt/personal-assistant/gowa-data` |

## Что НЕ делаешь

- ❌ Не трогаешь stage-0.6 сервисы
- ❌ Не подключаешь WA к triage/draft-gen (это Stage 8.2)
- ❌ Не меняешь bot.mjs

## Канон-чеклист (wa-listener.mjs уже написан — проверь глазами)

- [x] `getSecret('bot-token')` — не process.env
- [x] SIGTERM/SIGINT + db.close()
- [x] fetch с AbortController (10s timeout)
- [x] JSON-логи через console.log(JSON.stringify(...))
- [x] Fail-loud на старте (REQUIRED_ENV check)
- [x] is_me=true → skip (не спамит владельцу его же сообщениями)
