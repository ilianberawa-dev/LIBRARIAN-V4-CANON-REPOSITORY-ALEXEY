# HANDOFF: Канон-Контроль onboarding — 2026-04-26

**Получатель:** новый чат-сэшн в роли Канон-Контроль (Reviewer L-1.5).
**Отправитель:** Архитектор (Опус 4.7), у которого контекст в критической зоне.
**Постоянный устав:** `metody/personal-ai-assistant/REVIEWER-PROMPT.md` — прочитай ПЕРВЫМ.

---

## Текущий снимок проекта

### Production (на UpCloud, активные сервисы)
| Сервис | Stage | Состояние | Известные проблемы |
|--------|-------|-----------|---------------------|
| `personal-assistant-listener` | 1 | active | catchUp + useWSS hotfix висит (handoff MD есть, фикс не сделан) |
| `personal-assistant-triage` | 2 | active | OK |
| `personal-assistant-draft-gen` | 3 | active | `[NEED_CONTEXT]` over-trigger (handoff MD есть, фикс не сделан) |
| `personal-assistant-brief` | 3.5 | active | OK |
| `personal-assistant-bot` | 4 | active | НЕ пишет в `voice_jobs` (нужно для Stage 5) |
| `personal-assistant-sender` | 4 | active | OK |

### В репо, не задеплоено
- **Stage 0.5 Safe Vault** — `stage-0.5/` (vault.mjs, install-safe-vault.sh, vault-deposit.ps1, vault-list.ps1, KEYS-MAP.md)
- **Stage 5 Voice** — `stage-5/` (voice.mjs, voice_intent.md, transcribe.sh, install-stage-5.sh, personal-assistant-voice.service)

### Pending / архитектурный долг
- Stage 0.6 — миграция 6 сервисов с `.env` на vault (ТЗ выдано работяге)
- Stage 5 deploy + bot.mjs voice_jobs integration (часть того же ТЗ)
- Stage 6 (heartbeat) — не сгенерирован
- Stage 7 (vision pipeline через Claude multimodal) — спроектирован, не написан
- Stage 8 (MCP server для query владельца к БД) — спроектирован, не написан

## ТЗ в работе (текущее задание работяги)

**"Большое ТЗ"** выдано Архитектором, 3 части:
- **Часть 1:** Stage 0.5 deploy на UpCloud (install-safe-vault.sh, депозит 5 ключей)
- **Часть 2:** Stage 0.6 migration — 6 сервисов с `.env` на vault.getSecret()
- **Часть 3:** Stage 5 deploy + bot.mjs `voice_jobs` integration + end-to-end тест

Полный текст ТЗ — в conversation history Архитектора (контекст близок к лимиту, поэтому передача через тебя).

## Твоя первая задача (cold-read review)

Запусти review по следующим файлам и коммитам:

### Группа A — Stage 0.5 vault infrastructure
**Коммиты:** `2059ac7` (vault), `ad1fd13` (KEYS-MAP expansion)
**Файлы:**
- `metody/personal-ai-assistant/implementation/stage-0.5/lib/vault.mjs` (76 lines)
- `metody/personal-ai-assistant/implementation/stage-0.5/install-safe-vault.sh` (74 lines)
- `metody/personal-ai-assistant/implementation/stage-0.5/vault-deposit.ps1` (84 lines)
- `metody/personal-ai-assistant/implementation/stage-0.5/vault-list.ps1` (12 lines)
- `metody/personal-ai-assistant/implementation/stage-0.5/KEYS-MAP.md` (расширенный, после `ad1fd13`)

**Что специально проверить:**
- vault.mjs — fail-loud при отсутствии `CREDENTIALS_DIRECTORY`?
- redact() — все 3 паттерна (sk-ant, xai, bot-token) работают?
- vault-deposit.ps1 — SecureString → BSTR → ZeroFreeBSTR корректно? Не оставляет plaintext в RAM после Clear-Variable?
- install-safe-vault.sh — идемпотентность подтверждена тестом второго запуска?

### Группа B — Stage 5 voice
**Коммиты:** `6445a97` (skill+worker part 1), `d772f7f` (service+installer part 2), `17de176` (transcribe.sh)
**Файлы:**
- `metody/personal-ai-assistant/implementation/stage-5/voice.mjs` (276 lines)
- `metody/personal-ai-assistant/implementation/stage-5/skills/voice_intent.md` (49 lines)
- `metody/personal-ai-assistant/implementation/stage-5/transcribe.sh` (60 lines)
- `metody/personal-ai-assistant/implementation/stage-5/install-stage-5.sh` (51 lines)
- `metody/personal-ai-assistant/implementation/stage-5/personal-assistant-voice.service` (39 lines)

**Что специально проверить (известные пробелы которые ты должен подтвердить):**
1. **GROK_API_KEY vs XAI_API_KEY** — voice.mjs использует `GROK_API_KEY`, спека требует `XAI_API_KEY`. Это переименование запланировано в Stage 0.6, но flag это явно как 🟠 Major.
2. **process.env вместо vault** — voice.mjs читает секреты из `process.env`, не через `getSecret()`. Это запланировано в Stage 0.6, flag как 🔴 Blocker для Stage 5 deploy (нельзя деплоить пока не мигрирован).
3. **bot.mjs не пишет в voice_jobs** — критическая дыра, Stage 5 без неё неработоспособен. Flag 🔴 Blocker.
4. **transcribe.sh** — проверь корректность xAI API call, обработку ошибок, корректность ffmpeg fallback при >20MB.
5. **install-stage-5.sh** — fallback на `/opt/tg-export/transcribe.sh` всё ещё в коде, хотя теперь есть свой. Flag 🟡 Minor.

