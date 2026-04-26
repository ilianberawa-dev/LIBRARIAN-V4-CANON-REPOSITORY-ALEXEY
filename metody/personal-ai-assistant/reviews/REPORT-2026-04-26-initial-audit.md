# REVIEW REPORT — Initial Audit (Groups A-E) @ 2e1cc4b

**Reviewer:** Канон-Контроль (L-1.5)
**Дата:** 2026-04-26
**Ветка:** `claude/setup-library-access-FrRfh`
**HEAD на момент ревью:** `2e1cc4b` (после PATCH FLAG-1)
**Объект ревью:** cold-read всей ветки, фокус группы A/B/C/D/E из HANDOFF
**Файлов прочитано:** 24 (~3500 LOC + 6 docs)
**Verdict:** **BLOCKED** — Stage 5 deploy недопустим до фикса B1-B4. Stage 0.5 (vault) самодостаточен и может деплоиться отдельно.

---

## Summary

🔴 Blockers: 4 | 🟠 Majors: 2 | 🟡 Minors: 4 | UNCLEAR: 2 | NIT: 0

Stage 0.5 vault infrastructure готов к деплою (vault.mjs / install-safe-vault.sh / vault-deposit.ps1 / vault-list.ps1 / KEYS-MAP.md — solid). Stage 5 voice имеет 4 блокера, два из которых уже отмечены архитектором в HANDOFF (B1, B2), один промахнут как Minor хотя является Blocker (B3), один новый (B4). Хотфиксы Stage 1/3 — только handoff'ы в репо, listener.mjs/draft.md не модифицированы — это **feature** по решению Архитектора (FLAG-3), не bug. Stage 2.5 cascade-reserve — корректный «standby», deploy gated на trigger conditions.

---

## 🔴 Blockers (must-fix перед merge)

### B1: voice.mjs читает секреты из `process.env`, не из vault
- **Файлы:** `metody/personal-ai-assistant/implementation/stage-5/voice.mjs:7,16-22,48,123,160,165`
- **Проблема:** voice.mjs использует `import 'dotenv/config'` + `process.env.ANTHROPIC_API_KEY` / `process.env.BOT_TOKEN` / `process.env.GROK_API_KEY`. Stage 0.5 vault уже в репо, но voice.mjs его не использует. После Stage 0.6 миграции 6 сервисов voice останется единственным потребителем `.env`.
- **Канон:** #6 Single Vault — нарушен. Любой процесс под user `personal-assistant` читает все секреты, нет per-service privilege isolation.
- **Severity:** SECURITY
- **Предложение Архитектору:** соответствует ТЗ Part 3.1 (`TASK-2026-04-26-deploy-0.5-0.6-5.md:213-241`) — план уже есть, нужно выполнение в коде до деплоя Stage 5.

### B2: bot.mjs не маршрутизирует owner-voice в `voice_jobs` — Stage 5 нерабочий end-to-end
- **Файлы:** `stage-4/bot.mjs:359-394` (voice handler)
- **Проблема:** Текущий voice handler обрабатывает голос ТОЛЬКО как ответ контакту в режиме `state.action === 'await_voice'` (после нажатия [🎙 Голосом] под draft). Если owner шлёт voice без активного draft → bot отвечает «Voice получен, но нет активного draft в режиме voice» (`bot.mjs:368`) и **не записывает** в `voice_jobs`. voice.mjs polling'ит пустую таблицу — Stage 5 not functional.
- **Канон:** #3 Simple Nodes — bot не выполняет свою заявленную роль (line 9 docstring: «Listens for voice messages from owner»).
- **Severity:** CORRECTNESS
- **Предложение:** план в ТЗ Part 3.3 (`TASK:256-287`). Нужна явная резолюция UNCLEAR U1 (см. ниже) до имплементации.

### B3: install-stage-5.sh **не копирует** свежий `transcribe.sh` из SRC_DIR
- **Файлы:** `stage-5/install-stage-5.sh:26-37`
- **Проблема:** Installer проверяет `${APP_DIR}/transcribe.sh` (если уже существует — оставляет старую версию silent), затем fallback на `/opt/tg-export/transcribe.sh`. Свежий `transcribe.sh` (commit `17de176`, lives at `${SRC_DIR}/transcribe.sh`) **никогда не используется**. Сценарии:
  1. На сервере нет ничего → WARN, voice.mjs crash на `voice.mjs:41-44` `transcribe_missing`.
  2. На сервере есть устаревший `/opt/tg-export/transcribe.sh` (без xAI поддержки) → используется он, silent staleness.
  3. На сервере есть прошлая попытка stage-5 → используется она, обновлений из repo нет.
