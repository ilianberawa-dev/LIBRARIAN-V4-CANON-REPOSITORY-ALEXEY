# Handoff: librarian-v2 → librarian-v3

**Дата передачи:** 2026-04-21, ~22:00 WITA
**От:** librarian-v2 (UI-chat: setup-tg-parser, organized handoff, не emergency)
**Кому:** librarian-v3 (новая сессия после Ilya закроет v2)
**Триггер переезда:** school application `handoff_promptting_quality` триггер (50% UI-контекст), organized prep + consensus workshop с school завершён.

---

## 1. Header

- **UI-chat name:** `setup-tg-parser` (продолжение после v2; Илья закроет v2 после твоего прихода).
- **Role:** `librarian-v3` (`librarian`, IU1 Infrastructure Unit).
- **Canon version at handoff write:** `0.3` (2026-04-21T20:30+08:00).
- **Handoff type:** organized (НЕ emergency draft — v2 успела написать сама).
- **Kontext measurement:** **v2 self-reported отказ** — не оценивает по `context_measurement_rule` canon v0.3. Последний известный % — Илья последний раз сказал 25% в turn'е 21:00, точный на момент handoff-write неизвестен.

---

## 2. Роль + BU + monetization

- **BU/IU:** `IU1_librarian` (knowledge asset, не продаётся, снижает cost всех BU).
- **Монетизационная роль:** research done once, reused many times. Без тебя:
  - school слепа (канон Алексея = её учебник).
  - parser не знает эталона human-rhythm.
  - secretary не видит msg_178 и Paperclip msg_147.
  - linkedin-writer не знает msg_101-104 content-factory.
- Экономия — часы Ильи → деньги. При rollout MCP Agent Mail + warm_start_brief + LightRAG: ~$300/год базово, $1500/год при 5 ролях.

---

## 3. Read-on-start (обязательный порядок)

1. **`docs/school/canon_training.yaml`** — полностью. Сверь `version` с `4. last_read_canon_version` ниже. Если mismatch → full re-read + записать в inbox как canon drift detection event (gap I-8 mitigation).
2. **`docs/school/mailbox/dispatch_queue.md`** — свежие блоки от school (последний 21:45 + позже если есть).
3. **`docs/school/mailbox/consensus_workshop.md`** — все turns (особенно школьный 21:45 follow-up).
4. **`docs/school/mailbox/outbox_to_librarian.md`** — директивы, включая RESEARCH TASK 3.A-3.F (уже выполнен v2).
5. **Этот handoff** — целиком.
6. **`docs/school/mailbox/inbox_from_librarian.md`** — последние 5 блоков (17:05 RE-CHECK, P0.2 PDF, P0.1 library, 19:30 research, 19:45 idea dump, 21:05 ideas_preserved, 21:30 school consultation response + mission brief, 22:00 ACK).
7. **`docs/school/warmstart/librarian_v3_brief.md`** — если существует (school auto-generates при Ilya approval твоего launch).

---

## 4. last_read_canon_version

**0.3** (2026-04-21T20:30+08:00). При старте v3:
- Прочитай header `canon_training.yaml` строка 1 → `version:`.
- Если не `0.3` → full re-read всего yaml + ack в inbox: `canon_drift_detected: v2_last=0.3, v3_first=<X.Y>, re-read complete`.
- Протокол уже утверждён как `canon_version_check_on_turn_start` (будет в canon v0.4 после POC).

### 4a. Context snapshot (новое поле по canon v0.3+)

```yaml
spawned_at_ui_context: UNKNOWN      # Claude Code UI-индикатор не доступен агенту
ilya_last_reported: "25% at 21:00"   # последний известный Илья-измеренный
librarian_self_estimate: NEVER       # самооценка запрещена canon v0.3 context_measurement_rule
handoff_trigger_observed_at: "21:00 reading 3 school files, decision taken after 21:30 consultation turn"
```

---

## 5. Research Task 3.A-3.F — STATE

Все 6 задач **выполнены и approved school-v1** (см. `consensus_workshop.md` 21:45).

| Задача | Вердикт | Артефакты |
|---|---|---|
| **3.A Paperclip eval** | ❌ не заменяет mailbox, CEO-модель не наш use-case. Сложность 4-5/10, hardcoded Claude Pro. | `/opt/tg-export/_paperclip_unpacked/` на Aeza, `install_paperclip.sh` прочитан целиком, README сервер+локально прочитаны. |
| **3.B MCP Agent Mail** | ✅ **PRIMARY mailbox** — прямое попадание, 3/10 сложность, Git+SQLite FTS5, file-leases, Human Overseer UI, Ed25519 export. | `/opt/tg-export/_mcp_mail_eval/` на Aeza (git clone --depth 1), SKILL.md + README + AGENT_FRIENDLINESS + compose прочитаны. |
| **3.C A2A Google/LF** | ⏸ отложить до Phase 2 SaaS (когда secretary начнёт discover external services). | Knowledge-only, без code-артефактов. |
| **3.D CrewAI/LangGraph/AutoGen** | ❌ требуют Python-dev, Илья non-dev, регресс по канону #2. | Knowledge-only. |
| **3.E Multi-model prompt draft** | ✅ draft готов (в inbox block 19:30), ждёт LiteLLM endpoint parser-v2 (A3 task у него). | В inbox 19:30 секция 3.E. |
| **3.F TG-chat fallback** | 🔀 только как notify layer над MCP Agent Mail на urgent-сообщения Ильи в Telegram. | Knowledge-only. |

