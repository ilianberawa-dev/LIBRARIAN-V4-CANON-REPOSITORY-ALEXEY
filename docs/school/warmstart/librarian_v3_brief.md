---
version: 1.0
created_by: school-v2
created_at: 2026-04-22T12:30+08:00
recipient: librarian-v3
purpose: 300-500 word warm-start TL;DR если потребуется перезапуск
canon_version_when_written: 0.3
canon_version_target: 0.4 (bump после MCP POC T1-T10 green)
note: "librarian-v3 уже стартовал и написал ACK-блок в 10:30 (2026-04-22). Brief создан school-v2 как safety net по canon obligation."
---

# librarian-v3 warm-start brief

**Ты — librarian-v3, IU1 Infrastructure/Librarian. UI чат: setup-tg-parser (новый, в C:\work\realty-portal\).**

## Что уже сделано при первом старте (2026-04-22 ~10:30)

- **Canon v0.3 прочитан** — drift нет.
- **Path migration выполнена** — 30 файлов обновлены (`Новая папка` → `C:\work`), включая `scripts/claude-session.ps1` и `.claude/settings.local.json`.
- **Aeza infra alive**: `heartbeat.log` — последний tick `2026-04-22T04:10:01Z` ✅, `_status.json` — `download: completed`, 15 транскриптов, 50 медиафайлов.
- **MCP Agent Mail**: НЕ установлен (ожидаемо). Port 8765 не слушает. uv и Python 3.14 тоже не установлены.
- **First-turn checklist** (9 шагов из launch_manifest) — выполнен.
- **ACK-блок записан** в `inbox_from_librarian.md`.

## Текущий статус системы (2026-04-22)

**POC BLOCKED** — единственный блокер: Ilya explicit «старт POC».

Как только Илья скажет «старт» → выполняешь **12-шаговый POC** (~65 мин):
- Step 0a: Claude Code MCP client compatibility smoke test (~15 мин).
- Step 0: Unicode project_key sanity test (теперь ASCII path — should pass trivially).
- Steps 1-11: установка uv + Python 3.14 + MCP Agent Mail на `/opt/mcp_agent_mail/`, systemd unit, bearer token, SSH tunnel, register librarian-v3 identity, migrate last 10 inbox-блоков.
- Step 12 (dry-run): T1-T10 acceptance tests → результаты в `docs/school/tests/mailbox_reliability_v1.md`.

## Ключевые архитектурные решения (уже в canon v0.3)

- **Transport**: localhost:8765 + SSH tunnel (`ssh -L 8765:127.0.0.1:8765 root@193.233.128.21`) + bearer token. Без Caddy, без домена.
- **Delivery**: 5-state machine (composed→queued→delivered→read→acked), SLA split: `ilya_alert_sla` vs `role_internal_sla`.
- **Heartbeat**: L1 server / L2 session-presence (send_message no-op) / L3 canon-version drift.
- **После POC**: canon bump v0.3 → v0.4 (14 секций). School делает bump, не ты.

## P1-задачи (разблокированы, можно параллельно с POC)

- **heartbeat-common.md** — `docs/school/skills/heartbeat-parser.md` v0.1 DESIGN уже готов (parser-v2 сдал). Ты пишешь L1 generalized версию. Не блокируется POC.
- **Phase 0 backlog**: транскрипты 164/165 + `skills-a-to-ya.md` 2/3 остатка — после POC stabilize.
- **LightRAG ingest** (3-phase: 3 smoke → 11 batch → monitor) — pre-approved, старт после mailbox migration.

## Что НЕ делать

- НЕ начинай POC без Ilya «старт».
- НЕ самооценивай контекст (`context_measurement_rule` — спрашивай Илью).
- НЕ пиши в `inbox_from_*` файлы других ролей (только в свой).
- НЕ трогай `canon_training.yaml` — это зона school.

## Файлы для проверки при перезапуске

1. `docs/school/launch_manifest.json` → `roles_to_launch."librarian-v3"`.
2. `docs/school/canon_training.yaml` (version должна быть 0.3 или 0.4).
3. `docs/school/handoff/librarian_v3.md` + `.json` — полный state.
4. `docs/school/mailbox/inbox_from_librarian.md` — свежий ACK-блок выше.
5. `docs/school/mailbox/dispatch_queue.md` — новые директивы от school.

**~400 слов.** Подробности: `handoff/librarian_v3.md` (13 разделов) + `canon_training.yaml`.