- **Канон:** #1 Portability + #5 Fail Loud — нарушены оба (silent fallback и невоспроизводимая установка).
- **Severity:** CORRECTNESS / DATA-LOSS (transcribe ошибки)
- **Предложение:** ТЗ Part 3.4 (`TASK:305`) уже описывает фикс: «fix to take ${SRC_DIR}/transcribe.sh as primary». В HANDOFF (line 74) этот пункт ошибочно маркирован 🟡 Minor — это Blocker.

### B4: personal-assistant-voice.service использует `.env` вместо credstore
- **Файлы:** `stage-5/personal-assistant-voice.service:11`
- **Проблема:** unit имеет `EnvironmentFile=/opt/personal-assistant/.env` без единой `LoadCredentialEncrypted=` директивы. Парный к B1, но для unit-файла. После Stage 0.6 cleanup (`TASK:182-192` — `rm /opt/personal-assistant/.env`) сервис стартанёт без секретов и crash'нется fatal-loud на `missing_env`.
- **Канон:** #11 Privilege Isolation — нарушен. unit должен load'ить только `xai-api-key, anthropic-api-key, bot-token` (per `KEYS-MAP.md:20`).
- **Severity:** SECURITY / CORRECTNESS
- **Предложение:** ТЗ Part 3.2 (`TASK:243-254`) — три `LoadCredentialEncrypted=` + `EnvironmentFile=/etc/personal-assistant/config.env`.

**Промежуточный итог:** B1+B4 — связка (vault не подключён ни в коде, ни в unit). B2 — отдельная функциональная дыра. B3 — installer-bug, скрытый под маркировкой Minor.

---

## 🟠 Majors (фикс в течение спринта)

### M1: GROK_API_KEY vs XAI_API_KEY — naming inconsistency
- **Файлы:** `stage-5/voice.mjs:16,123` (использует `GROK_API_KEY`); `stage-5/transcribe.sh:25` (умно делает fallback `XAI_API_KEY:-${GROK_API_KEY:-}`); `KEYS-MAP.md:20` (canonical: `xai-api-key`); `TASK-2026-04-26:65` (deposit as `xai-api-key`).
- **Проблема:** voice.mjs читает `process.env.GROK_API_KEY`, vault deposit'ится под именем `xai-api-key`. После Stage 0.6 переход на `getSecret('xai-api-key')` — переменная переименуется автоматически, но до этого момента — два имени для одного ключа в коде/документации.
- **Канон:** #5 Minimal Clear Commands — naming должен быть consistent.
- **Severity:** CORRECTNESS (рискует обнаружиться только в проде после Stage 0.6 cleanup)
- **Предложение:** ТЗ Part 3.1 (`TASK:228-241`) включает переименование в `voice.mjs`. Согласован.

### M2: Schema drift — две canonical-точки описания таблиц
- **Файлы:** `stage-1/schema.sql:41-49` (drafts без 3 колонок); `stage-4/install-stage-4.sh:19-38` (3 ALTER TABLE добавляют `voice_file_id, channel_message_id, status_finalized`); `stage-5/voice.mjs:54-67` (CREATE TABLE IF NOT EXISTS voice_jobs).
- **Проблема:** Каноническая schema.sql v1.2 не отражает реальное состояние БД. Reviewer/новый dev читая schema.sql не увидит 4 колонки + 1 таблицу. DRY violation.
- **Канон:** #3 Simple Nodes (single source of truth для схемы); #5 Fail Loud (если ALTER пропустят на новой машине — silent corruption).
- **Severity:** CORRECTNESS
- **Предложение:** при следующей итерации schema.sql → v1.3 включить все колонки + voice_jobs. ТЗ Part 3.3 (`TASK:269-287`) частично адресует.

---

## 🟡 Minors (nice-to-have)