**Сводный вердикт:** Path A = MCP Agent Mail primary + TG push layer. APPROVED школой (см. consensus_workshop 21:45).

---

## 6. Workshop decisions v0.3 — где зашиты в каноне

| Idea (из idea dump 19:45) | Статус | Canon location | Строки |
|---|---|---|---|
| #1 Canon versioning + changelog | ✅ v0.2 | `versioning` + `changelog` секции | `canon_training.yaml:6-33` |
| #2 2-слойная memory | ✅ концептуально | `memory_layers.ops/knowledge/code_and_secrets` | `canon_training.yaml:146-162` |
| #3 Heartbeat SKILL finalization | ✅ последовательность parser→librarian→secretary | `heartbeat_policy` (остаётся UNDER_RESEARCH до draft) | `canon_training.yaml:404-437` |
| #4 IU3 multi-model gateway | ✅ инфраструктурная единица | `infrastructure_units.IU3_multi_model_gateway` | `canon_training.yaml:63-69` |
| #5 Anti-patterns catalog | ✅ AP-1 до AP-4 | `role_invariants.anti_patterns_catalog` | `canon_training.yaml:164-183` |
| #6 Dispatch_protocol v2 | ⏸ ОТЛОЖЕНО (MCP решает нативно) | remains as is | `canon_training.yaml:249-304` |
| **Принцип #11** architectural_privilege_isolation | ✅ v0.2 отдельный принцип | `principles_alexey[11]` | `canon_training.yaml:390-398` |
| **`mailbox_re_check_protocol`** | ✅ v0.2 | `role_invariants.mailbox_re_check_protocol` | `canon_training.yaml:119-124` |
| **`split_addressing_in_inbox`** | ✅ v0.2 | `role_invariants.split_addressing_in_inbox` | `canon_training.yaml:234-247` |
| **`dispatch_protocol`** | ✅ v0.2 | отдельная секция | `canon_training.yaml:249-304` |
| **`mailbox_transport_model`** | ✅ v0.2 | `role_invariants.mailbox_transport_model` | `canon_training.yaml:185-199` |
| **`school_global_scan`** | ✅ v0.2 | `role_invariants.school_global_scan` | `canon_training.yaml:217-226` |
| **`communication_delivery_closure`** | ✅ v0.3 | `role_invariants.communication_delivery_closure` | `canon_training.yaml:134-145` |
| **`context_measurement_rule`** | ✅ v0.3 | `role_invariants.context_measurement_rule` | `canon_training.yaml:126-132` |

### Все 4 mission brief пункта — APPROVED (ждут canon v0.4 bump)

- ✅ 10 инвариантов SLO `mailbox_reliability_invariants`.
- ✅ 10 test cases T1-T10 как acceptance для POC.
- ✅ Gap I-8 mitigation `canon_version_check_on_turn_start`.
- ✅ warm_start_brief owner = school, 300-500 слов, `docs/school/warmstart/<role>_v<N>_brief.md`.

### Все 10 ideas_preserved observations — APPROVED для v0.4

- #1 context template в handoff (применено в разделе 4a выше).
- #2 symmetric `role_inbox_exit_closure` (📤 Выход блок в inbox).
- #3 librarian имеет право IU3 validation (когда parser endpoint готов).
- #4 `mailbox_transport_model` уточнение `librarian-v2+: Windows local direct`.
- #5 AP-5 `self_estimation_without_ground_truth` (anti_patterns catalog).
- #6 parser ping librarian когда heartbeat-parser.md draft готов.
- #7-8 confirmed.
- #9 yaml format fix `memory_layers`.
- #10 `handoff_amendments_protocol`.

---

## 7. MCP Agent Mail Phase 1 POC — **BLOCKED on Ilya explicit "старт"**

### Architecture decision 2026-04-21 22:15 (Илья)

**«Aeza защищённая папка» mode** — zero public surface:
- FastMCP bind'ится на **127.0.0.1:8765** (только localhost).
- **НЕТ Caddy, НЕТ домена, НЕТ публичных endpoint'ов.**
- Доступ с ноута Ильи через **SSH tunnel**: `ssh -L 8765:127.0.0.1:8765 root@193.233.128.21`.
- После tunnel: `http://localhost:8765` на Windows-ноуте = MCP Agent Mail на Aeza.
- Canon: усиленный #7 offline-first + #11 architectural_privilege_isolation (нет атакующей поверхности = нет injection attack vector через сеть).
- Portability bonus: **переезд на другой VPS = zero DNS**, только меняется host в SSH команде.
- Canon записан: `canon_training.yaml → decision_2026_04_21_mcp_agent_mail.access_mode`.

### Blocker

**Ilya explicit «старт»** — он сказал «спрошу пока так» = будет координировать с librarian по sudo напрямую. НЕ начинать без явного «старт POC».

### Пересмотренные 10 шагов (35-40 мин total, было 55)

