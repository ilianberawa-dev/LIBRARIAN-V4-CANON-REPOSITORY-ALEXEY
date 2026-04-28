# Installation Plan — Personal AI Assistant MVP v1.2

**Дата:** 2026-04-25
**Назначение:** Декомпозиция MVP на конкретные задачи для прораба → работяг
**Принцип:** один этап = один Claude Code чат-работяга

---

## Roadmap (8 этапов, 13-16 дней)

| # | Этап | Дни | Работяг | Зависимости |
|---|------|:---:|:-------:|-------------|
| 0 | Sub-agents (~/.claude/agents/) | 1 | владелец сам | — |
| 1 | Listener live (gramjs + SQLite + forward) | 1-2 | работяга #1 | Этап 0 |
| 2 | Triage (Sonnet тэги) | 1 | работяга #2 | Этап 1 |
| 3 | Drafts (Sonnet с контекстом) | 2 | работяга #3 | Этап 2 |
| 3.5 | Brief Compiler (3×день) | 1 | работяга #4 | Этап 3 |
| 4 | Inline buttons + Silero TTS | 2 | работяга #5 | Этап 3.5 |
| 5 | Voice 4 команды | 1-2 | работяга #6 | Этап 4 |
| 6 | Heartbeat + backup + hc-ping | 1 | работяга #7 | Этап 5 |

---

## Setup checklist (one-time, владелец)

| # | Что | Где | Время |
|---|-----|-----|-------|
| 1 | Claude Code Max подписка | console.anthropic.com → Plans → Max | 3 мин |
| 2 | Sub-agents в `~/.claude/agents/` (scout-haiku, worker-sonnet, strategist-opus) | dev машина | 30 мин (Этап 0) |
| 3 | UpCloud Premium $26 (2/4/50 NVMe MaxIOPS) SGP1 + Week backup $5.20 | upcloud.com | 15 мин |
| 4 | Anthropic API key (production runtime) | console.anthropic.com → Create Key | 5 мин |
| 5 | Telegram Bot token (@BotFather) | telegram → @BotFather → /newbot | 3 мин |
| 6 | Chat_id для канала AI Assistant | curl команда от прораба | 2 мин |
| 7 | MTProto auth личного TG (SMS код) | скрипт от работяги #1 на dev машине | 5 мин |
| 8 | Healthchecks.io free account → ping URL | healthchecks.io | 3 мин |
| 9 | VIP список 3-5 контактов (имена/usernames) | mental list | — |
| 10 | Подтверждение budget cap $22/мес API | — | — |

---

## Этап 0: Sub-agents setup (владелец)

**Файл:** `~/.claude/agents/scout-haiku.md`
```markdown
---
name: scout-haiku
description: Quick search agent for files, FTS5 queries, references
model: haiku-4-5
---
You are a fast scout. Find files, search code, fetch documentation. Be brief.
```

**Файл:** `~/.claude/agents/worker-sonnet.md`
```markdown
---
name: worker-sonnet
description: Default executor for writing skills, code, parsers
model: sonnet-4-6
---
You are the default worker. Write code, skills, parsers. Follow instructions exactly.
```

**Файл:** `~/.claude/agents/strategist-opus.md`
```markdown
---
name: strategist-opus
description: Deep thinking for architecture, plans, tradeoffs (use rarely)
model: opus-4-7
---
You are a strategist. Deep architecture analysis. Use only for complex tradeoffs.
```

**Acceptance:** в Claude Code чате команда "найди X в проекте" автоматически роутится на scout-haiku.

---

## Этап 1: Listener live

**Цель:** входящее TG → SQLite → forward в канал AI Assistant за ≤3 сек.

**Что создать на сервере:**
- `/opt/personal-assistant/listener.mjs` — gramjs NewMessage handler
- `/opt/personal-assistant/auth.mjs` — одноразовая SMS auth
- `/opt/personal-assistant/schema.sql` — SQLite + FTS5
- `/opt/personal-assistant/.env` — single secret vault
- `/opt/personal-assistant/package.json` — deps: telegram, better-sqlite3, dotenv
- `/etc/systemd/system/personal-assistant-listener.service` — systemd unit

**SQLite schema:**
```sql
CREATE TABLE contacts (
  tg_id INTEGER PRIMARY KEY,
  name TEXT, username TEXT,
  first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_msg_at TIMESTAMP,
  msg_count_30d INTEGER DEFAULT 0,
  priority TEXT,
  is_vip BOOLEAN DEFAULT 0,
  notes TEXT, tone TEXT
);

CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tg_msg_id INTEGER, chat_id INTEGER,
  from_id INTEGER REFERENCES contacts(tg_id),
  text TEXT,
  received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  category TEXT, urgent BOOLEAN DEFAULT 0,
  handled BOOLEAN DEFAULT 0
);

CREATE VIRTUAL TABLE messages_fts USING fts5(
  text, from_name, chat_name,
  content=messages,
  tokenize='unicode61 remove_diacritics 2'
);

CREATE TABLE drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  msg_id INTEGER REFERENCES messages(id),
  draft_text TEXT,
  generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  verdict TEXT, final_text TEXT, feedback_note TEXT
);

CREATE TABLE rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scope TEXT, scope_id TEXT,
  action TEXT, note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE voice_samples (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  to_contact_id INTEGER REFERENCES contacts(tg_id),
  text TEXT, sent_at TIMESTAMP
);

CREATE TABLE budget_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date DATE, input_tokens INTEGER, output_tokens INTEGER,
  cost_usd REAL, operation TEXT
);

CREATE TABLE briefs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  brief_type TEXT,
  generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  content TEXT,
  msg_count INTEGER
);
```

