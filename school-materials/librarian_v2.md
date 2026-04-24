# Handoff: librarian-v1 → librarian-v2

**Дата передачи:** 2026-04-21, ~15:00 WITA
**От:** librarian-v1 (UI: setup-tg-parser, критическая зона контекста)
**Кому:** librarian-v2 (новая сессия)
**Триггер переезда:** v1 достигла критической зоны контекста. Handoff создан school-v1 на основе `inbox_from_librarian.md` (разделы Задача 1-4) + `canon_training.yaml` + общего канона. v1 может дополнить детали если успеет.

> **Важно:** этот handoff — **school-draft**. Если у v1 есть свежие детали которые я (school) не знаю — она добавит их в конце файла отдельным блоком `### v1 amendments` перед закрытием.

---

## Что ты (v2) делаешь при старте

1. Прочитай `docs/school/canon_training.yaml` — общий канон всех ролей.
2. Прочитай **этот файл** (handoff) + `librarian_v2.json` (machine-readable).
3. Прочитай `docs/school/mailbox/outbox_to_librarian.md` — директивы школы (включая permits и approvals).
4. Прочитай `docs/school/mailbox/inbox_from_librarian.md` — твой предыдущий ответ от v1 (сверху вниз).
5. Начни с **незавершённых задач** (см. раздел ниже).

---

## Роль

Ты — `librarian-v1` в **IU1 (Infrastructure — Librarian)** личной AI-компании Ильи. Это сессия **v2** той же роли (канон: `one_role_one_chat` — v1 закрывается Ильёй после твоего handoff read).

**UI-имя чата в Claude Code у Ильи:** `setup-tg-parser` (по факту это ты).

**Зона правок:** Aeza `/opt/tg-export/` + всё что касается канона Алексея + транскрипты + library_index + heartbeat/notify/sync_channel/verify cron на Aeza.

**НЕ трогать:**
- `docs/school/**` (домен school-v1) — читать можно, писать нельзя. Исключение: `docs/school/mailbox/inbox_from_librarian.md` (твой inbox для ответов) + `docs/school/handoff/librarian_v<N+1>.md` при твоём переезде.
- `scrapers/` + `normalize_listings.py` + Supabase scheme (домен parser-rumah123-v2).
- Чужие ключи.

---

## Твоя монетизационная роль

Ты — **knowledge asset всей компании**. Не продаёшься сам по себе, но **снижаешь cost всех BU**:
- School без тебя слепа (канон Алексея = её учебник для Ильи).
- Parser без тебя не знает эталона human-rhythm (`tg_download_aeza.mjs` → от тебя).
- Secretary без тебя не узнает про Telegram skill msg_178 и Paperclip msg_147.
- LinkedIn-writer будет использовать msg_101-104 (контент-завод).

Research done once, reused many times. Это твой вклад в часы Ильи → деньги.

---

## Состояние работы на момент handoff

### Heartbeat — работает стабильно (эталон Layer 1)

- Файл: `/opt/tg-export/heartbeat.sh` (~150 строк bash)
- Cron записи (выживают при reboot):
  ```
  */10 * * * *    /opt/tg-export/heartbeat.sh         # self-healing каждые 10 мин
  0 */2 * * *     /opt/tg-export/notify.sh            # Telegram push статус
  15 */6 * * *    /opt/tg-export/sync_channel.mjs     # новые посты Алексея
  30 2 * * *      /opt/tg-export/verify.sh            # daily integrity check
  ```
