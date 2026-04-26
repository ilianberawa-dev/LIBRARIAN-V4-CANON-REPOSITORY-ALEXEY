# ТЗ Stage 8 — WhatsApp Listener (GOWA → Telegram уведомления)

**Ветка:** `claude/setup-library-access-FrRfh`
**Репо:** `LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY`
**Выдал:** Архитектор, 2026-04-26

---

## Цель

Когда владельцу приходит сообщение в WhatsApp — он сразу видит уведомление в Telegram (в тот же бот, которым уже пользуется). Ответ пока руками, интеграция с triage/draft-gen — Stage 8.2 (позже).

---

## Что устанавливаешь

### Компонент 1 — GOWA (Go WhatsApp Web Multidevice)

**Репо:** https://github.com/aldinokemal/go-whatsapp-web-multidevice  
**Что это:** Docker-контейнер / Go-бинарник, реализует WhatsApp Web multi-device protocol (через `whatsmeow`), даёт REST API + webhook на входящие сообщения.

**Почему GOWA, не WAHA:** GOWA использует нативный multi-device протокол whatsmeow (тот же что Beeper). Ниже ban-риск, меньше RAM, не нужен Puppeteer.

### Компонент 2 — `wa-listener.mjs`

Новый Node.js сервис (Express). Принимает webhook от GOWA, пересылает уведомление в Telegram владельцу.

---

## Сервер

- **Хост:** UpCloud (тот же что все personal-assistant-* сервисы)
- **Пользователь:** `personal-assistant`
- **Папка приложения:** `/opt/personal-assistant`
- **БД:** `/opt/personal-assistant/assistant.db` (SQLite WAL)
- **Vault:** секреты через `getSecret()` из `/opt/personal-assistant/lib/vault.mjs`

---

## Файлы которые создашь

```
metody/personal-ai-assistant/implementation/stage-8/
├── install-stage-8.sh
├── wa-listener.mjs
├── personal-assistant-gowa.service
├── personal-assistant-wa-listener.service
└── migrations/002-add-wa-messages.sql
```

---

## Детали реализации

### 1. install-stage-8.sh

Идемпотентный bash-скрипт. Делает:

```bash
#!/bin/bash
set -euo pipefail
APP_DIR=/opt/personal-assistant
SRC_DIR="$(dirname "$0")"

# 1. Установить Docker если нет
# 2. Запустить GOWA контейнер:
docker run -d \
  --name gowa \
  --restart always \
  -p 127.0.0.1:3001:3000 \
  -v /opt/personal-assistant/gowa-data:/app/storages \
  aldinokemal2104/go-whatsapp-web-multidevice:latest \
  --webhook http://127.0.0.1:3005/webhook

# 3. Скопировать wa-listener.mjs в APP_DIR
install -m 0640 -o root -g personal-assistant "${SRC_DIR}/wa-listener.mjs" "${APP_DIR}/wa-listener.mjs"

# 4. Применить миграцию БД
sqlite3 "${APP_DIR}/assistant.db" < "${SRC_DIR}/migrations/002-add-wa-messages.sql"

# 5. Включить и запустить оба сервиса
systemctl enable personal-assistant-gowa personal-assistant-wa-listener
systemctl start  personal-assistant-gowa personal-assistant-wa-listener
```

**GOWA volume:** `/opt/personal-assistant/gowa-data` — хранит WhatsApp сессию (после QR-сканирования).  
**GOWA порт:** 3001 (только localhost, не наружу).  
**wa-listener порт:** 3005 (только localhost, не наружу).  
**GOWA → webhook:** `--webhook http://127.0.0.1:3005/webhook`

### 2. wa-listener.mjs

```javascript
import express from 'express';
import Database from 'better-sqlite3';
import { getSecret, redact } from './lib/vault.mjs';

const REQUIRED_ENV = ['OWNER_TG_ID'];
// fail-loud checks ...

const BOT_TOKEN = getSecret('bot-token');
const OWNER_TG_ID = process.env.OWNER_TG_ID;
const DB_PATH = process.env.DB_PATH || '/opt/personal-assistant/assistant.db';
const PORT = 3005;

const db = new Database(DB_PATH);
const app = express();
app.use(express.json());

// GOWA webhook payload (incoming message):
// {
//   "code": "message.updated",
//   "result": {
//     "sender": { "phone": "628123...", "name": "Имя", "is_me": false },
//     "text": "текст",
//     "type": "text",        // text | image | audio | video | document
//     "timestamp": "...",
//     "message_id": "XXX"
//   }
// }

app.post('/webhook', async (req, res) => {
  res.sendStatus(200); // ack GOWA немедленно

  const payload = req.body;
  const result = payload?.result;
  if (!result || result.sender?.is_me) return; // игнорируем исходящие

  const sender = result.sender?.name || result.sender?.phone || 'Unknown';
  const phone  = result.sender?.phone || '';
  const kind   = result.type || 'text';
  const text   = result.text || `[${kind}]`;

  // Сохраняем в wa_messages
  const stmt = db.prepare(`
    INSERT INTO wa_messages (phone, name, kind, text, raw_json)
    VALUES (?, ?, ?, ?, ?)
  `);
  const row = stmt.run(phone, sender, kind, text, JSON.stringify(payload));

  // Отправляем уведомление в Telegram владельцу
  const preview = text.length > 200 ? text.slice(0, 200) + '…' : text;
  const tgText  = `📱 *WA от ${sender}:*\n${preview}`;

  await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: OWNER_TG_ID,
      text: tgText,
      parse_mode: 'Markdown',
    }),
  });

  console.log(JSON.stringify({ ts: new Date().toISOString(), event: 'wa_message', sender, kind, wa_id: row.lastInsertRowid }));
});

// SIGTERM graceful shutdown
process.on('SIGTERM', () => { db.close(); process.exit(0); });
process.on('SIGINT',  () => { db.close(); process.exit(0); });

app.listen(PORT, '127.0.0.1', () => {
  console.log(JSON.stringify({ ts: new Date().toISOString(), event: 'startup', port: PORT }));
});
```

