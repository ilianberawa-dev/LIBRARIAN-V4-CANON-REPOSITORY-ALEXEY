# 📦 ПАКЕТ ПЕРЕДАЧИ — РАЗВЕРТЫВАНИЕ TG-ПАРСЕРА (Фаза 1)

**Дата:** 2026-04-28  
**От:** Архитектор (librarian-v4)  
**Кому:** TG-parser deployer (второй чат)  
**Статус:** Ожидает GO от Ильи

---

## Ответы на 3 вопроса

### 1. Сервер

Не Aeza (она мертва, не подключаемся). Новый VPS:

```
Provider:  UpCloud SGP1 (Singapore)
Plan:      Premium $26/mo (2 CPU / 4 GB RAM / 50 GB NVMe MaxIOPS)
Backup:    Weekly +$5.20/mo (включается в UpCloud panel)
OS:        Ubuntu Server 24.04 LTS (Noble Numbat)
Host:      213.163.207.84
Port:      22
SSH user:  (попросить у владельца — ждёт ту же информацию)
```

### 2. Credentials

Под рукой у владельца (предоставит при GO):

```
TG_API_ID         = 33841401
TG_API_HASH       = 90cd3efd6255ae4df2376940b2181f77
TG_PHONE          = +971524725200
BOT_TOKEN         = (нужен НОВЫЙ бот через @BotFather, не переиспользовать personal-assistant'овый)
CHAT_ID           = (нужен отдельный канал для анонсов постов Алексея,
                     или согласовать с владельцем переиспользование канала -1003840120630)
XAI_API_KEY       = (попроси у владельца — использовался в старом transcribe.sh)
HCPING_URL        = (отдельный check на healthchecks.io, НЕ переиспользуй
                     hc-ping.com/87a5c94d-2773-4c3c-b247-4de93668d38a — это personal-assistant'a)
TG_SESSION_STRING = ⚠️ генерируется auth-скриптом на сервере с SMS-кодом,
                     НЕ переиспользуй personal-assistant'овый session string
                     (Canon #11 Privilege Isolation — раздельные сессии на каждый сервис)
```

### 3. library_index.json

Перенос обязателен. Файл уже в репо:

```
Repo:   ilianberawa-dev/librarian-v4-canon-repository-alexey
Branch: claude/setup-library-access-FrRfh
Path:   aeza-archive/library_index.json   (278 KB, 142 поста с метаданными)
```

Стартовать с нуля = заново парсить весь канал = риск бан + потеря истории.  
Делай `git clone` репо → копируй `aeza-archive/library_index.json` в `/opt/tg-export/library_index.json`

---

## ⚠️ CRITICAL: ты не один на сервере

На том же UpCloud `213.163.207.84` параллельно деплоится **personal-assistant (Stage 1)**. Worker #1 уже создал draft PR #5 с 6 файлами и ждёт GO. Чтобы не конфликтовать:

### Изоляция (Canon #11)

|  | personal-assistant | TG-парсер (твой) |
|---|---|---|
| Systemd user | `personal-assistant` | `tg-export` (создавай свой) |
| Путь приложения | `/opt/personal-assistant/` | `/opt/tg-export/` |
| Путь логов | `/var/log/personal-assistant/` | `/var/log/tg-export/` |
| .env | `/opt/personal-assistant/.env` chmod 600 | `/opt/tg-export/.env` chmod 600 |
| Systemd units | `personal-assistant-*.service` | префикс `tg-export-*` |
| MemoryMax | 300M | рекомендую 200M |

### Память (всего 4 GB)

```
personal-assistant limit:  300 MB
tg-parser estimate:        150-300 MB (Node bare-metal)
система + буферы:          ~500 MB
свободно для Phase 2:      ~3 GB → недостаточно для 17 Docker контейнеров (4-5 GB)
```

→ **Phase 2 на этом сервере НЕ влезет**, владельцу нужен отдельный VPS под Supabase/LightRAG. Эскалируй прорабу.

### Координация деплоев

- НЕ деплой одновременно с personal-assistant — конфликт apt locks, npm cache, systemctl reloads
- Согласуй с прорабом порядок: либо Worker #1 сначала, либо ты
- Сообщи прорабу когда начинаешь и когда закончишь

---

## Источник кода (Quick Clone)

Репо `ilianberawa-dev/librarian-v4-canon-repository-alexey`, ветка `claude/setup-library-access-FrRfh`, директория `aeza-archive/` — это рабочий код парсера с Aeza. Все пути в коде захардкожены под `/opt/tg-export/...`:

```
aeza-archive/
├── README.md                  — описание
├── config.json5               — шаблон конфига (apiId, apiHash, sessionString)
├── package.json               — npm deps (gramjs)
├── package-lock.json          — pinned versions
├── sync_channel.mjs           — MTProto listener для канала Алексея (cron /6h)
├── download.mjs               — скачивание файлов из канала
├── enumerate_p4.mjs           — enumerate priority 4 items
├── transcribe.sh              — Grok STT адаптер (нужен XAI_API_KEY)
├── ingest_transcripts.py      — Python ingest
├── merge_transcripts.py       — Python merge
├── heartbeat.sh               — proven watchdog (по канону)
├── notify.sh                  — Telegram notify helper
├── verify.sh                  — verify integrity
├── library_index.json         — 142 поста (history, не теряй)
├── p4_whitelist.txt           — whitelist
├── announced.txt              — что уже анонсировано
└── transcripts/               — готовые транскрипты
```

