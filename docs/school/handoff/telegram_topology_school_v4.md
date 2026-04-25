# Telegram Topology — передача school-v4

**Создан:** 2026-04-23 | **Автор:** school-v3 (infra session)  
**Для:** school-v4 при старте из ЛЮБОЙ директории / Linux-контейнера

---

## 1. Архитектура (что где живёт)

```
┌─────────────────────────────────────────────────────┐
│  Aeza VPS 193.233.128.21  /opt/tg-export/           │
│                                                     │
│  sync_channel.mjs  ←── MTProto session (gramjs)     │
│      ↓ каждые 6ч (cron 15 */6 * * *)               │
│  library_index.json (151 пост, оглавление)          │
│  media/ (P1-P4 файлы)                               │
│  transcripts/ (31 файл, ~15 видео)                  │
│      ↓                                              │
│  notify.sh ←── bot sendMessage                      │
│      ↓ каждые 2ч (cron 0 */2 * * *)                │
│  → PROPERTYEVALUATOR_bot → Илья (chat_id)           │
│                                                     │
│  heartbeat.sh (cron */10 * * * *)  ← self-healing   │
│  verify.sh    (cron 30 2 * * *)    ← daily integrity│
└─────────────────────────────────────────────────────┘
```

**Один экземпляр каждого процесса — инвариант.** Второй gramjs клиент с той же session разлогинит оба.

---

## 2. Cron на Aeza (активный)

| Schedule | Скрипт | Назначение |
|----------|--------|------------|
| `*/10 * * * *` | `heartbeat.sh` | self-healing, _status.json |
| `0 */2 * * *` | `notify.sh` | TG статус → Илье |
| `15 */6 * * *` | `sync_channel.mjs` | новые посты канала Алексея |
| `30 2 * * *` | `verify.sh` | daily integrity check |
| `@reboot` | `night_monitor.sh` | ночной pipeline |
| `@reboot` | `2h_reporter.sh` | 2-часовой репортёр |

---

## 3. Где credentials (БЕЗ значений — только пути)

| Что | Где хранится |
|-----|-------------|
| MTProto apiId/apiHash/sessionString | `/opt/tg-export/config.json5` (Aeza) + `launcher_school_v4.json` → `credentials.telegram_library_reader` |
| Bot token | `/opt/tg-export/.env` (BOT_TOKEN) + `/opt/realty-portal/.env` (TELEGRAM_BOT_TOKEN) |
| Grok STT key (XAI_API_KEY) | `/opt/tg-export/.env` |
| LightRAG key | `/opt/realty-portal/.env` → LIGHTRAG_API_KEY |
| Chat ID Ильи | `/opt/tg-export/.env` → CHAT_ID = 5642329195 |

**Читать credentials:** `ssh root@193.233.128.21 'cat /opt/tg-export/.env'` (через Илью как посредника)  
Или из `launcher_school_v4.json` секция `credentials` (прочитать напрямую если доступ к Windows FS).

---

## 4. Что school-v4 МОЖЕТ делать

| Действие | Как |
|----------|-----|
| Читать library_index.json | Попросить Илью: `ssh root@193.233.128.21 'cat /opt/tg-export/library_index.json'` |
| Читать конкретный транскрипт | Попросить Илью: `ssh root@193.233.128.21 'cat /opt/tg-export/transcripts/170_video.mp4.transcript.txt'` |
| Список транскриптов | `ssh root@193.233.128.21 'ls /opt/tg-export/transcripts/*.txt'` |
| Проверить статус cron | `ssh root@193.233.128.21 'tail -20 /opt/tg-export/heartbeat.log'` |
| Проверить свежие посты | `ssh root@193.233.128.21 'tail -5 /opt/tg-export/sync.log'` |
| Отправить в ТГ (одноразово в turn) | REST API sendMessage через python urllib (не polling!) |
| Написать ingest-скрипт | В vault/machine/code/ → передать Илье → он деплоит на Aeza |

---

## 5. Что school-v4 НЕ МОЖЕТ (runtime ограничение)