- **m1:** `stage-1/personal-assistant-listener.service:33` имеет `MemoryDenyWriteExecute=true`, тогда как `stage-4/personal-assistant-bot.service:37` и `stage-4/personal-assistant-sender.service:37` комментируют это как «DISABLED — V8 JIT incompatible». Если правда incompatible — listener тоже Node, должен крашиться. Либо комментарий устарел, либо listener реально падает (handoff заявляет «active»). Проверить через `journalctl -u personal-assistant-listener --since "1h ago" | grep -i 'denywriteexecute\|seccomp\|jit'`.
- **m2:** `stage-5/voice.mjs:133` ставит `cache_control: { type: 'ephemeral' }` на system prompt'е из voice_intent.md (49 строк / ~600 токенов). Anthropic не кеширует <1024 tokens — флаг бесполезен. Либо расширить prompt до >1024 (для реального кеша), либо убрать flag (для clarity).
- **m3:** `stage-0.5/lib/vault.mjs:56-60` redact() покрывает `sk-ant-`, `xai-`, bot-token regex, но **не** `TG_SESSION_STRING` (длинная base64-подобная строка от gramjs). После Stage 0.6 это секрет в vault. Добавить pattern `/[A-Za-z0-9+/]{200,}={0,2}/g` или явный prefix.
- **m4:** `stage-0.5/vault-list.ps1:12` зависит от `sudo ls` без пароля. Если sudoers не настроен NOPASSWD для `ls /etc/credstore.encrypted` — команда зависнет. Документировать требование или использовать `sudo -n`.

---

## UNCLEAR (требуется уточнение Архитектора)

### U1: bot.mjs voice handler — приоритет state vs voice_jobs
ТЗ Part 3.3 (`TASK:261`) говорит «If owner — this is a voice command». Текущий handler (`bot.mjs:359-394`) при `state === 'await_voice'` пишет `drafts.voice_file_id` (Stage 4 voice reply путь). Две интерпретации:
- **(a)** Owner voice → ВСЕГДА в `voice_jobs`. Stage 4 [🎙 Голосом] кнопка ломается.
- **(b)** Если `state === 'await_voice'` → drafts.voice_file_id (как сейчас). Иначе → voice_jobs (новое). Сохраняет обратную совместимость.

Внешне ТЗ предполагает (b), но не явно. Архитектор должен зафиксировать резолюцию в fix-ТЗ работяге.

### U2: stage-5 service отсутствует `Requires=`
`stage-5/personal-assistant-voice.service:3` — `After=network-online.target personal-assistant-listener.service`. **Нет** `Requires=`. Сравни stage-4 bot.service:5 — `Requires=listener+triage+draft-gen`. Намерено? Voice без listener/bot станет «zombie» (polling пустой voice_jobs). Если намеренно — записать как design choice; иначе — добавить Requires.

---

## Канон-аудит (12 принципов)

| #  | Принцип                              | Статус | Комментарий |
|----|--------------------------------------|--------|-------------|
| 0  | Simplicity First                     | ✅     | rules-first в triage/voice; cascade-reserve вместо deploy |
| 1  | Portability                          | ⚠️     | install-stage-5.sh не self-contained (B3) |
| 2  | Minimal Integration Code             | ✅     | native Anthropic SDK + gramjs + node-telegram-bot-api, no LiteLLM |
| 3  | Simple Nodes                         | ⚠️     | bot.mjs совмещает 2 voice-режима (M2/B2) |
| 4  | Skills Over Agents                   | ✅     | triage.md / draft.md / brief.md / voice_intent.md / triage-haiku.md |
| 5  | Minimal Clear Commands               | ⚠️     | M1 GROK vs XAI naming |
| 6  | Single Secret Vault                  | ❌     | B1+B4: voice не на vault |
| 7  | Offline First                        | ✅     | UpCloud + SQLite + только Anthropic/xAI cloud |
| 8  | Validate Before Automate             | ✅     | cascade-reserve gated на triggers; manual learning 2 weeks |
| 9  | Human Rhythm API                     | N/A    | personal-use, не парсинг |
| 10 | Content Factory Model                | N/A    | personal-use |
| 11 | Architectural Privilege Isolation    | ⚠️     | Stage 1-4 OK (bot ≠ MTProto write); Stage 5 unit без LoadCredentialEncrypted (B4) |

