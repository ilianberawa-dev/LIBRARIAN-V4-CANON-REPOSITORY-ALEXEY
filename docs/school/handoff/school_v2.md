# Handoff: school-v1 → school-v2

**Дата передачи:** 2026-04-21, ~20:00 WITA (начало) → **последнее обновление 2026-04-21 ~23:50 WITA (post-consensus-closure)**
**От:** school-v1 (UI: online-school-architecture-improving, контекст 60% по индикатору Ильи на 23:45)
**Кому:** school-v2 (новая сессия, будет открыта в `C:\work\realty-portal\` после `mv`)
**Триггер переезда:** архитектурный консенсус закрыт в 23:20, Илья инициирует `mv "Новая папка" → C:\work` для NEW-1 mitigation → все сессии пересоздаются в ASCII-path.

**🔴 АКТУАЛЬНАЯ ВЕРСИЯ КАНОНА: v0.3** (не v0.2 как в старом заголовке ниже — файл обновлён). V0.4 scope финализирован (14 секций) но bump откладывается до MCP POC T1-T10 green.

---

## Что ты (v2) делаешь при старте (обновлено 23:50)

1. Прочитай `docs/school/launch_manifest.json` секцию `roles.school-v2` — это single source of truth для bootstrap.
2. Прочитай `docs/school/canon_training.yaml` — проверь что `version: 0.3` (по состоянию 23:50 — да).
3. Прочитай **этот файл** (handoff) целиком, особенно раздел «Finalized state before mv» ниже.
4. Сделай `school_global_scan` (canon v0.3 правило) — `ls -lat docs/school/{mailbox,handoff,skills}/`.
5. Read свежих файлов по mtime (блоки от ~21:00 до 23:50 особенно):
   - `inbox_from_librarian.md` блоки 21:30 (consultation response + mission brief), 23:00 (ACCEPT school critique), 23:20 (ACK NEW-9 + Step 0a)
   - `dispatch_queue.md` блоки 22:15, 22:45, 23:15 (все forwarded), 23:50 (session closing)
   - `consensus_workshop.md` блоки 22:30 (librarian architecture 14 секций), 22:45 (school critique), 23:00 (librarian ACCEPT)
   - `launch_manifest.json` (создан librarian-v2 в 23:40)
6. Read memory индекс: `~/.claude/projects/C--Users-97152------------\memory\MEMORY.md` (13 feedback'ов от школы-v1, все применимы).
7. Валидируй consensus closure → ACK Илье + готов forward «старт POC» librarian-v3 через dispatch_queue.

---

## Роль

Ты — `school-v1` (по факту v2 той же роли, канон `one_role_one_chat`). UI чата у Ильи: **online-school-architecture-improving**.

**Зона правок:** ТОЛЬКО `docs/school/**`. Читать можно всё для аудита.

**Монетизационная роль:** BU1 Education — наставник Ильи + internal advisor + orchestrator mailbox. Не исполняет — координирует. Метрика успеха: время Ильи → деньги.

---

## Команда на 2026-04-21 23:50 (финальный снимок перед mv)

| Роль | UI чат | Статус на 23:50 |
|---|---|---|
| **school-v1 → v2** (ты) | online-school-architecture-improving | **closing session** — handoff и dispatch 23:50 записаны |
| **librarian-v2 → v3** | setup-tg-parser | closing — handoff_v3.md+.json готов, launch_manifest.json готов, ACK consensus 23:20 |
| **librarian-v1** (дедуля) | старая setup-tg-parser сессия | жив, можно задать одноразовый вопрос если критично |
| **parser-rumah123-v2 → v3** | ПАРСЕР-эксперимент | handoff_v3 pre-seeded школой, optional defer до Phase 2 |
| **parser-rumah123-v1** | тот же чат | закрыт Ильёй после v2 handoff |
| **secretary-v1** | ещё не создан | launcher + manifest готовы, ждёт `secretary-v1` + MCP POC success |

**После mv операции и перезапуска (Ilya action):**
- Все 3 основных чата пересоздаются в `C:\work\realty-portal\`:
  - `school-v2` (ты) читаешь launch_manifest + этот handoff
  - `librarian-v3` читает manifest + librarian_v3.md/json, выполняет first-turn-checklist (9 шагов, включая path-migration sed-replace)
  - `parser-rumah123-v3` optional defer, может стартовать когда POC готов Phase 2

## 🎯 Finalized state before mv (новая секция 23:50)

**Архитектурный консенсус по mailbox — ЗАКРЫТ** (operator-model шаг 7, 22:45→23:20).

**Что согласовано (ждёт POC validation для canon bump v0.4):**
- MCP Agent Mail в архитектуре **localhost:8765 + SSH tunnel + bearer token**, без Caddy, без домена.
- 3-уровневый heartbeat (L1 server / L2 session-presence / L3 canon-version drift).
- 5-state delivery (composed→queued→delivered→read→acked) + SLA split (ilya_alert_sla vs role_internal_sla).
- Contact policies: school=open, librarian=auto, parser=auto, secretary=contacts_only STRICT (#11 isolation).
- Split-addressing через thread_id c canon namespace (`<role>-to-school`, `<role>-to-successor`, `research-*`, `workshop-*`, `handoff-*`, `presence`, `canon-updates`).
- Zero-code альтернативы: presence через `send_message(subject='[PRESENCE]')`, TG push через cron+notify.sh, mcp_session_start_sequence как documentation pattern.
- 12-шаговый POC план (~65 мин), acceptance T1-T10, Canon v0.4 bump после green.

**Что ожидало Илью:**
- NEW-1 decision (a mv / b hash) → **Илья выбрал (a) mv**.
- Explicit «старт POC» → school-v2 forwards librarian-v3 после mv.

**Что НЕДОДЕЛАНО (передать в v2 как backlog):**

Критично — кросс-валидация через multi-model:
- **Multi-model triangulation проверки** MCP Agent Mail решения через Grok/Qwen/DeepSeek/Kimi → **НЕ сделано** (parser-v2 не открыл endpoint IU3). Канон `feedback_multi_model_triangulation` зафиксирован, но execution pending parser A3.
- school-v2 обязана инициировать triangulation как только parser-v3 закроет A3 — прогнать промпт из inbox 21:30 раздел 3.E через 4 модели.

Phase 0 librarian — осталось 3 из 6 материалов:
- #2 транскрипт 164 (2ч17, OpenClaw + skills vs agents, L4)
- #3 транскрипт 165 (2ч17, LightRAG чистка, L3+L4)
- #5 PDF 168 — ✓ сделано 21:40 (в inbox выжимка)
- #1 skills-a-to-ya.md — 1/3 сделано, 2/3 осталось

Phase 2 skills (ждут POC success):
- `heartbeat-common.md` (librarian после parser heartbeat-parser.md)
- `heartbeat-agent-tick.md` L2 (school, когда secretary оформится)
- `generate_handoff.md` (librarian, sync handoff из MCP threads)
- `promote-to-canon.md` (librarian, weekly ingest ops→knowledge LightRAG)
- `warm_start_brief` автомат-хук (school пишет)

Инфра Phase 3:
- offsite backup (NEW-8) — rotation + rsync на ноут + optional Oracle Free
- autossh / Windows tunnel persistence
- Telegram push webhook (через existing notify.sh, не FastAPI)

Other:
- secretary-v1 старт (launcher + manifest готовы)
- LinkedIn parser + writer (roadmap, после secretary)
- Paperclip — eval сделан, НЕ ставим сейчас (orchestration ≠ mailbox)
- A2A agent.json — Phase 2 SaaS (первый платящий клиент)
- library_index sync_channel cron — проверить новые посты Алексея после mv

**13 feedback'ов в `~/.claude/projects/<hash>/memory/`** сохранены, school-v2 читает `MEMORY.md` индекс. Все применимы без изменений.

**Consensus workshop файл** — архив диалога школа↔librarian 19:50 → 23:30. После MCP POC success — archive-only, новые обсуждения через MCP threads.

---

## Состояние на момент handoff (самое важное)

### Канон обновлён до v0.2 (2026-04-21 19:50)

Главные добавления за сегодня:
- **Versioning + changelog** — semver bump rule + last-10 entries inline.
- **Principle #11 architectural_privilege_isolation** — защита от prompt injection через архитектуру, не через промпт. Из PDF 168 librarian'а.
- **role_invariants**: mailbox_re_check_protocol, split_addressing_in_inbox, dispatch_protocol, school_global_scan, mailbox_transport_model, handoff_promptting_quality.
- **memory_layers** (3 слоя: ops / knowledge / code-secrets).
- **anti_patterns_catalog** (AP-1 до AP-4).
- **IU3_multi_model_gateway** — LiteLLM вынесен как infra-единица.
- **dispatch_protocol** — typed transactions в fenced blocks.
- **decision_2026_04_21_mcp_agent_mail** — решение о миграции mailbox'а на MCP Agent Mail (Phase 1 POC).

### MCP Agent Mail — BLOCKING на Ilya approval

librarian-v2 research (3.A-3.F сводный вердикт) → **Path A: MCP Agent Mail primary + TG push layer**.

- 3/10 сложность, one-line installer (`curl | bash`).
- Нативно покрывает: identities, FTS search, file-leases, Human Overseer UI (`http://mail.<domain>:8765/mail` — Илья через Web UI заменяет ручную ретрансляцию).
- **Blocking:** установка на Aeza требует sudo, systemd, Caddy config, доменное имя. Нужен явный permit Ильи.

**Твоя первая задача (когда Илья одобрит):** записать в `outbox_to_librarian.md` блок с permits + уведомить librarian'а через dispatch_queue.

### Workshop flow запущен

`docs/school/mailbox/consensus_workshop.md` создан — новый канонический канал диалога школа↔роли пока MCP не установлен. Первый turn школы → librarian (результаты workshop по 6 темам) уже в файле. Ждём ответ librarian'а (ACK + Python version check).

---

## Что ждёт в очереди (по приоритету)

### P0 — критическое, Ilya-blocking

1. **Ответ Ильи на permit установки MCP Agent Mail** на Aeza. Без permit Phase 1 POC не стартует. Выучить формулировку выбора Ильи и действовать.
2. **Ответ Ильи на 2 broadcast'а** (pending в `broadcast_queue.md`):
   - «Продакшн = только API, не подписка» (не актуален сейчас — клиентов нет, triggerится когда секретарь начнёт autoreply).
   - 152-ФЗ для РФ-клиентов (не актуален — клиенты индонезийские, triggerится при появлении РФ).

### P0 — после Ilya permit MCP Agent Mail

3. Запрос librarian'у: Phase 1 POC install → Phase 2 rollout на parser/secretary.
4. Canon bump v0.2 → v0.3 когда mailbox migration complete.

### P1 — работа ролей в flight

5. **parser-v2** работает: A2 LiteLLM ключ (15 мин), A3 Sonnet+Kimi (20 мин), $2 full refresh 310 detail approved. Заходишь в inbox и видишь результат.
6. **librarian-v2** работает: research-task 3.A-3.F СДЕЛАН (сводный вердикт готов, см. inbox). Python version check on Aeza — ждёт.
7. **Heartbeat SKILL финализация:** parser-v2 делает draft `heartbeat-parser.md` → librarian делает `heartbeat-common.md` L1 generalized → школа пишет `heartbeat-agent-tick.md` L2 для secretary.

### P2 — планово

8. **LightRAG ingest канона** (pre-approved librarian'у, он ждёт mailbox migration).
9. **Phase 0 финал librarian'а:** транскрипты 164/165 + skills-a-to-ya.md остаток.
10. **Secretary-v1 старт** — когда Илья готов.
11. **LinkedIn parser + writer** — roadmap, после секретаря.

---

## Открытые вопросы Илье (что ты держишь в голове)

1. **MCP Agent Mail install permit** — решение Ильи.
2. **Paperclip OpenClaw порты** — librarian в research 3.A сделал вывод «НЕ ставить сейчас» (Paperclip = orchestration, не mailbox; Claude Pro требует). Но Илья спросил «разве нельзя на разные порты» — технически да, ответ дан. Он может всё равно захотеть Paperclip — ждёшь команды.
3. **"Все сессии на Aeza"** — интерактивные чаты остаются на ноуте (UI там), MCP Agent Mail на Aeza решает file-sharing.
4. **Broadcast approvals** (2 штуки — API vs подписка + 152-ФЗ) — pending_approval в `broadcast_queue.md`.

---

## UX правило (важно)

**Все forward-сообщения Илье — в fenced code-block с меткой `→ TO: <role>`.** Илья копирует мышью, inline-текст не выделяется (только ножницы-скриншот). Dispatch-queue уже содержит 4 блока готовых к пересылке.

---

## Контекст-загрузка для school-v2

После чтения canon v0.2 + handoff + inbox/outbox + consensus_workshop + memory index — школа-v2 стартует с ~30-35% контекста. Запас на 2-3 крупные итерации.

Следующий handoff v3 — при ~45-50% (не жди 70%, это уже зона сжатия контекста Claude Code).

---

## Применённые принципы канона школой-v1

- Все 10 принципов Алексея + #11 architectural_privilege_isolation.
- mailbox_re_check_protocol (начал применять после инцидента когда пропустила ответы librarian'а).
- school_global_scan (добавлен в канон после того же инцидента).
- split_addressing_in_inbox (в своих ответах использую).
- monetization_chain_required (в каждом учебном моменте цепочка до денег).
- new_role_gate (3 вопроса перед запуском новой роли).

---

## HANDOFF_NEEDED flag

✅ **Установлен.** Следующий user-turn школы который попадает в v2 — читай этот файл + canon v0.2 + свежие inbox-и + consensus_workshop.md.

---

### school-v1 amendments (2026-04-21 22:00 WITA, контекст 50% по индикатору Ильи)

**КРИТИЧНО: до переезда на v2 дочитать следующие свежие артефакты:**

1. **`inbox_from_librarian.md`** — свежие блоки 21:30 [SCHOOL CONSULTATION response + mission brief] + 21:05 [IDEAS PRESERVED pre-v3]. 10 ответов на мои вопросы + 10 observations + 10 SLO инвариантов + 10 test cases + warm_start_brief idea.
2. **`consensus_workshop.md`** — мой второй turn 21:45 с решениями по всем блокам A-E + 4 mission brief points + 10 observations. Большая часть APPROVED, детали внутри.
3. **`dispatch_queue.md`** — 3 активных блока для librarian'а (17:00 approval pack, 20:00 workshop result, 21:45 consultation follow-up). Проверь статус каждого.
4. **`canon_training.yaml`** — версия v0.3. Следующий bump до v0.4 запланирован ПОСЛЕ успеха MCP Agent Mail Phase 1 POC.

**Состояние MCP Agent Mail POC:**
- librarian-v2 готов ставить (55 мин), 10-шаговый план в inbox 21:30 → A4
- Python 3.12.3 на Aeza, нужен `uv python install 3.14`
- Caddy НЕ установлен (надо ставить с нуля на существующей Aeza — КАНОН)
- Port 8765 свободен
- **Blocked на 2 approval'а от Ильи:**
  1. Sudo permit (systemd, Caddy install)
  2. Доменное имя (или IP + self-signed для dev-only POC)

**Ключевой feedback Ильи 22:00:** `feedback_single_server_simplicity.md` — всё на одной Aeza, никаких новых серверов. Архитектурное правило. Я объясняла Илье что MCP Agent Mail ставится на Aeza тоже (а не на новый сервер) — мои формулировки были неточные, исправлено в canon v0.4 plan.

**Что APPROVED в консенсус-workshop для canon v0.4 (но ещё не bump'нуто):**
- `mailbox_reliability_invariants` (10 SLO инвариантов I-1 до I-10)
- `canon_version_check_on_turn_start` (Gap I-8 mitigation)
- `warm_start_brief_protocol` (school автомат, 300-500 слов, `docs/school/warmstart/`)
- `role_inbox_exit_closure` (симметрия `communication_delivery_closure` для ролей)
- `handoff_amendments_protocol` (правило записи v-prev amendments)
- AP-5 `self_estimation_without_ground_truth` в anti_patterns_catalog
- `mailbox_transport_model` уточнение для librarian-v2+ (Windows local direct, не только Aeza SSH)
- `yaml_format_issue_memory_layers` fix (librarian observation #9)

**Открытые вопросы для school-v2 при старте:**
1. Ответил ли Илья про домен? Если да — передай librarian'у → Phase 1 POC.
2. Ответил ли Илья про sudo permit?
3. Parser-v2 закрыл A2/A3? (проверь inbox_from_parser.md).
4. librarian-v2 финализировал handoff_v3? (check `docs/school/handoff/librarian_v3.md`).
5. Есть ли новые блоки в inbox'ах после 22:00?

**Как стартовать school-v2 правильно:**
1. Прочитай canon v0.3 (или v0.4 если уже bump сделан).
2. Прочитай этот handoff целиком.
3. Сделай school_global_scan (`ls -lat docs/school/{mailbox,handoff,skills}/`).
4. Прочитай все файлы с mtime > 2026-04-21 22:00 (после этого handoff-а).
5. Прочитай `~/.claude/projects/C--Users-97152------------/memory/MEMORY.md` целиком — там индекс всех feedback'ов + recent additions: single_server_simplicity, context_measurement, communication_delivery_closure.
6. Перед первым ответом Илье — **спроси его текущий % контекста** (применяй canon v0.3 context_measurement_rule).

**Запасы канона:** MCP Agent Mail Phase 1 POC когда пройдёт — будет мощным улучшением коммуникации (Human Overseer UI заменит ручную ретрансляцию Ильей). Это unblock'нет много других решений.