Захардкоженные значения, которые увидишь в `sync_channel.mjs`:

```javascript
const CHANNEL = 'Алексей Колесов | Private';
const CHANNEL_ID = 2653037830;
const CFG     = '/opt/tg-export/config.json5';
const LIBRARY = '/opt/tg-export/library_index.json';
```

---

## Канонические принципы (применяй к каждому шагу)

- **#1 Портативность** — bare-metal node + cron, никакого Docker для Phase 1
- **#2 Minimal Integration** — gramjs готов, не пиши свой MTProto wrapper
- **#5 Fail Loud** — если `.env` пустой → `process.exit(1)`, никаких fallback'ов
- **#6 Single Vault** — chmod 600, никаких хардкодов в `config.json5` (symlink на `.env`)
- **#9 Human Rhythm** — cron every 6 hours, не каждую минуту (Telegram бан)
- **#11 Privilege Isolation** — отдельный user `tg-export`, отдельная MTProto session, отдельный бот

---

## Критерии приёмки Фазы 1

- [ ] `systemctl list-timers` показывает `tg-export-sync.timer` каждые 6 часов
- [ ] Первый ручной запуск `sync_channel.mjs` от user `tg-export` сканирует канал и обновляет `library_index.json` без ошибок
- [ ] Если в канале появился новый пост с момента старта → notify в CHAT_ID за < 30 сек
- [ ] `heartbeat.sh` шлёт ping на HCPING_URL каждые 5/30 мин (день/ночь)
- [ ] `journalctl -u tg-export-* --since "10 min ago"` без ERROR/CRITICAL
- [ ] Память процесса < 300 МБ

---

## Жёсткие запреты

- ❌ No Docker для Phase 1 (Принцип Алексея)
- ❌ Не подключайся к старой Aeza `193.233.128.21` — она мертва
- ❌ Не используй `/opt/secrets/` — Single Vault в `/opt/tg-export/.env` (chmod 600, owner `tg-export`)
- ❌ Не запускай `sync_channel.mjs` от root — только от user `tg-export`
- ❌ Не переиспользуй MTProto session string personal-assistant'а — генерируй свой
- ❌ Не переиспользуй HCPING URL personal-assistant'а
- ❌ Не трогай `/opt/personal-assistant/`, `/var/log/personal-assistant/`, user `personal-assistant`
- ❌ Не модифицируй файлы в репо `aeza-archive/` — копируй на сервер «как есть», правки только в копии
- ❌ Не пытайся поднять Phase 2 broker-parser на этом сервере — 4 GB RAM не влезет, эскалируй прорабу

---

## 9-ступенчатый план деплоя

1. **PRE:** владелец подтверждает Backup ON в панели UpCloud; даёт `SSH_USER`, `BOT_TOKEN` (новый), `CHAT_ID`, `XAI_API_KEY`, `HCPING_URL` (новый)
2. **SSH:** `ssh <SSH_USER>@213.163.207.84` — проверь что уже стоит/не стоит personal-assistant, не сломай его
3. **Инструменты:** проверь `node -v` (LTS); если Worker #1 был раньше — уже стоит; иначе: `setup_lts.x + apt install nodejs git build-essential`
4. **User & dirs:** создай system user `tg-export`, директории `/opt/tg-export/` (chmod 750), `/var/log/tg-export/` (chmod 750)
5. **Код:** `git clone` репо во временный путь, скопируй содержимое `aeza-archive/` в `/opt/tg-export/` (`chown tg-export:tg-export`)
6. **.env:** создай `/opt/tg-export/.env` chmod 600 с `TG_API_ID`, `TG_API_HASH`, `BOT_TOKEN`, `CHAT_ID`, `XAI_API_KEY`, `HCPING_URL`
7. **Auth:** запусти MTProto auth-скрипт — СТОП, попроси SMS-код у владельца через прораба, добавь `TG_SESSION_STRING` в `.env`
8. **systemd:** напиши `tg-export-sync.timer` (каждые 6ч) + `tg-export-sync.service`; аналогичный таймер для `heartbeat.sh` (5 min day / 30 min night) — hardened (`NoNewPrivileges`, `ProtectSystem=strict`, `MemoryMax=200M`)
9. **Test:** ручной запуск → `systemctl start tg-export-sync.service` → `journalctl -u tg-export-sync -f` → проверь library_index.json и Telegram уведомление

---

## Что нужно от прораба до GO

1. Подтверждение что канал `Алексей Колесов | Private` (ID 2653037830) активен и доступен
2. Решение: новый bot/channel для tg-parser или переиспользовать `-1003840120630` (AI Assistant)?
3. Решение: deploy order — параллельно с Worker #1 нельзя, кто первый?
4. Подтверждение: Phase 2 (broker-parser Docker) на ОТДЕЛЬНОМ сервере, не на этом 4GB?

---

## ACK ожидается

```
TG-parser deployer ready, handoff received, plan understood,
awaiting GO + SSH_USER + BOT_TOKEN + CHAT_ID + XAI_API_KEY + HCPING_URL
+ confirmation of deploy order (before/after personal-assistant Stage 1)
```