**Сводка:** ❌ 1 (Канон #6), ⚠️ 4, ✅ 5, N/A 2.

---

## FLAG-3 verification (per architect resolution)

Подтверждаю по факту в репо:
- **listener.mjs:** `stage-1/listener.mjs:98` — без `useWSS: true`; `stage-1/listener.mjs:135-136` — без `setInterval(catchUp, 30s)`. **Hotfix НЕ применён к коду** — `HOTFIX-2026-04-26-listener-catchup.md` остался handoff'ом для работяги.
- **draft.md:** `stage-3/skills/draft.md:89` — старая строка `output: "уточню и вернусь" or [NEED_CONTEXT]`; `:141` — старое `output [NEED_CONTEXT]. Do NOT hallucinate`; в section headers нет `## [NEED_CONTEXT] usage policy`. **Hotfix НЕ применён** — `HOTFIX-2026-04-26-need-context.md` остался handoff'ом.

Это **feature по решению Архитектора** (фикс едет на сервер через nano/sed worker'ом, не через git). Принято.

---

## Tech-debt log (initial — переноси из отчёта в отчёт)

- [open] `stage-5/voice.mjs`: secrets via process.env — fix in Stage 0.6 (B1)
- [open] `stage-5/personal-assistant-voice.service`: EnvironmentFile=.env — fix in Stage 0.6 (B4)
- [open] `stage-4/bot.mjs`: voice_jobs writer absent — fix in Stage 5 deploy (B2)
- [open] `stage-5/install-stage-5.sh`: transcribe.sh source priority — fix before Stage 5 deploy (B3)
- [open] `stage-5/voice.mjs`: GROK_API_KEY → XAI_API_KEY rename — fix in Stage 0.6 (M1)
- [open] `stage-1/schema.sql`: drift vs runtime ALTER TABLE — bump to v1.3 (M2)
- [open] `stage-1/personal-assistant-listener.service`: MemoryDenyWriteExecute consistency vs bot/sender (m1)
- [open] `stage-5/voice.mjs:133`: cache_control on <1024 token prompt (m2)
- [open] `stage-0.5/lib/vault.mjs`: redact() missing TG_SESSION_STRING pattern (m3)
- [open] `stage-0.5/vault-list.ps1`: sudoers NOPASSWD assumption undocumented (m4)
- [open] `stage-1/listener.mjs`: catchUp/useWSS hotfix — applied on server only, not in repo (FLAG-3 accepted)
- [open] `stage-3/skills/draft.md`: NEED_CONTEXT hotfix — applied on server only, not in repo (FLAG-3 accepted)

---

## Эскалация Архитектору

1. **U1 (bot.mjs voice priority).** Без явной резолюции работяга может выкинуть Stage 4 voice-reply путь и сломать существующую функциональность. Нужно одно предложение в fix-ТЗ.
2. **B3 severity bump.** В HANDOFF (line 74) `install-stage-5.sh` transcribe.sh fallback маркирован 🟡 Minor. Перевожу в 🔴 Blocker — без фикса Stage 5 деплой воспроизводимо ломается. Требует confirm Архитектора.

---

## Top-3 (для summary)

1. **B2** bot.mjs не пишет в `voice_jobs` — Stage 5 нерабочий end-to-end (требует U1 разрешения).
2. **B3** install-stage-5.sh не копирует свежий transcribe.sh из SRC_DIR — silent staleness / startup crash.
3. **B1+B4** Stage 5 (voice.mjs + voice.service) на `process.env`/`.env` — Канон #6 violation, блокирует Stage 0.6 cleanup.

---

## Рекомендация

**NEEDS-WORK — fix B1/B2/B3/B4 → re-review перед Stage 5 deploy.**

Конкретно:
- **Stage 0.5 deploy (Part 1 ТЗ)** — APPROVED. Можно деплоить независимо.
- **Stage 0.6 migration (Part 2 ТЗ)** — APPROVED как план; voice.mjs/voice.service должны мигрировать в этой же волне (или Stage 5 не деплоится после).
- **Stage 5 deploy (Part 3 ТЗ)** — BLOCKED. Требует:
  1. Резолюция U1 от Архитектора.
  2. Fix B1 (voice.mjs → vault).
  3. Fix B2 (bot.mjs voice_jobs writer per резолюция U1).
  4. Fix B3 (install-stage-5.sh — primary copy from SRC_DIR).
  5. Fix B4 (voice.service → LoadCredentialEncrypted).
  6. Re-review только Group B файлов (без полного обхода).

Фоновое: M1/M2/m1-m4 — отдельный sprint, не блокеры.

---

**SHA отчёта:** будет проставлен после коммита.