**Acceptance:** `tail -f /var/log/personal-assistant/listener.log` показывает приём входящего сообщения, в SQLite появляется запись, в канале AI Assistant появляется forward за ≤3 сек.

---

## Этап 2: Triage

**Цель:** каждое входящее классифицируется на hot/regular/new/noise + urgent boolean.

**Что создать:**
- `/opt/personal-assistant/triage.mjs` — Sonnet wrapper с skill
- `/opt/personal-assistant/skills/triage.md` — детерминированный prompt

**Decision flow:**
```
incoming →
  is_bot_or_channel? → noise (no LLM)
  contact.is_vip? + 'срочно|?|help' → urgent=1, hot
  contact.msg_count_30d > 10 → hot
  contact.msg_count_30d > 3 → regular
  contact.msg_count_30d < 3 → new
  Sonnet call (cached system) → category классификация
```

**Acceptance:** на 100 реальных сообщений ≥85% классификация визуально правильная.

---

## Этап 3: Drafts

**Цель:** для важных сообщений (hot/regular + question) — draft в канал.

**Что создать:**
- `/opt/personal-assistant/draft_gen.mjs` — Sonnet wrapper
- `/opt/personal-assistant/skills/draft.md` — skill с voice_profile placeholder
- `/opt/personal-assistant/budget_guard.mjs` — hard cap $22/мес

**Acceptance:** на 20 реальных входящих минимум 60% драфтов отправляемы без правок.

---

## Этап 3.5: Brief Compiler (НОВЫЙ)

**Цель:** 3 раза в день (09:00/14:00/19:00 UTC+TZ) сводка в канал AI Assistant.

**Формат brief:**
```
📋 УТРЕННИЙ BRIEF — 09:00
─────────────────────────
🔥 За ночь (3 важных):
  • Илья (HOT): "Встреча в 12?"            [draft ↓]
  • Maria (HOT клиент): "Счёт пришёл?"     [draft ↓]
  • Банк (auto): "Платёж прошёл"           [info]

👥 РЕГУЛЯРНЫЕ (5):
  • Мама, Саша, Петя, ...                  [grouped]

🆕 НОВЫЕ (2):
  • +7999...: "Здравствуйте..."            [draft]
  • @user: "помнишь меня"                  [need context]

🗑️ ШУМ (47): каналы, новости, промо       [игнор]
```

**Что создать:**
- `/opt/personal-assistant/brief_compiler.mjs`
- `/opt/personal-assistant/skills/brief.md`
- 3 cron jobs (09:00, 14:00, 19:00)

**Между brief'ами:** только urgent (VIP + срочно) шлются мгновенно.

**Acceptance:** 3 brief'а в день приходят в канал, группировка корректная по тэгам.

---

## Этап 4: Inline buttons + Silero TTS активный

**Цель:** под каждым draft — 5 кнопок, [🎙 Голосом] **РАБОТАЕТ**.

**Что создать:**
- `/opt/personal-assistant/bot.mjs` — node-telegram-bot-api
- `/opt/personal-assistant/action_router.mjs` — webhook handler
- `/opt/personal-assistant/tts_silero.py` — Python TTS service
- `/opt/personal-assistant/silero_models/` — модель (200 MB)

**Кнопки:** [✅ Отправить] [✏️ Правка] [🎙 Голосом] [🚫 Игнор] [🔇 Mute]

**Acceptance:** клик [Отправить] → за 2 сек собеседник получил сообщение от твоего имени. Клик [🎙 Голосом] → за 3-5 сек собеседник получил .ogg от твоего имени.

---

## Этап 5: Voice 4 команды

**Цель:** voice message в bot → STT → intent → action.

**4 команды:**
1. **"Ответь [кому]: [текст]"** → draft
2. **"Правило [контакт] [never_draft/vip/mute]"** → INSERT rules
3. **"Поиск [запрос]"** → FTS5 + top 5 results
4. **"Backfill [контакт]"** ← НОВАЯ → инкрементальная история по конкретному чату

**Что создать:**
- `/opt/personal-assistant/voice.mjs`
- `/opt/personal-assistant/skills/voice_intent.md`
- `/opt/personal-assistant/backfill.mjs` (для команды #4)
- Адаптер `transcribe.sh` с `language=ru` фиксом

**Acceptance:** все 4 команды работают 90%+ на реальном голосе владельца.

---

## Этап 6: Heartbeat + monitoring + backup

**Цель:** 7 дней uptime без рук + ежедневный backup SQLite.

**Что создать:**
- `/opt/personal-assistant/heartbeat.sh` — адаптировано из `navyki/heartbeat-telegram.sh` с фиксами
- `/opt/personal-assistant/backup.sh` — SQLite daily 04:00 + 7-day rotation
- Cron: 5 мин day (8-22) / 30 мин night (23-7)
- Healthchecks.io ping URL в .env

**Heartbeat проверяет:**
- listener.mjs жив (pgrep + log freshness)
- bot.mjs жив
- SQLite доступна
- Бюджет не превышен
- Backup сделан сегодня

**Acceptance:** 72 часа uptime, все auto-restart'ы отработали, 0 false positives, daily backup появляется в `/opt/personal-assistant/backups/`.

---

## Production budget

| Статья | $/мес |
|--------|:-----:|
| UpCloud Premium SGP1 (2/4/50 MaxIOPS) | $26 |
| Week backup (+20%) | $5.20 |
| Anthropic Sonnet API runtime | $20 |
| Grok STT API | $0.50 |
| Healthchecks.io | $0 |
| **ИТОГО prod** | **~$51.70/мес** |

**Claude Code Max** ($100/мес) — для архитектора + прораба + работяг (та же подписка владельца).

---

**Версия:** 1.2 (post-re-audit, full features)
**Заменяет:** v1.1-mvp-simplified.md
**Статус:** Ready for orchestration