| Нельзя | Почему |
|--------|--------|
| Heartbeat cron | Процесс умирает между turn'ами — нет persistent runtime |
| MTProto polling | Одна session = один клиент, Aeza держит |
| getUpdates бота | Один polling process, уже на Aeza |
| gramjs в этой сессии | Нет node/npm, и нельзя параллелить session |

**Эти задачи принадлежат Aeza.** School-v4 = проектировщик артефактов, не runtime.

---

## 6. Node.js окружение на Aeza (для скриптов)

```
Node:     v18.19.1
gramjs:   установлен в /opt/tg-export/node_modules/
Путь:     /opt/tg-export/
Session:  /opt/tg-export/config.json5 (apiId + apiHash + sessionString)
```

Если нужно запустить одноразовый MTProto скрипт через Илью:
```bash
ssh root@193.233.128.21 'cd /opt/tg-export && node <твой_скрипт.mjs> 2>&1 | head -50'
```

---

## 7. LightRAG — текущий статус

**Пустой (Total: 0).** Ingest не делался.  
API: `http://localhost:9621` (на Aeza, порт не проброшен наружу)  
Key: `/opt/realty-portal/.env` → LIGHTRAG_API_KEY

Что нужно сделать (P1 задача librarian-v3):
```
Phase 1: залить 3 транскрипта (msg 170, 55, 147)
Phase 2: остальные 15 транскриптов  
Phase 3: library_index.json (151 запись) как отдельные документы
```

**Артефакты которые school-v4 может написать:**
- `vault/machine/code/ingest_transcripts.py` — stdlib-only, POST /documents/text, doc_id="tg-{msg_id}"
- `vault/machine/code/ingest_library_index.py` — каждая запись из library_index.json как документ
- `vault/machine/code/lightrag_dedupe.py` — проверка что уже залито

Деплой: Илья делает `scp script.py root@193.233.128.21:/opt/tg-export/` → запускает.

---

## 8. announced.txt — алгоритм новых постов

```
Файл:   /opt/tg-export/announced.txt
Формат: один msg_id на строку
Последний: 179

Алгоритм (sync_channel.mjs делает это автоматически каждые 6ч):
1. library_index.json → все msg_id
2. announced.txt → уже обработанные  
3. diff → новые
4. sendMessage через бот → Илье
5. append msg_id → announced.txt
```

---

## 9. Как взаимодействовать (school-v4 в Linux-контейнере)

```
school-v4 (Linux vault) 
    ↓ пишет команду или скрипт
Илья (посредник)
    ↓ копирует команду в этот чат (school-v3 windows сессия)
    ↓ ИЛИ запускает сам в терминале
Aeza VPS
    ↓ возвращает результат
Илья
    ↓ вставляет вывод обратно
school-v4
```

**Шаблон запроса school-v4 к Илье:**
```
Илья, выполни на Aeza:
ssh root@193.233.128.21 'команда'
И скинь мне вывод.
```

---

## 10. Ротация секретов (URGENT)

Следующие секреты утекли в этом чате — ротировать до начала работы:

| Секрет | Как ротировать |
|--------|---------------|
| Bot token | @BotFather → /revoke → обновить в `/opt/tg-export/.env` + `/opt/realty-portal/.env` |
| XAI_API_KEY (Grok STT) | console.x.ai → API Keys → regenerate → обновить в `/opt/tg-export/.env` |
| LIGHTRAG_API_KEY | `openssl rand -hex 20` → обновить в `.env` + docker-compose → `docker compose up -d --force-recreate lightrag` |
| sessionString | Telegram → Settings → Devices → завершить сессию gramjs → пересоздать на Aeza |
| LiteLLM master key | уже ротирован 2026-04-23 (sk-27b4b513...) |

После ротации — обновить `launcher_school_v4.json` секцию `credentials` (кроме sessionString — не хранить в файлах).

---

*Создан school-v3 infra session 2026-04-23. Актуален пока топология Aeza не меняется.*