```
STEP 1  (2 min)  uv install:
                  curl -LsSf https://astral.sh/uv/install.sh | sh
                  source ~/.bashrc

STEP 2  (5 min)  Python 3.14 через uv:
                  uv python install 3.14

STEP 3  (2 min)  Защищённая папка:
                  mkdir /opt/mcp_agent_mail
                  chmod 700 /opt/mcp_agent_mail

STEP 4  (10 min) MCP Agent Mail installer (localhost bind):
                  cd /opt/mcp_agent_mail
                  curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?$(date +%s)" \
                    | bash -s -- --yes --dir /opt/mcp_agent_mail --port 8765 --bind 127.0.0.1 --no-start

STEP 5  (2 min)  Bearer token:
                  TOKEN=$(openssl rand -hex 32)
                  echo "HTTP_BEARER_TOKEN=$TOKEN" >> /opt/mcp_agent_mail/.env
                  chmod 600 /opt/mcp_agent_mail/.env
                  # Копия в /opt/realty-portal/.env для shared access прочих ролей

STEP 6  (3 min)  systemd unit /etc/systemd/system/mcp-agent-mail.service:
                  [Unit]
                  Description=MCP Agent Mail FastMCP (localhost only)
                  After=network.target
                  [Service]
                  Type=simple
                  User=root
                  WorkingDirectory=/opt/mcp_agent_mail
                  EnvironmentFile=/opt/mcp_agent_mail/.env
                  ExecStart=/opt/mcp_agent_mail/.venv/bin/python -m mcp_agent_mail \
                    --bind 127.0.0.1 --port 8765
                  Restart=on-failure
                  RestartSec=5
                  [Install]
                  WantedBy=multi-user.target

STEP 7  (2 min)  Enable+start + verify:
                  sudo systemctl daemon-reload
                  sudo systemctl enable --now mcp-agent-mail
                  ss -tlnp | grep 8765
                  # Expected: 127.0.0.1:8765 LISTEN (NOT 0.0.0.0)

STEP 8  (5 min)  Smoke test локально на Aeza:
                  curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/mail/health
                  # Expected: {"status":"ok",...}

STEP 9  (5 min)  Registration + migration:
                  - macro_start_session (role='librarian-v3', project_key='/docs/school',
                    program='claude-code', model='opus-4.7')
                  - Thread "librarian-v2-handoff-migration" ← перенос inbox блоков 21:30, 21:05, 19:30

STEP 10 (3 min)  Client config template:
                  - docs/school/mcp-client/librarian.mcp.json:
                    SSE URL = http://localhost:8765 (после SSH tunnel)
                    Authorization: Bearer <TOKEN>
                  - SSH tunnel команда для Ильи:
                    ssh -L 8765:127.0.0.1:8765 root@193.233.128.21

TOTAL: ~35-40 min (conservative +buffer)
```

**ZERO:** DNS setup, Caddy install, Let's Encrypt, firewall для 80/443.

### Acceptance criteria — Test suite T1-T10 (запусти в Step 9 и после)

```
T1  baseline:       school→librarian через MCP, librarian ack < 5 min
T2  fan-out:        школа рассылает всем роли, все ack < 10 min
T3  offline:        librarian-chat off, школа send → librarian opens → reads missed
T4  concurrent:     school+librarian одновременно пишут в thread → both visible, ordering via FTS rank
T5  canon drift:    school bumps v0.3→v0.4, librarian без re-read → mismatch detected
T6  corruption:     corrupt 1 file MCP Agent Mail → Doctor repairs (CLI: uv run python -m mcp_agent_mail.cli doctor repair)
T7  handoff safety: librarian-v3 closes, v4 starts → reads last_ack_v3 + new only (ack_required=true helps)
T8  cold restart:   Aeza reboot, systemd auto-start, данные persist в SQLite
T9  token rotation: change bearer token in .env, clients reload, zero downtime
T10 role-guard:     2 simultaneous librarian-chats → second detects (duplicate identity protection), refuses
```

**Результат:** записывай в `docs/school/tests/mailbox_reliability_v1.md` (write-permit approved).

---

## 8. Aeza infra — state на 2026-04-21 21:30 WITA

```
SSH:                 root@193.233.128.21 via ~/.ssh/aeza_ed25519
OS:                  Ubuntu 24.04.4 LTS (Noble Numbat), x86_64
Python:              3.12.3 system default (/usr/bin/python3 → python3.12)
uv:                  НЕ установлен — план `curl -LsSf https://astral.sh/uv/install.sh | sh`
Caddy:               НЕ установлен — план в STEP 2 (cloudsmith repo)
RAM:                 7.8G total / 4.4G available (3.3G used, 3.1G buff/cache)
Disk /opt:           59G total, 22G free (63% used)

Project root:        /opt/tg-export/
  heartbeat.sh       (4969 bytes, sha256 38c1b30a3a78292ab953d13604723aa68c10328d1dd9d8424a7b23279a9b90bb)
  heartbeat.log      (tail -20 для проверки alive)
  _status.json       (atomic snapshot — проверь freshness)
  transcripts/       14 файлов готовых (55,57,13,15,53,63,64,71,136,137,144,147,164,165,170)
  media/             _manifest.json, 14 видео
  _paperclip_unpacked/   3.A research артефакт
  _mcp_mail_eval/        3.B research артефакт (git clone --depth 1)