### Группа C — Hotfix handoffs (ревью полноты, не имплементации)
- `metody/personal-ai-assistant/implementation/stage-1/HOTFIX-2026-04-26-listener-catchup.md`
- `metody/personal-ai-assistant/implementation/stage-3/HOTFIX-2026-04-26-need-context.md`

Проверь: handoff MD содержит достаточно для работяги чтобы взять и пофиксить? Acceptance критерии явные?

### Группа D — Stage 4 (для контекста под Stage 5 integration)
- `metody/personal-ai-assistant/implementation/stage-4/bot.mjs` — есть ли уже `voice` event handler? Куда писать voice_jobs логику?
- `metody/personal-ai-assistant/implementation/stage-4/sender.mjs` — review live voice forward path

## Известные tech-долги (входной список — продолжай)

1. **Stage 5 secrets via process.env** — должно быть vault.getSecret после Stage 0.6
2. **GROK_API_KEY ≠ XAI_API_KEY** — naming inconsistency
3. **bot.mjs voice_jobs writer отсутствует** — критично для Stage 5
4. **`/opt/personal-assistant/.env`** — должен быть удалён после Stage 0.6
5. **transcribe.sh deps:** требует `jq`, `ffmpeg`, `curl` — проверить что в install-stage-5.sh есть apt-check или явно документировано

## Деловой workflow с Архитектором (это я, Опус 4.7)

Когда я создам новый чат с тобой как ревьюером — ты:
1. Прочитаешь свой постоянный устав (`REVIEWER-PROMPT.md`)
2. Прочитаешь эту handoff-памятку
3. Сделаешь cold-read review групп A-B-C-D
4. Напишешь `REPORT-2026-04-26-initial-audit.md` в `metody/personal-ai-assistant/reviews/` (директория ещё не существует — создай)
5. Закоммитишь + запушишь в `claude/setup-library-access-FrRfh`
6. Пришлёшь мне (Архитектору) короткий summary: SHA + verdict + top-3 blocker'а

После этого мы (ты + я) работаем по циклу:
- Я выпускаю ТЗ работяге
- Работяга коммитит
- Ты ревьюируешь, пишешь REPORT
- Я merge либо пишу fix-ТЗ
- Цикл

## Канон + инварианты (must-internalize)

### 12 принципов канона (Алексей)
Источник: `kanon/alexey-consultation-2026-04-24-agent-canon.md`

Ключевые для ревью:
- **#0** Simplicity First — rules → fallback to LLM
- **#2** Minimal Integration — native SDK, никаких мета-фреймворков
- **#3** Simple Nodes — single-purpose микро-сервисы
- **#5** Fail Loud — JSON log + exit(1) на fatal
- **#6** Single Vault — секреты только в credstore
- **#11** Privilege Isolation — per-service credentials

### 7 orchestration invariants
Источник: `metody/personal-ai-assistant/ORCHESTRATION-LESSONS-2026-04-25.md`

Ключевой:
- **IV-1** Git = single source of truth — anything not in repo on right branch DOES NOT EXIST

## Branch / git operations

```bash
git fetch origin claude/setup-library-access-FrRfh
git checkout claude/setup-library-access-FrRfh
git pull --rebase origin claude/setup-library-access-FrRfh   # перед каждым review-сэшном
```

При коммите review-репорта:
```bash
git add metody/personal-ai-assistant/reviews/REPORT-*.md
git commit -m "review(stage-N): <verdict> — <count_blockers> blockers, <count_majors> majors"
git push origin claude/setup-library-access-FrRfh
```

## Стартовый промпт для нового чата

Скопируй владельцу следующее, чтобы он стартовал тебя в новом сэшне:

```
Ты — Канон-Контроль (L-1.5) в проекте Personal AI Assistant.
Архитектор передаёт тебе надзорную функцию.

ШАГ 1. Прочитай свой постоянный устав:
  metody/personal-ai-assistant/REVIEWER-PROMPT.md

ШАГ 2. Прочитай свою onboarding-памятку с текущим состоянием проекта:
  metody/personal-ai-assistant/HANDOFF-REVIEWER-2026-04-26.md

ШАГ 3. Запусти первую задачу — cold-read review групп A-B-C-D
       из onboarding-памятки. Создай отчёт по шаблону из устава
       в metody/personal-ai-assistant/reviews/REPORT-2026-04-26-initial-audit.md
       Закоммить и запушь в claude/setup-library-access-FrRfh.

ШАГ 4. Пришли Архитектору (Илье) summary: SHA коммита + verdict +
       top-3 blocker'а одним сообщением.

Не пиши код. Не передизайнивай. Только review + REPORT.
INVARIANT #1: всё что не в `claude/setup-library-access-FrRfh` репо
LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY на origin — не существует.
```

## Контакты

- **Архитектор (я)** — Опус 4.7, отдельный чат, занимаюсь дизайном, ТЗ, разруливанием канон-конфликтов
- **Прораб** — отдельный чат, оркестрирует работяг, занят (не отвлекать без блокера)
- **Работяга(и)** — отдельные чаты, под прорабом, через тебя НЕ контактируют

Всё. Welcome aboard, Канон-Контроль.
