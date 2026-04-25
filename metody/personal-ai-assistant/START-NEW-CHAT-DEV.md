# Старт нового Claude чата — Personal AI Assistant разработка

**Назначение:** Стартер для нового чата, где владелец продолжит разработку AI Assistant после этого чата.

---

## 🚀 Команда для нового чата

Скопируй и вставь целиком в новый Claude чат:

```
Ты — архитектор проекта Personal AI Assistant для владельца.

КОНТЕКСТ:
- Библиотека на GitHub: ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY
- Ветка: claude/setup-library-access-FrRfh (PR #1, draft)
- Сервер: Aeza (193.233.128.21), свободно 3.8 GB RAM / 23 GB disk
- Существующий софт на сервере: /opt/tg-export/ (парсер канала Алексея, не ломать),
  realty_lightrag + realty_ollama + supabase-* (для realty portal, изолированы)

ЧИТАЙ В ПЕРВУЮ ОЧЕРЕДЬ:

1. kanon/simplicity-first-principle.md — Principle #0 (ПЕРЕД любым решением)
2. kanon/alexey-11-principles.md — 12 принципов Алексея
3. kanon/alexey-consultation-2026-04-24-agent-canon.md — авторитетный канон автора
4. metody/personal-ai-assistant/v1.1-mvp-simplified.md — ТЗ MVP (главный документ)
5. metody/personal-ai-assistant/AUDIT-2026-04-24.md — почему именно так упрощено

ТВОЯ РОЛЬ:
- Архитектор, не исполнитель
- Декомпозируешь задачи для Claude Code чатов-исполнителей
- Каждое решение проверяешь по 12 принципам канона
- Принцип #0 Simplicity First — всегда первый

ТЕКУЩИЙ СТАТУС:
- Завершён canon audit, упрощён MVP до 6 этапов / 10-12 дней
- Ждём от владельца: SSH к Aeza, API keys (Anthropic, TG Bot), MTProto auth, VIP list

СТРАТЕГИЯ РАЗРАБОТКИ:
- Архитектор (ты) → пишет ТЗ каждого этапа
- Claude Code чаты-исполнители → пишут код
- Владелец → даёт доступы + reviews
- Каждый этап имеет критерий приёмки
- Ничего не добавляется без trigger condition (#8 Validate Before Automate)
```

---

## 📋 Короткая шпаргалка по ТЗ MVP v1.1

### Бюджет
- **$20/мес** Anthropic (Sonnet 4.6 с prompt caching, cap $22)
- **$0.50/мес** Grok STT (уже есть)
- **Итого: ~$20-21/мес**

### 6 этапов (10-12 дней)

| # | Этап | Дни | Value |
|---|------|-----|-------|
| 1 | Listener live | 1-2 | входящие TG → SQLite + форвард в канал |
| 2 | Triage | 1 | сообщения с тэгами hot/regular/noise |
| 3 | Drafts | 2 | Sonnet предлагает ответ на важное |
| 4 | Inline buttons | 1 | [Отправить/Правка/Голосом/Игнор] |
| 5 | Voice 3 intent | 1-2 | "Ответь X", "Правило Y", "Поиск Z" |
| 6 | Heartbeat + hc-ping | 1 | 7 дней uptime без рук |

### Что НЕ в MVP (Phase 2+)

| Компонент | Trigger добавления |
|-----------|--------------------|
| Silero TTS | 5+ использований кнопки 🎙 |
| LiteLLM + Qwen | Sonnet-only $ ≥$20/мес |
| Embeddings | FTS5 misses ≥50% |
| Learning auto | 3+ паттерна замечено |
| PWA | "TG экран мал" |
| History backfill | По конкретному запросу |
| Parser групп | MVP стабилен 2 недели |

---

## 🔐 Что нужно от владельца для старта

0. **Claude Code Max** ($100/мес — Pro $20 не хватит)
0.5. **Sub-agents настроены** в `~/.claude/agents/` (scout-haiku, worker-sonnet, strategist-opus)
1. SSH root к VPS (Aeza если жив, иначе новый — Linode Jakarta или Vultr Singapore по канону)
2. Anthropic API key
3. Telegram Bot token (@BotFather)
4. Chat_id (curl-команда)
5. MTProto auth для личного аккаунта (скрипт на своей машине с СМС-кодом)
6. Healthchecks.io account → ping URL
7. Имя бота (@xxx_ai_bot)
8. VIP список контактов
9. Подтверждение $22/мес cap

---

## 🗂️ Структура работ

```
/opt/personal-assistant/     — новая папка, изолирована
├── listener.mjs            — Этап 1
├── triage.mjs + skills/triage.md  — Этап 2
├── draft_gen.mjs + skills/draft.md — Этап 3
├── bot.mjs                 — Этап 4
├── voice.mjs + skills/voice_intent.md — Этап 5
├── heartbeat.sh            — Этап 6
├── assistant.db            — SQLite + FTS5
├── .env                    — one file, all secrets
└── systemd/*.service       — не Docker
```

---

## ⚠️ Критичные запреты

- ❌ Не мешать с `/opt/tg-export/` (парсер канала Алексея)
- ❌ Не подключать `realty_lightrag` или `realty_ollama` (утечка данных, #11)
- ❌ Не делать auto-reply без human review — никогда
- ❌ Не Python для основного кода (канон Алексея)
- ❌ Не мульти-агентные системы (канон Алексея)
- ❌ Не добавлять новые компоненты без trigger condition

---

## 📜 Hierarchy решений

**При любом сомнении:**
1. Что говорит Алексей в `kanon/alexey-consultation-2026-04-24-agent-canon.md`?
2. Что говорят 12 принципов `kanon/alexey-11-principles.md`?
3. Что говорит Principle #0 `kanon/simplicity-first-principle.md`?
4. Что делают аналоги в индустрии (Superhuman / Shortwave)?
5. Только потом — своя оценка

---

## 📂 Ключевые файлы библиотеки

**Канон:**
- `kanon/alexey-11-principles.md` — 12 принципов
- `kanon/simplicity-first-principle.md` — #0 детально
- `kanon/alexey-consultation-2026-04-24-agent-canon.md` — авторитет

**Метод:**
- `metody/personal-ai-assistant/v1.1-mvp-simplified.md` — текущий ТЗ (читать!)
- `metody/personal-ai-assistant/AUDIT-2026-04-24.md` — история упрощения
- `metody/personal-ai-assistant/v1.0-mvp-to-sales.md` — original methodology (deprecated for MVP)

**Навыки (переиспользование):**
- `navyki/heartbeat-telegram-pattern.md` — heartbeat с исправлениями
- `navyki/heartbeat-telegram.sh` — template (требует фиксов, см. аудит)

**Справочники:**
- `spravochniki/skills-a-to-ya.md` — 110KB справочник по Skills

**Troubleshooting:**
- `troubleshoot/telegram-parser-recreation.md` — для Phase 3 парсера

**Reference implementation:**
- `aeza-archive/download.mjs` — доказанный парсер с Human Rhythm
- `aeza-archive/heartbeat.sh` — эталон heartbeat
- `aeza-archive/transcribe.sh` — Grok STT (нужно исправление language=ru)

---

**Создано:** 2026-04-24
**Контекст:** сохранение наработок для нового чата
**Следующий шаг:** владелец даёт 9 позиций setup → Этап 1 стартует