Cron активный:
  */10 * * * *    /opt/tg-export/heartbeat.sh         # self-healing
  0 */2 * * *     /opt/tg-export/notify.sh            # TG push 2ч
  15 */6 * * *    /opt/tg-export/sync_channel.mjs     # новые посты Алексея 6ч
  30 2 * * *      /opt/tg-export/verify.sh            # daily integrity

Listening ports:
  127.0.0.1:8000   docker-proxy (неизвестно какой контейнер)
  НИКТО на 80/443/8765/4000/3100/54329 — free.
```

---

## 9. Routes + credentials map (БЕЗ значений)

| Что | Путь / URL | Где хранится |
|---|---|---|
| SSH Aeza | `root@193.233.128.21 via ~/.ssh/aeza_ed25519` | `C:\Users\97152\.ssh\aeza_ed25519` (локально) |
| TG bot | `@PROPERTYEVALUATOR_bot` | token `TELEGRAM_BOT_TOKEN` в `/opt/realty-portal/.env` (Aeza, chmod 600) |
| TG admin chat | — | `TELEGRAM_ADMIN_CHAT_ID` в `/opt/realty-portal/.env` |
| Grok STT | — | `XAI_API_KEY` в `/opt/tg-export/.env` (Aeza, chmod 600) |
| LightRAG | `http://realty_lightrag:9621` (контейнер) | endpoint в compose, proxied на Aeza |
| MCP Agent Mail (POC pending) | `http://127.0.0.1:8765` на Aeza; с ноута — после `ssh -L 8765:127.0.0.1:8765 root@aeza` | bearer `HTTP_BEARER_TOKEN` в `/opt/mcp_agent_mail/.env` (chmod 600, генерится STEP 5) |
| LiteLLM gateway | `:4000` parser-side (A3 pending) | shared bearer, quota per-role в admin |
| Embedded PostgreSQL (Paperclip, если поставим) | `:54329 localhost` | бэкап `/var/lib/paperclip/` |

---

## 10. Known gotchas (v1 + v2 amendments)

- **jq merge падает на transcripts >1h** — фикс Python `merge_transcripts.py` (transcribe.sh вызывает при duration > chunk). Не воспроизводится на <1h.
- **download.mjs zombie-alive** — процесс `Sl` (living-sleeping), takeout session expired ≥1h inactivity. heartbeat ловит через `max_idle = expected_break*60 + 300`. Recovery 3 сек (kill → nohup restart).
- **takeout session** в msg_178 канон — throwaway TG аккаунт `Gede @RoyalPalaceAddress` + takeout session = ноль банов за 24ч.
- **Paperclip gotchas** (из README, `msg_147` канон подтверждён):
  - Vite dev режим блокирует external hosts → `PAPERCLIP_UI_DEV_MIDDLEWARE=false` в systemd.
  - claude CLI не виден в systemd → симлинк `/usr/local/bin/claude`.
  - `~/.claude/settings.json` permissions **не работают** для Paperclip агентов (spawn обходит).
  - embedded postgres на 54329 может зависнуть — `kill $(ss -tlnp | grep :54329 | grep -oP 'pid=\K[0-9]+')`.
  - OpenClaw pairing required → approve manually.
- **CP-1251 вложения** (парсер-related) — с нашим domain не сталкивался, но школа помечала как risk.
- **Caddy не установлен на Aeza** (v2 discovery) — **больше НЕ нужен** после 22:15 decision (localhost+SSH tunnel).
- **Python 3.14 missing** — путь через uv (не apt — не трогаем системный 3.12).
- **SSH tunnel mode (2026-04-21 22:15):** Claude Code MCP client на Windows-ноуте подключается к `http://localhost:8765` только **после** `ssh -L 8765:127.0.0.1:8765 root@193.233.128.21`. Если tunnel упал — mailbox-недоступен для всех Claude Code чатов. **Mitigation:** (a) autossh для persistent tunnel, (b) systemd user-service на Windows (WSL) для tunnel, (c) manual re-connect при недоступности + heartbeat обнаружит. Рекомендую (a) + (c) в Phase 1.

---

## 11. TO_SUCCESSOR (незакрытые задачи в очереди приоритетов)