- Транспорт Telegram через `@PROPERTYEVALUATOR_bot`, токен в `/opt/realty-portal/.env` (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_ADMIN_CHAT_ID`).
- Anti-false-positive: `expected-duration logging` + `manifest.finished` флаг + `_status.json` atomic snapshot.
- Известный incident: один раз 2026-04-20T18:20Z download застрял на long-break (takeout session протух). Heartbeat среагировал за 3 секунды.
- **Правок не требуется.** Твой heartbeat — canonical Layer 1 эталон для parser.

### Download P4 whitelist — в процессе

- Whitelist 16 видео (~17 ГБ, estimate $3.48).
- На 2026-04-21: **12 из 16** готовы транскриптами (55, 57, 63, 64, 71, 13, 15, 53, 136, 137, 144, 147, 164, 165, 170 — итого 14 транскриптов доступны).
- **Осталось 4:** msg_72 (N8N MCP рекомендации), msg_82 (Kilo Code ч.1), msg_97 (Supabase MCP), msg_103 (Content Factory backstage). ETA 2-4 часа.
- Grok STT бюджет: потрачено ~$0.46, осталось $4.54, прогноз $3.94 итого.
- msg_39 (Леший install, 3.5 ГБ) — вне бюджета, пропущен.

### Phase 0 прогон для школы — 3 из 6

**Сделано:**
- **#1 `skills-a-to-ya.md`** — первая треть разобрана (5 ключевых принципов, применения в BU1). **Продолжить** оставшиеся 2/3 — в следующей итерации (разделы про 3 уровня скиллов, description formula, 400 символов, `devops-ak` 8→1 случай).
- **#4 транскрипт 170** (59 сек) — завершено. 3 темы Алексея, L0.1 материал.
- **#6 `166_INSTRUCTION_CONNECT_MCP.md`** — завершено. L3 база. 5 принципов + гатчи.

**Осталось:**
- **#2 транскрипт 164** (2ч17, встреча 06.03.26) — OpenClaw + skills vs agents, L4 материал.
- **#3 транскрипт 165** (2ч17, Телемост) — LightRAG чистка + стратегии памяти, L3+L4 материал.
- **#5 `168_Мультиагентные AI-системы.pdf`** — стрейт про "когда агентные системы НЕ нужны", для L4.

Рекомендованный порядок (от school): **завтра — 168 PDF** (короче, прямо про multi-agent, нужно для секретаря). Затем 164, 165. Финал — оставшиеся 2/3 skills-a-to-ya.md.

### library_by_module.md — PERMIT получен

Школа разрешила разовую запись в `docs/school/library_by_module.md`. Твоя таблица топ-5 постов на модуль L0–L7 из раздела 3.3 твоего inbox — можешь скопировать туда. Подпиши как твой экстракт.

### LightRAG ingest канона — pre-APPROVED

Напиши ingest-скрипт (transcripts → LightRAG) в следующей сессии. Контейнер `realty_lightrag` на Aeza работает (Ollama + Haiku сконфигурен), канон не загружен. После ingest — endpoint URL для query → `canon_training.yaml → knowledge_endpoints`.

### Paperclip канон (ты уже исследовал)

- `Paperclip_install.zip` распакован в `/opt/tg-export/_paperclip_unpacked/`
- msg_147 — heartbeat = agent tick (AI просыпается, оценивает ситуацию, решает). Для секретаря — релевантно.
- Предполагаемое поле `heartbeatInterval` в `config.json` Paperclip (не проверено в коде).
- Известные косяки Paperclip: агенты теряют настройки, OpenClaw самоубийства, права CEO.

---

## Свежие транскрипты — команда scp для школы

```bash
mkdir -p "C:/work/realty-portal/docs/alexey-reference/export-2026-04-20/transcripts"
scp -i "C:/Users/97152/.ssh/aeza_ed25519" -o StrictHostKeyChecking=no \
  'root@193.233.128.21:/opt/tg-export/transcripts/*.transcript.txt' \
  "C:/work/realty-portal/docs/alexey-reference/export-2026-04-20/transcripts/"
```

14 файлов подтянутся. После: отфильтровать `*_part*.transcript.json` (orphans).

---

## Что ждёт в очереди

### P0 — приоритет высокий

1. **library_by_module.md** запись (одна задача, быстро).
2. **Phase 0 материал #5** — `168_Мультиагентные AI-системы.pdf` (первый, т.к. релевантен для секретаря который стартует параллельно).

### P1 — после Phase 0

3. **LightRAG ingest канона** (написать скрипт transcripts → LightRAG).
4. **Phase 0 материал #2, #3** (транскрипты 164, 165 — 2ч каждый).
5. **Phase 0 материал #1 финал** (оставшиеся 2/3 skills-a-to-ya.md).

### P2 — свежие материалы

6. После докачки msg_72/82/97/103 + транскрибации — короткие выжимки по 5 минут каждая.

### P3 — infra

7. **Broadcast-кандидат: Telegram+OpenClaw связка** (вопрос в твой прошлый inbox). Пока отложено — secretary-v1 определит свой транспорт первым.

---

## Канон-сверка (что применено)

- `#1 portability` — Docker Paperclip compose + Caddy/Let's Encrypt автомат.
- `#3 simple nodes` — heartbeat.sh / notify.sh / verify.sh / sync_channel.mjs — 4 скрипта, 4 задачи.
- `#5 minimal clear commands` — bash с `set -eu`, `|| log [err]`, императивно.
- `#6 single secret vault` — `/opt/realty-portal/.env` chmod 600.
- `#7 offline-first` — всё на Aeza.
- `#9 human rhythm` — `tg_download_aeza.mjs` эталон (SHORT 60-300s, BREAK 300-1200s, LONG_BREAK 1800-5400s).
- msg_178 Telegram canon — отдельный throwaway аккаунт `Gede @RoyalPalaceAddress` + takeout session = ноль банов.

---

## Технические routes

```
SSH:                 root@193.233.128.21 via ~/.ssh/aeza_ed25519
Project root:        /opt/tg-export/
Library index:       /opt/tg-export/library_index.json
Transcripts:         /opt/tg-export/transcripts/
Heartbeat/notify:    /opt/tg-export/{heartbeat.sh, notify.sh, verify.sh, sync_channel.mjs}
Paperclip unpack:    /opt/tg-export/_paperclip_unpacked/
Telegram bot:        @PROPERTYEVALUATOR_bot (токен в /opt/realty-portal/.env)
Grok STT key:        /opt/tg-export/.env (chmod 600)
LightRAG:            http://localhost:????  (контейнер realty_lightrag, endpoint уточни сам)
```

---

## Что НЕ делать v2

- ❌ Трогать `docs/school/**` кроме `mailbox/inbox_from_librarian.md` + своего handoff + разрешённого `library_by_module.md`.
- ❌ Трогать `scrapers/`, `scripts/normalize_listings.py` — домен parser.
- ❌ Убивать cron-задачи на Aeza (они работают независимо).
- ❌ Коммитить в git материалы Алексея (канал приватный, `.gitignore` защищает — не нарушать).
- ❌ Публиковать transcript/posts Алексея куда-либо.

---

## Формат отчёта

По шаблону `inbox_reply_format` в `canon_training.yaml`. Каждую задачу отдельным блоком. Новый блок идёт **сверху** inbox_from_librarian.md.

## Context-загрузка v2

После чтения canon_training + этого handoff + outbox — ~20-25% контекста. Остаётся 75%+ на реальную работу.

При >70% — пиши `librarian_v3.md` + `librarian_v3.json`.

---

## HANDOFF flag

✅ School-draft написан. v1 может дополнить блоком `### v1 amendments` если успеет до закрытия. Если нет — стартуй v2 с этого draft.

---

### v1 amendments (дописано librarian-v1 перед закрытием, 2026-04-21)

Допишу только то что **лично прогонял через руки** и что не в школьных артефактах.

#### 1. Heartbeat incident 2026-04-20T18:20Z — полный разбор root-cause

- Script объявил `[long-break] ~72min` в 16:46Z. По расчёту должен был проснуться в 17:58Z.
- Процесс был `Sl` (sleeping, живой) — `pgrep` его видел. Heartbeat НЕ бил тревогу потому что процесс формально жив.
- Реально: после `setTimeout(72*60*1000)` Node.js не делал новых API-вызовов несколько минут. **Корень**: takeout session expired после >1h inactivity. Telegram стороны не уведомил — ответы просто перестали приходить.
- Моё правило «idle > expected_break*60 + 300s → restart» сработало только когда я вручную обновил log (изменил expected_break) — это был мой workaround, не автофикс.
- **Скрытая грабля для v2**: heartbeat чекает `stat -c %Y log` (mtime), а не «время последнего успешного API-вызова». Zombie-like процесс НЕ ловится.
- **Рекомендация v2**: добавить `_api_heartbeat.json` где download-скрипт пишет timestamp каждого успешного API-response. Heartbeat читает **его** вместо mtime лога.

#### 2. Takeout session lifetime — недокументированное

- Grok не единственное ограничение. Telegram `account.InitTakeoutSession` даёт session_id, которая живёт **пока активна**. Определение «активна» не задокументировано.
- На практике: **~60 минут без single call → expired**. При следующем call возвращает `TAKEOUT_REQUIRED` или тихо висит.
- Мой код имеет fallback (regular mode) но **только при ошибке на InitTakeoutSession**, не при expiry уже активной session.
- **v2 TODO**: ловить expired takeout в middle of iteration → re-init.

#### 3. `jq --argjson` limit — количественные детали

- Падает на массиве word-level timestamps > ~8000 элементов.
- 2ч17мин видео = ~18000 слов = гарантированное падение.
- `merge_transcripts.py` (Python in-memory) — единственный workaround. НЕ полагайся на jq для merge больших транскриптов.
- **Скрытая связь:** если транскрипт > 1ч — сразу Python, не пробуй jq.

#### 4. Paperclip_install.zip — недокументированный нюанс

- Распаковал на Aeza `/opt/tg-export/_paperclip_unpacked/` (я один это сделал, school-draft про это не знает).
- `install_paperclip.sh` **требует sudo без пароля** + DNS A-record уже настроен. На Aeza у нас **уже есть OpenClaw через Caddy** — ставить Paperclip на тот же сервер = конфликт портов (3100 и 54329).
- В README msg_144 прямо: «Ставится на тот же сервер, где OpenClaw». Но не указано что OpenClaw использует 3100 тоже в некоторых конфигах — **проверить перед установкой**.
- Я Paperclip НЕ ставил — только читал. `~/.paperclip/` на Aeza не существует.

#### 5. Grok STT quirk — язык-detection бага

- В response JSON `language` иногда = `"English"` даже когда весь текст русский (подтверждено на 7/14 файлах).
- `text` и `words[].text` — корректны, русский. Поле `language` игнорировать.
- **Не баг нашего кода**. Это Grok STT сам путается на смешанной RU+EN речи (Алексей вставляет «cloud code», «paperclip», «MCP» — Grok meta-label'ит EN).

#### 6. Auto-sync cron — immediate gotcha

- `sync_channel.mjs` cron `15 */6`. Первый раз запустится **в 18:15 UTC сегодня** (≈сейчас для твоего следующего старта).
- Если v2 запустится одновременно с cron sync — возможен **race** на `library_index.json` (sync перезаписывает, v2 читает).
- **Безопасно:** v2 делает копию `cp library_index.json library_index.read.json` при старте, работает с копией.

#### 7. Что в `.env` на Aeza (не засвечу значения)

- `XAI_API_KEY` — Grok STT, $5 куплено, потрачено ~$0.67
- `BOT_TOKEN`, `CHAT_ID` — для notify/sync (импортнуты из `/opt/realty-portal/.env`)
- `OPENCLAW_GATEWAY_TOKEN` — есть в `/opt/realty-portal/.env`, **не перенёс** в tg-export (OpenClaw не используем для алёртов)
- **v2 может переиспользовать** tg-export/.env для OpenClaw алёртов если school решит — просто импорт через sed из `/opt/realty-portal/.env`.

#### 8. Downloaded но ещё не транскрибированные на момент handoff

- msg 72, 82, 97, 103 — **ещё не скачаны** (4 тяжёлых видео). ETA 2-4 часа после начала v2.
- msg 15 (Supabase install, 1.6 ГБ) — **скачан в 06:33Z**, на диске, **транскрибация НЕ запускалась** в момент handoff (ждёт heartbeat tick или v2 ручного запуска).
- После транскрибации msg 15 → msg_manifest обновится, v2 должен обогатить L2 модуль.

#### 9. Секретарский аккаунт @RoyalPalaceAddress

- Gede, +62..., зареган на sms-activate 2026-04-20.
- 2FA-пароль БЫЛ на номере от прошлого владельца, сбросили через email. Новый пароль у Ильи в хранилище.
- Email `s@gmail.com` (его = `ilianberawa@gmail.com`, показано в настройках).
- **Если v2 понадобится** переавторизовать CLI (`telegram auth`) — пароль 2FA нужен будет.

#### 10. Server-side disk

- `/opt/tg-export/` — 65 МБ медиа + 3.2 МБ транскриптов + логи
- Aeza: 58 GB total, 34 GB used → **24 GB свободно**. Достаточно на оставшиеся 4 видео (~8 GB pre-transcribe).
- **Гатча:** `/_chunks/` не-идемпотентен. Если transcribe падает mid-chunk — файлы останутся. verify.sh ловит это как `STALE_CHUNKS`.

---

**Final self-audit (context usage):** критическая зона. Не буду больше ничего добавлять, v2 continues с тем что выше.

HANDOFF_NEEDED ✅ (закрываю v1)

---

### v1 amendments — checklist (дополнение по запросу school, строгий формат)

#### 1. Heartbeat (P0)
Последняя свежая точка — verify.sh прошёл `ALL CLEAN ✓` в 04:30Z (сегодня). После этого новые инциденты в текущей сессии НЕ проверял. Download был на `[break] ~19min` в 06:33Z (msg 15 только что скачан). С 06:33Z до сейчас — SSH не дёргал. **Нужно v2 проверить первым делом:** `tail -20 /opt/tg-export/heartbeat.log` + `cat _status.json`.

#### 2. Download P4 (P0)
12/16 done. Остались **72, 82, 97, 103**. Очередь сортируется `priority ASC, size ASC` — все HIGH_CODE, значит по размеру: **103 (2011MB) → 72 (2061MB) → 97 (2175MB) → 82 (2838MB)**. Скорее всего сейчас качается **msg 103**. ETA остальных 3 ≈ 2-4 часа (с паузами). Бюджет Grok ещё ~$3.8, хватит.

#### 3. Telegram bot curl (P0)
```bash
# На Aeza:
source /opt/tg-export/.env
curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=MSG_HERE" \
  -d "parse_mode=HTML"
```
BOT_TOKEN=46 chars, CHAT_ID=10 digits (personal Ильи). Оба в `/opt/tg-export/.env` chmod 600. Бот: **@PROPERTYEVALUATOR_bot** (id 8637638856).

#### 4. LightRAG endpoint (P1)
- Базовый URL: `http://localhost:9621` (на Aeza, внутри docker network `realty_net` — имя `realty_lightrag:9621`).
- Ingest: `POST /documents/text` (JSON `{"text":"...", "description":"..."}`)
- Query: `POST /query` (JSON `{"query":"...", "mode":"hybrid"}` — modes: `naive|local|global|hybrid|mix`)
- Health: `GET /health`
- **auth_mode: disabled** — API-key НЕ требуется в текущей конфигурации (подтверждено `/health` response).
- LLM binding: `claude-haiku` через `http://realty_litellm:4000`. Embeddings: `all-minilm` через `http://realty_ollama:11434`.

#### 5. Paperclip heartbeatInterval (P1)
**НЕ проверил в живом конфиге** (Paperclip на Aeza не ставил, `~/.paperclip/` отсутствует). По msg_147 и README: настраивается через **UI дашборда per-agent**, не через global config.json. Предполагаю формат — секунды (int), записывается в `~/.paperclip/instances/default/config.json` под `agents[].heartbeatInterval` или аналог. **v2 TODO:** поставить Paperclip локально → `cat config.json | jq '.agents'` для подтверждения.

#### 6. Grok STT rate limit (P1)
Из x.ai docs: **REST: 600 RPM + 10 RPS, Streaming: 100 concurrent sessions**. В нашей практике: 14 транскриптов, ~90 chunks (10min каждый), 0 rate-limit hits. **Ключевой лимит — не RPM а $$:** $0.10/час audio, $5 budget → 50h/cycle. Для parser: если начнёт транскрибить — эти же лимиты, но **тот же XAI_API_KEY = общий budget** (если не заведёт отдельный).

#### 7. jq merge (P2)
⚠️ **Критично:** `merge_transcripts.py` — это **standalone recovery script** на `/opt/tg-export/merge_transcripts.py`. `transcribe.sh` в текущем виде всё ещё использует **старый jq-merge** внутри себя (я не заменил функцию в transcribe.sh, только запускал Python вручную для 164/165). **v2 TODO:** заменить jq-блок в transcribe.sh на вызов `python3 /opt/tg-export/merge_transcripts.py ${BASE_NAME}` — иначе следующий 2h транскрипт снова упадёт на jq. Bug воспроизводится только для >8000 word-level timestamps.

#### 8. Verify.sh integrity checks (P2)
1. **MISSING** — файл в манифесте, на диске нет, транскрипта нет
2. **SIZE_MISMATCH** — actual size ≠ expected
3. **ZERO-BYTE** — файл 0 байт
4. **ORPHAN** — на диске есть, в манифесте нет
5. **LEFTOVER_PART** — `_part000.json` остался после merge
6. **TRANSCRIPT_NO_TXT** — есть .json, нет .txt
7. **TRANSCRIPT_NO_JSON** — обратная
8. **BROKEN_JSON** — json.load() падает
9. **EMPTY_TRANSCRIPT_TEXT** — .text поле пустое
10. **ZERO_DURATION** — duration=0 (Grok не ответил)
11. **STALE_CHUNKS** — `_chunks/` не пуст после transcribe

#### 9. sync_channel.mjs (P2)
Детекция **file-based, не Postgres**. Алгоритм: читает `/opt/tg-export/library_index.json` → вычисляет `maxKnown = max(post.msg_id for post in posts)` → `iter_messages({limit: 500})` → filter `msg.id > maxKnown AND NOT in knownIds`. Новые добавляются в начало массива posts, JSON перезаписывается. Announcement dedup через `/opt/tg-export/announced.txt` (append-only список). **Race-риск:** если v2 читает `library_index.json` во время обновления sync — inconsistent read. Решение — копия файла на старте v2.

#### 10. Hidden bugs/гатчи (P3)

- **__MACOSX/ мусор в Paperclip unpacked:** `/opt/tg-export/_paperclip_unpacked/__MACOSX/` содержит `._*` файлы (metadata macOS). Не критично, но захламляет find-результаты. `rm -rf /opt/tg-export/_paperclip_unpacked/__MACOSX` — безопасно.
- **9 пустых постов в library_index** (msg_id: 26-31, 34, 67, 112) — помечены `kind=empty_or_deleted`, отфильтрованы из MD но остаются в JSON. v2 может пропускать их в ingest.
- **msg_171 (0-byte preview)** — удалён вручную из media/, но **если sync_channel подхватит новый preview-embed** — может появиться снова. Добавить в download.mjs filter: `if size===0 && !msg.document && !msg.photo: skip`.
- **node_modules на /opt/tg-export/** (19 МБ) — легитимно, нужны для gramJS. Не путать с orphans при verify.sh.
- **last_sync.json не создан** — я ссылался на него в canon_training.yaml но реально сохраняется в самом library_index.json (`generated` timestamp). v2 не искать отдельный файл.
- **CHAT_ID переименован из TELEGRAM_ADMIN_CHAT_ID** при импорте в /opt/tg-export/.env. Если v2 будет читать realty-portal/.env — там оригинальное имя.
