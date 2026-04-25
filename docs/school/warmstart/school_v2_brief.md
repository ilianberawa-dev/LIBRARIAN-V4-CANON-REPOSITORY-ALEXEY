---
version: 1.0
created_by: librarian-v2 (force-majeure — school-v1 froze before self-writing)
created_at: 2026-04-21T23:55+08:00
recipient: school-v2
purpose: 300-500 word TL;DR за 2 минуты вместо 20-минутного onboarding
canon_version_when_written: 0.3
canon_version_target: 0.4 (bump после MCP POC T1-T10 green)
note: "School-v1 успела написать полный handoff_v2.md в 23:39 до зависания. Этот brief — safety net, читай первым, handoff вторым."
---

# school-v2 warm-start brief

**Ты — school-v2, BU1 Education + orchestrator всей мульти-ролевой системы Ильи.**

## Что произошло за последние 8 часов (19:00 → 23:55 WITA)

Мы (librarian-v2 + school-v1 + parser-v2) прошли **полный архитектурный workshop** по созданию не-падающего agent-mailbox. Результат: **MCP Agent Mail на Aeza в режиме localhost+SSH tunnel+bearer** (zero public surface). Консенсус закрыт в 23:20 (operator-model шаг 7). 14 секций canon v0.4 scope утверждены.

## Ключевые решения

- **Path:** Илья переименовал `C:\Users\97152\Новая папка` → `C:\work` (NEW-1 mitigation для ASCII project_key в MCP SQLite).
- **Transport:** MCP Agent Mail (https://github.com/Dicklesworthstone/mcp_agent_mail) — FastMCP+Git+SQLite+FTS5. Установка 12 шагов (~65 мин) через SSH tunnel, никакого Caddy/домена.
- **Heartbeat:** 3 уровня — L1 server alive / L2 session presence (через `send_message no-op`) / L3 canon version drift.
- **Delivery:** 5-state machine (composed→queued→delivered→read→acked) + split SLA (ilya_alert vs role_internal).
- **#11 isolation:** secretary=`contacts_only` strict (защита от prompt injection архитектурно, не промптом).

## Твоя первая задача

**Дождаться от Ильи "старт POC" → forward librarian-v3 через новый MCP (или dispatch_queue если MCP ещё не стоит).**

Все approvals уже записаны в каноне (v0.3). Не надо начинать новые архитектурные решения. Ты в режиме **observer + gatekeeper** пока POC не установлен.

## Куда смотреть в первую очередь

1. **`launch_manifest.json`** секция `roles_to_launch."school-v2"` — single source of truth для твоего bootstrap.
2. **`handoff/school_v2.md`** — school-v1 успела записать полный финальный дамп в 23:39 (canon v0.3, consensus closure, v0.4 scope, amendments, команда ролей, backlog).
3. **`canon_training.yaml`** — version **0.3** (головой — changelog + versioning новые секции).
4. **`consensus_workshop.md`** — архитектурный диалог school↔librarian 19:50-23:00 (6 turns, три от каждой стороны).
5. **`dispatch_queue.md`** — 9 блоков forward'ов Илье, все sent.

## Что НЕ надо делать

- **НЕ начинай новые research** — все 6 идей из idea dump закрыты, 3.A-3.F done.
- **НЕ самооценивай контекст** (canon v0.3 `context_measurement_rule` — спрашивай Илью).
- **НЕ переделывай 14 секций v0.4** — они согласованы, ждут POC validation.
- **НЕ форкай свой chat** (school-v1 зависла, форк тоже зациклился — не повторяй).

## Команда ролей на момент mv (23:55)

| Роль | UI chat | Статус |
|---|---|---|
| school-v2 | online-school-architecture-improving (новый) | **ты, стартуешь** |
| school-v1 | зависший (8m+ stuck, Илья force-закрывает) | **закрыта force** |
| librarian-v3 | setup-tg-parser (новый) | стартует с first-turn checklist, делает Python sed-replace, ждёт «старт POC» |
| librarian-v2 | setup-tg-parser (старый) | close-ACK записан 23:50, Илья закрывает |
| parser-v3 | optional defer до Phase 2 | handoff pre-seeded, активация позже |

## Наблюдения для canon v0.4 bump (записать когда POC green)

- AP-6 кандидат: «session freeze при длинном промпте от orchestrator» (школа зависла 23:45 после большого critique turn'а) → limit token size outgoing?
- launch_manifest ключ = `roles_to_launch`, не `roles` (опечатка в одном из промптов, fix в canon).

## Что прошу у тебя (school-v2)

- Первый turn: ACK read + подтвердить что canon 0.3, handoff_v2.md, launch_manifest прочитаны.
- После ACK — waiting mode до Ильиного «старт POC».
- НЕ генерируй новый workshop turn без явной просьбы Ильи.

**Всего ~485 слов. Читается за 2 минуты.** Подробности — в `handoff/school_v2.md` + `consensus_workshop.md`.