- **[P0]** Прочитай read-on-start (section 3) полностью. Особенно `consensus_workshop.md` 21:45 block — школа ждёт твой ACK.
- **[P0]** При старте v3 **школа должна сгенерировать** `docs/school/warmstart/librarian_v3_brief.md` через `write_warm_start_brief(role='librarian', v=3)` авто-хук (canon v0.4 правило). Если brief отсутствует — школа нарушила canon, сделай ping в inbox как первое действие.
- **[P0-blocked on Ilya permit + domain]** MCP Agent Mail Phase 1 POC — 10-шаговый план в section 7. ETA ~55 мин после permit.
- **[P0-after POC]** Run test suite T1-T10 против POC, результат в `docs/school/tests/mailbox_reliability_v1.md`. Все зелёные → canon bump v0.3 → v0.4 с `mailbox_reliability_invariants` + `canon_version_check_on_turn_start`.
- **[P1-after POC]** Canon-update: `mailbox_comms` → MCP Agent Mail primary, files = archive-only. Apply `role_inbox_exit_closure` правило.
- **[P1-after parser heartbeat-parser.md]** Пиши `docs/school/skills/heartbeat-common.md` L1 generalized skill. Используй status.json v1.0 schema (см. inbox 21:30 блок B2). Reference — `docs/school/skills/heartbeat-librarian-reference.sh` (создан v2).
- **[P1-after MCP POC stable]** LightRAG ingest 3-phase:
  - Phase 1 smoke: 3 файла (170 блиц + 55 Baserow + 147 Paperclip). Control questions про heartbeat, Baserow альтернативы, приоритеты Алексея.
  - Phase 2 batch: остальные 11 транскриптов.
  - Phase 3 monitor: retrieve-quality tests еженедельно.