**Зависимости** — уже есть в проекте: `express`, `better-sqlite3`. `fetch` — нативный Node 18+.

### 3. personal-assistant-gowa.service

```ini
[Unit]
Description=Personal AI Assistant — GOWA WhatsApp Bridge
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
ExecStart=/usr/bin/docker start gowa
ExecStop=/usr/bin/docker stop gowa
Restart=no

[Install]
WantedBy=multi-user.target
```

> Примечание: контейнер `gowa` создаётся install-скриптом один раз (`docker run -d --restart always`). Сервис просто стартует/стопает его. `--restart always` в Docker гарантирует автоподъём после reboot без systemd-логики.

### 4. personal-assistant-wa-listener.service

```ini
[Unit]
Description=Personal AI Assistant — WhatsApp Listener
After=network-online.target personal-assistant-gowa.service
Wants=network-online.target

[Service]
Type=simple
User=personal-assistant
Group=personal-assistant
WorkingDirectory=/opt/personal-assistant
EnvironmentFile=/opt/personal-assistant/config.env
ExecStart=/usr/bin/node /opt/personal-assistant/wa-listener.mjs
Restart=always
RestartSec=5
StartLimitIntervalSec=300
StartLimitBurst=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=personal-assistant-wa-listener

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/personal-assistant
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
MemoryMax=100M
TasksMax=32

[Install]
WantedBy=multi-user.target
```

> `LoadCredentialEncrypted` не нужен: `bot-token` уже в vault, читается через `getSecret()`. Если Stage 0.6 деплой ещё не выполнен — перепроверь что vault.mjs доступен в `/opt/personal-assistant/lib/vault.mjs`.

### 5. migrations/002-add-wa-messages.sql

```sql
-- Stage 8: WhatsApp incoming messages log
CREATE TABLE IF NOT EXISTS wa_messages (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  phone      TEXT,
  name       TEXT,
  kind       TEXT DEFAULT 'text',
  text       TEXT,
  raw_json   TEXT,
  received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  forwarded  INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_wa_messages_received_at ON wa_messages(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_wa_messages_phone       ON wa_messages(phone);

INSERT OR REPLACE INTO schema_version (version, applied_at)
VALUES ('1.4', datetime('now'));
```

---

## После деплоя — QR-сканирование

GOWA запустится и будет ждать авторизации. Владелец выполняет **один раз** из консоли:

```bash
# Получить QR код в терминале
curl http://127.0.0.1:3001/app/login
# Вернёт HTML или JSON с QR. Либо:
docker logs gowa   # QR в ASCII в логах
```

Открываешь WhatsApp Business на телефоне → Настройки → Связанные устройства → Привязать устройство → сканируешь QR.

После сканирования GOWA сохраняет сессию в `/opt/personal-assistant/gowa-data/`. Повторное сканирование не нужно.

---

## Acceptance criteria

- [ ] `systemctl is-active personal-assistant-gowa` → `active`
- [ ] `systemctl is-active personal-assistant-wa-listener` → `active`
- [ ] `journalctl -u personal-assistant-wa-listener -n 20` — нет fatal ошибок
- [ ] Написать тестовое сообщение в WA → в течение 10 сек Telegram-бот присылает уведомление с именем отправителя и текстом
- [ ] `sqlite3 /opt/personal-assistant/assistant.db "SELECT * FROM wa_messages ORDER BY id DESC LIMIT 1;"` — запись есть
- [ ] `sqlite3 /opt/personal-assistant/assistant.db "SELECT version FROM schema_version;"` → содержит `1.4`
- [ ] Входящий WA `is_me=true` (отправленное владельцем) — в TG **не** отображается

---

## Что НЕ делаешь в этом ТЗ

- ❌ Не подключаешь wa_messages к triage/draft-gen — это Stage 8.2
- ❌ Не добавляешь WA как источник в `inbox` — это Stage 8.2
- ❌ Не настраиваешь отправку WA-ответов из TG — это Stage 8.2
- ❌ Не трогаешь Stage 0.6 сервисы

---

## Канон-чеклист (самопроверка перед коммитом)

- [ ] `getSecret('bot-token')` — не `process.env.BOT_TOKEN`
- [ ] Нет `catch (e) {}` без логирования
- [ ] SIGTERM/SIGINT handler с `db.close()`
- [ ] fetch с таймаутом (AbortController, 10s)
- [ ] Логи валидный JSON через `console.log(JSON.stringify(...))`
- [ ] `ProtectSystem=strict` + `NoNewPrivileges=true` в .service
- [ ] `ReadWritePaths=` только `/opt/personal-assistant`
- [ ] GOWA volume permissions: `chown -R personal-assistant:personal-assistant /opt/personal-assistant/gowa-data`

---

## Коммит

```
git add metody/personal-ai-assistant/implementation/stage-8/
git commit -m "feat(stage-8): GOWA WhatsApp bridge + wa-listener TG notifications"
git push origin claude/setup-library-access-FrRfh
```