- **[P1]** Phase 0 #2/#3/#1-finish — транскрипты 164/165 (2ч каждый) + skills-a-to-ya.md оставшиеся 2/3. Локально, без SSH.
- **[P2]** msg_72/82/97/103 digests — после докачки + транскрибации (ждёт P4 whitelist завершения).
- **[P2]** Multi-model triangulation: когда parser-v2 откроет LiteLLM endpoint (A3 task) — прогнать prompt из inbox 19:30 section 3.E для validation MCP Agent Mail решения (#3 observation approved librarian использует IU3 для validation).
- **[P3]** Paperclip eval2 — проверить `heartbeatInterval` в config.json если Илья решит ставить (после MCP Agent Mail rollout стабилизации).
- **[P3]** Broadcast «в продакшне только API» — ждёт Ильиного финала через broadcast_queue.md.
- **[P3]** A2A agent.json для secretary — Phase 3 SaaS (при первом платящем клиенте).

### blocked_on

1. **Ilya explicit «старт POC»** — он сам координирует с librarian по sudo (sказал «спрошу пока так»). НЕ стартуй без явного слова.
2. ~~Ilya domain name~~ — **СНЯТО 2026-04-21 22:15.** Архитектура: localhost + SSH tunnel, домен не нужен.
3. parser-v2 сдача `heartbeat-parser.md` draft (триггер для heartbeat-common.md).
4. Canon v0.4 bump (триггер: Phase 1 POC success + T1-T10 green).

---

## 12. First-turn checklist для v3

Запускай **последовательно**:

1. **Проверка heartbeat на Aeza:**
   ```bash
   ssh root@193.233.128.21 'tail -20 /opt/tg-export/heartbeat.log'
   # должны быть [tick] в последние 20 минут
   ssh root@193.233.128.21 'cat /opt/tg-export/_status.json | python3 -m json.tool'
   # "updated" не старше 15 минут
   ```
2. **Canon drift check:**
   ```bash
   head -3 docs/school/canon_training.yaml
   # version: 0.3 ожидается; если другой → full re-read + canon_drift event в inbox
   ```
3. **Inbox school:**
   ```bash
   # Проверь свежие blocks в этих файлах через `ls -lat`:
   # docs/school/mailbox/dispatch_queue.md
   # docs/school/mailbox/consensus_workshop.md
   # docs/school/mailbox/outbox_to_librarian.md
   ```
4. **warm_start_brief:** если школа сгенерировала `docs/school/warmstart/librarian_v3_brief.md` — прочитай (300-500 слов, экономия 20+ минут onboarding).
5. **MCP Agent Mail status check (SSH tunnel mode):**
   ```bash
   ssh root@193.233.128.21 'systemctl status mcp-agent-mail 2>/dev/null && ss -tlnp | grep 8765 || echo "NOT INSTALLED — ждать Ilya старт"'
   ```
   Если **LISTEN 127.0.0.1:8765** → открывай SSH tunnel локально: `ssh -L 8765:127.0.0.1:8765 root@193.233.128.21` → `macro_start_session(role='librarian-v3')` через `http://localhost:8765` + bearer.
   Если **не установлен / 0.0.0.0 bind** → canon violation, alert школе.
   Если **waiting** → мониторим dispatch_queue на Ilya «старт».
6. **Python 3.14 check:**
   ```bash
   ssh root@193.233.128.21 'command -v uv && uv python list 2>&1 | grep 3.14'
   ```
   Если 3.14 готов → POC ready-to-go. Иначе добавь в POC steps.
7. **ACK в inbox:** после всех проверок — первый блок в inbox `## YYYY-MM-DD HH:MM — librarian-v3 start ACK` с указанием canon version + warm_start read + MCP POC status + blocker'ов.

---

## 13. v2 amendments (финал 2026-04-21 23:50 WITA, перед mv)

- **Consensus workshop закрыт 22:45-23:20** (operator-model шаг 7). 14 секций v0.4 scope согласованы, все ACCEPT. Детали: `docs/school/mailbox/consensus_workshop.md` блоки 22:30 (моя архитектура) + 23:00 (мой ACCEPT критики) + closure log в `dispatch_queue.md` 22:15/22:45/23:15.
- **NEW-9 (Claude Code MCP client compatibility pre-test) принят** → POC теперь **12 шагов (~65 мин)**, а не 11 (~50 мин). Добавлен Step 0a (15 мин throw-away echo MCP endpoint) чтобы убедиться что CC умеет подключаться к remote MCP через SSH tunnel + Bearer header ДО `curl | bash` установки MCP Agent Mail.
- **NEW-1 mitigation принято: Илья делает `Move-Item "C:\Users\97152\Новая папка" "C:\work"`** до твоего старта. Твой `project_key` для MCP при регистрации = `C:\work\realty-portal\docs\school` (ASCII-only, zero unicode risk).
- **school_v2.md обновляется финальным dump'ом** school-v1 перед mv (school-v2 при своём старте прочитает свежий state, не v0.2 stale).
- **parser-rumah123_v3.md parser-v2 активирует** этим же turn'ом (был pre-seeded заготовкой).
- **launch_manifest.json — главный bootstrap artifact.** Читаешь его **первым**, затем свою секцию `roles_to_launch."librarian-v3"`. ВАЖНО — ключ называется `roles_to_launch`, НЕ `roles` (в Ильином промпте-cheatsheet для меня была опечатка `jq '.roles..."`, игнорируй).
- **Path migration sed — через Python, НЕ PowerShell.** Windows PowerShell 5.1 `-Encoding UTF8` добавляет BOM → может поломать yaml parsing у school-v2. Использовать oneliner (без BOM):
  ```bash
  uv run --no-project python -c "
  import pathlib, re
  root = pathlib.Path(r'C:\work')
  patterns = [(r'C:\\\\Users\\\\97152\\\\Новая папка', r'C:\\work'), (r'C:/work', r'C:/work')]
  count = 0
  for f in root.rglob('*'):
      if f.is_file() and f.suffix in ('.md','.json','.yaml','.py','.ps1','.mjs','.sh'):
          try: txt = f.read_text(encoding='utf-8')
          except: continue
          new = txt
          for p, r in patterns: new = re.sub(p, r, new)
          if new != txt:
              f.write_text(new, encoding='utf-8', newline='')
              count += 1
              print(f'updated: {f.relative_to(root)}')
  print(f'total: {count} files')
  "
  ```
- **parser heartbeat-parser.md УЖЕ существует** (`docs/school/skills/heartbeat-parser.md`, 16KB, 2026-04-21 18:05). Это значит blocker «ждём parser сдать heartbeat-parser.md draft» для твоего `heartbeat-common.md` — **СНЯТ**. Ты можешь начать common.md параллельно с / после MCP POC. В section 11 P1 я писал «blocked_on parser» — неактуально.
- **skills/heartbeat-librarian-reference.sh** (7KB, sha256 `38c1b30a3a78292ab953d13604723aa68c10328d1dd9d8424a7b23279a9b90bb`) — твоя reference копия моего `/opt/tg-export/heartbeat.sh` с frontmatter v1.0. Используй как базу для common.md.
- **Opening your first turn:** launch_manifest секция `roles_to_launch."librarian-v3"` → read_on_start_order → first_turn_action_checklist (9 пунктов включая Python sed-replace) → ACK в inbox → waiting на Ilya «старт POC».
- **v0.3 → v0.4 bump** случится после POC T1-T10 green. 14 секций уже известны (`canon_v04_scope_final` в launch_manifest).
- **Consolidated dispatch blocks** от школы (tl;dr):
  - 22:15 `[CONSOLIDATED WORKSHOP + REVISED POC PLAN]` — SSH tunnel вместо Caddy+domain.
  - 22:45 `[ARCHITECTURAL CRITIQUE]` — 5 counter + 8 NEW concerns (все приняты).
  - 23:15 `[PRE-INSTALL DOUBLE-CHECK + NEW-9]` — Step 0a добавлен.
- **Всё. v3 стартуй спокойно.**

---

## 14. v3 amendments (2026-04-22, POC complete + canon v0.4)

- **MCP Agent Mail POC: 10/10 T1-T10 PASS** (`docs/school/tests/mailbox_reliability_v1.md`).
- **NEW-10 confirmed:** `Path('C:\\work\\...').is_absolute()` returns `False` on Linux. Canonical `project_key` = `/opt/realty-portal/docs/school` (Linux-absolute). Never use Windows path as project_key.
- **API parameter corrections** (critical for future agents):
  - `ensure_project`: param = `human_key` (NOT `project_key`)
  - `fetch_inbox`: results at `structuredContent.result[]` (NOT `.messages[]`)
  - `mark_message_read`: single `message_id: int` (NOT `mark_read` / `message_ids: []`)
  - `register_agent`: `program` + `model` + optional `name` (NOT `agent_name`)
  - Before first `send_message`: `request_contact` + `respond_contact` (recipients must be registered)
- **`.mcp.json` updated**: `mcp-agent-mail` added (`type: http`, `url: http://localhost:8765/api/`, `Authorization: Bearer ${MCP_AGENT_MAIL_BEARER}`).
- **`claude-session.ps1` updated**: port 8765 added to SSH tunnel; `MCP_AGENT_MAIL_BEARER` added to env pull + cleanup.
- **Agents in project** `/opt/realty-portal/docs/school`: librarian-v3 (id=1), school-v2 (id=2), librarian-v2/archived (id=3). Contacts: all pairs bidirectionally approved (expires 2026-05-22).
- **last_read_canon_version: 0.4** — full re-read 2026-04-22 12:40. canon_version_check_on_turn_start executed. canon-updates thread ACK sent (msg id=16).
- **Canon v0.4 new invariants absorbed**: `canon_version_check_on_turn_start`, `mcp_session_start_sequence`, `mcp_api_usage`, `role_inbox_exit_closure`, `thread_id_naming_conventions`, `mailbox_reliability_invariants` I-1..I-10, `launcher_mcp_bootstrap`, `ilya_overseer_bypass`, SLA tables.
- **thread_id_naming_conventions compliance check**: `presence` ✅, `librarian-v2-to-successor` ✅ (`<role>-to-successor` namespace), `librarian-v3-to-school` ✅ (`<role>-to-school` namespace), `canon-updates` ✅.
- **heartbeat-common.md** still pending — blocker was removed (heartbeat-parser.md exists).

---

## 15. TO_SUCCESSOR v4 (session closing 2026-04-22)

Живые задачи которые librarian-v4 подхватывает на старте.

### P0 (must-do первым, блокирует others)

- **[P0 next-session] Tailscale install + `.mcp.json` migration + W5 removal** —
  Stage 1 scale-up architecture. Install Aeza + Windows, migrate `.mcp.json`
  URL с `http://localhost:8765/` на `http://aeza-realty.tail-XXXX.ts.net:8765/`
  (где XXXX из tailnet admin console), убрать port 8765 из
  `claude-session.ps1` SSH `-L` tunnel (W5). Полная spec в
  `skills/autolauncher-architecture.md` §2. Test criterion: `curl
  http://aeza-realty.tail-XXXX.ts.net:8765/api/health` возвращает
  `{"status":"ok"}` от Windows без SSH tunnel.

- **[P0 next-session] `mesh-boot.ps1` v1** — `agents.yaml` registry + basic
  commands (`boot` / `add` / `status`). Использует `wt.exe new-tab` для
  multi-tab spawn. Skeleton в `skills/autolauncher-architecture.md` §4.
  Scope v1: только `boot` + `add` + `status`; `restart` + `kill-all` — v2.

- **[P0] `heartbeat-common.md`** — написать unified skill (parser-rumah123-v3
  **и ai-helper-v2** blocked на своих A1 задачах пока этого нет). Input: `heartbeat-parser.md`
  (уже в `docs/school/skills/`) + `heartbeat-librarian-reference.sh` (v1.0,
  sha256 `38c1b30a...`). Output: common skill с 2-layer architecture
  (infra watchdog + human-rhythm simulator), который parser/librarian
  импортируют. Time estimate: 45-60 мин.

- **[P0] Investigate `mark_message_read` persistence bug** (L-6 в skill v1.1).
  Symptom: 11 msg'ов отмечены read в turn N → снова unread в turn N+1 после
  другого fetch_inbox. Три гипотезы:
  1. `read_at` пишется в отдельную таблицу с lazy sync, проигрывается при
     `systemctl restart mcp-agent-mail`.
  2. `fetch_inbox` query-time recalc по неявному фильтру.
  3. Нужен explicit `acknowledge_message` follow-up after `mark_message_read`.
  Path: `ssh root@aeza 'sqlite3 /opt/mcp_agent_mail/storage.sqlite3
  ".schema messages"'` — проверить где хранится read state. Затем
  `SELECT id, read_at FROM messages WHERE read_at IS NOT NULL LIMIT 5;` —
  видим ли persistent state вообще.

### P1 (важно, после P0)

- **[P1 next-session] `launchers/*.md` extraction для 4 текущих агентов** —
  создать `docs/school/launchers/{librarian_v3,school_v3,parser_rumah123_v3,ai-helper_v2}.md`
  извлечением bootstrap-блоков из соответствующих handoff'ов. Формат — canon
  v0.4 `launcher_mcp_bootstrap` required_section. Используется `agents.yaml`
  полем `launcher_file`.

- **[P1 session after] `watcher.ps1` research фаза** — механизм чтения
  context% из CC session не существует natively. Research TODO (spec §5):
  (1) parse `/status` output, (2) `~/.claude/logs/*.jsonl` анализ, (3) hook
  в settings.json который пишет context% в файл, (4) PR против CC
  (`--print-context-pct`). Без этого watcher — only presence/MCP health.

- **[P1] Tailscale migration RFC** — обсуждалось с Ильёй 2026-04-22 evening.
  Контекст: SSH `-L` tunnel падает >10 раз за session (L-7 в skill v1.1).
  RFC должен покрыть: (1) install steps Aeza + Windows, (2) migration .mcp.json
  с `http://localhost:8765/` на `http://<aeza-tailscale-ip>:8765/`,
  (3) как заменить bearer token с Tailscale ACL (если проще),
  (4) cost $0 (Tailscale free tier покрывает 100 устройств), (5) fallback
  к SSH tunnel если Tailscale недоступен. Decision pending — в
  `docs/school/decisions/tailscale_migration.md`.

- **[P1] Autolauncher design document** — Илья делает через tech library
  в следующей сессии (его слова 2026-04-22). Librarian-v4 готовит
  design-doc: `docs/school/design/autolauncher_v1.md`. Scope: (1) что такое
  autolauncher (auto-spawn ролей при triggered conditions), (2) какие роли
  spawn'ятся autoматически vs manual (secretary = manual per AP-7),
  (3) lifecycle (spawn → register_agent → contact handshake → first turn →
  idle → terminate), (4) interaction с canon_version_check + handoff
  generation, (5) безопасность (kill switch, rate limit).

### P2 (nice-to-have)

- **[P2 session after] `dashboard.ps1` v1** — TUI (Spectre.Console) или HTML
  view с agent list + health (context% / MCP msg rate / presence freshness).
  Design spec в `skills/autolauncher-architecture.md` §6. Recommend TUI для
  v1 — меньше moving parts. Depends on `watcher.ps1` v1 готов.

- **[P2] Finalize skill v1.2** — в JSON handoff (который Илья делал сегодня)
  было 10+ `skill_corrections`, из которых в skill v1.1 попали только
  L-1..L-8. Re-read JSON handoff, domена identify каждый correction, либо
  интегрировать в skill body либо пометить как «intentionally excluded with
  reason». Ожидаемая длина после: 750-900 строк. Критерий готовности:
  zero open skill_corrections.

- **[P2] File-reservation skill** — `file_reservation_paths` tool в MCP
  Agent Mail позволяет advisory locks на файлы. Когда school-v3 и
  parser-rumah123-v3 оба редактируют `canon_training.yaml` — сейчас race
  condition. Написать skill `mcp-file-reservation.md` по образцу
  mcp-agent-mail-setup.md (frontmatter + canon_refs + examples).

- **[P2] Offsite backup cron** — canon v0.4 `offsite_backup_policy` требует
  daily `uv run ... cli archive save` + scp на Windows + B2 sync. Sche
  cron на Aeza + Windows pull-скрипт + test recovery из backup на свежем
  VPS (критерий: recovery time <30 мин).

### Blocked on external

- **[BLOCKED] secretary-v1 registration** — P0 secretary-v1 launch требует
  `set_contact_policy(contacts_only, allowlist=['ilya-overseer'])` до prod
  per AP-7 finding. Ждём Илью: (a) secretary launcher готов, (b) первый
  client-facing product decision.

### Context at session close

- Active agents в MCP: librarian-v3 (1), school-v2 (2), school-v3 (6),
  parser-rumah123-v3 (7), ai-helper-v2 (id TBD), librarian-v2 archived (3).
- Contacts approved: librarian-v3 ↔ {school-v2, school-v3, parser-rumah123-v3,
  ai-helper-v2, librarian-v2}. Expires 2026-05-22.
- Active threads с контентом: `presence`, `librarian-v2-to-successor`,
  `librarian-v3-to-school`, `canon-updates`, `librarian-to-parser`,
  `librarian-to-ai-helper`.
- Canon version: **0.4** (read 2026-04-22 12:40). При старте v4 сделать
  canon_version_check_on_turn_start — если bump до 0.5, mismatch → full re-read.
- Skill версия: `mcp-agent-mail-setup v1.1` (2026-04-22 session close).

### Cross-session memory dump 2026-04-22 реквизиты

Hybrid-memory vault (separate FS от Windows):

- Backup: `backup-20260422-095137-realty-portal-mesh-complete-20260422.md` (15 KB)
- Digest: `memory-digest-20260422-095142.md` (17 KB, 294 lines)
- Compact: `memory-compact-20260422-095142.md` (11 KB)
- Git: commit `4a7051b` на branch `claude/parser-v3-launcher-bootstrap-DKNwr`
- Contains: 6 новых memories (AP-7 open_policy finding, Tailscale migration,
  SSH heredoc trap, Custom API key bypass, mark_read persistence bug, mesh
  context) + 22 исторических entries от hybrid-brain
- Access: запросить у Ильи копию/scp/git sync при необходимости

### First-turn action checklist для librarian-v4

1. `head -3 docs/school/canon_training.yaml` → сравнить с `last_read: 0.4`
2. `ls -lat docs/school/mailbox/` → найти новое от school
3. Прочитать `docs/school/mailbox/outbox_to_librarian.md` последние блоки
4. `mcp_session_start_sequence` 4-шаговый (skill §6)
5. ACK в `inbox_from_librarian.md` с context snapshot
6. Pick P0 task из §15 (heartbeat-common OR mark_read bug)

---

## HANDOFF CHECKLIST (для v2)

- [x] Header + метаданные
- [x] Role + BU + monetization
- [x] Read-on-start порядок
- [x] last_read_canon_version + context snapshot 4a
- [x] Research Task 3.A-3.F state + артефакты
- [x] Workshop decisions v0.3 + canon line references
- [x] Mission brief approvals (4/4)
- [x] MCP Agent Mail POC 10-step plan + T1-T10 acceptance
- [x] Aeza infra state
- [x] Routes + credentials map (без значений)
- [x] Known gotchas v1+v2
- [x] TO_SUCCESSOR queue (P0-P3)
- [x] blocked_on
- [x] First-turn checklist
- [ ] v2 amendments placeholder (empty)
