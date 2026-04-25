# Handoff: parser-rumah123-v1 → parser-rumah123-v2

**Дата передачи:** 2026-04-21, ~14:00 WITA
**От:** parser-rumah123-v1 (сессия Claude Desktop, ~60% контекста)
**Кому:** parser-rumah123-v2 (следующая сессия)
**Триггер переезда:** завершён эксперимент, накопился большой контекст библиотеки Алексея + ответы в школу, Илья запросил переезд.

## Что ты (v2) делаешь при старте

1. Прочитать `docs/school/canon_training.yaml` (общий манифест, роли, 10 принципов)
2. Прочитать `docs/school/mailbox/outbox_to_parser.md` (свежие директивы от школы)
3. Прочитать **этот файл** (handoff) + `parser-rumah123_v2.json` (machine-readable state)
4. Прочитать `docs/school/mailbox/inbox_from_parser.md` (твой собственный предыдущий ответ, сверху вниз)
5. Продолжить работу с раздела **«Что ждёт в очереди» ниже**

---

## Роль

Ты — `parser-rumah123-v1` в BU2 (Content Factory). Но это сессия **v2** той же роли (канон: `one_role_one_chat` — v1 закрывается Ильёй после твоего handoff read).

**Зона правок:** `scrapers/` + `scripts/` + Supabase schema + собственные логи на Aeza.
**НЕ трогать:** `docs/school/**` (принадлежит school-v1), `/opt/tg-export/**` (принадлежит librarian-v1), чужие ключи.

---

## Состояние эксперимента на момент handoff

### Pipeline V4 overnight — ЗАКРЫТ

| Метрика | Значение |
|---|---|
| Total properties в Supabase | **422** (normalization_status=complete) |
| Растёт с 81 → 422 за 14 часов | x5.2 масштаба |
| raw_listings.detail_status | 311 ok / 70 blocked / 41 not_found / 0 pending |
| Canggu + Berawa area records | 350 (83% базы) |
| LLM spend итого | $2.82 (525 Haiku calls, 0 ошибок) |
| Стоимость за объект | $0.0067 |

### CSV snapshots в хранилище (готовы для оффлайн-анализа)

Путь: `realty-portal/snapshots/2026-04-21/`
- `properties_snapshot.csv` — 422 записи
- `broker_inventory.csv` — 8 phone-кластеров (все на колл-центр Rumah123)
- `raw_listings_index.csv` — 422 URL со статусами
- `llm_usage_full.csv` — журнал 525 LLM-вызовов

### Активные процессы на Aeza (выживают при reboot Claude Desktop)

```
PID 1305546  night_monitor.sh       каждые 10 мин → /var/log/realty/heartbeat.log
PID 1322063  2h_reporter.sh         каждые 2 ч   → /var/log/realty/2h_reports.log
(V4 pipeline закончился, его PID уже нет)
```

**Проверка живучести:**
```bash
ssh root@193.233.128.21 'pgrep -af "night_monitor|2h_reporter"'
```

### Текущие нерешенные баги / технический долг

1. **`seller_type` колонка NULL для всех 422** — Haiku корректно извлекает значение, но UPSERT в `normalize_listings.py` не пишет. Нужен SQL UPDATE плюс патч кода. Ждёт approval.
2. **`contact_phone` = один номер Rumah123 office** — реальные phones спрятаны за JS reveal. 154/422 "phones" = `+62 21 30496123`. Фикс: Playwright или смена источника на Lamudi/Fazwaz.
3. **17% CF stable-block** на detail pages — 70 URL не доступны. Retry после cooldown + смена IP решит частично.
4. **LiteLLM fallback key в normalize_listings.py:40-42** — нарушение канона #6. План согласован со школой (задача 2 в inbox).

---

## Канон-сверка

### Применено в v1 (hard rules соблюдались)

- `3_simple_nodes` — три независимых скрипта (monitor / reporter / pipeline)
- `6_single_secret_vault` — `/opt/realty-portal/.env` chmod 600, единый (нарушение только в fallback кода — план устранения готов)
- `7_offline_first` — весь стек на Aeza, LiteLLM port 4000 только 127.0.0.1-binding
- `10_content_factory_model` — парсинг → нормализация → готово к пересборке

### Нарушено в v1 (v2 должен исправить после approval от школы)

- `9_human_rhythm_api` — heartbeat работает на фиксированных таймерах `sleep 600/7200`, регулярность детектируется CF. Нужен event-driven redesign. Ждёт approval школы (задача 1).
- `2_minimal_integration_code` — scraper/fetcher дублируют HTTP-логику, обе на Python вместо n8n-нод. Отмечено в задаче 3.
- `4_skills_over_agents` — LightRAG/pgvector развёрнут, но не используется для tenure inference. Отмечено в задаче 3 (скилл `tenure_inference_skill` как канон).

---

## Что ждёт в очереди (делать по приоритету)

### P0 — approval-dependent

Ждём от Ильи/школы решений по 4 вопросам (см. раздел **«Что прошу у школы дальше»** в `inbox_from_parser.md`):

1. **Heartbeat redesign** — event-driven вместо таймеров. Approval → делать в v2.
2. **LiteLLM key fallback plan** (15 мин) — убрать `.get(default)` из `normalize_listings.py:40-42` + `source .env` wrapper. Approval → делать первым в v2.
3. **Sonnet 4.5 + Kimi K2** подключить в LiteLLM (20 мин). Approval → делать.
4. **Пример «тормоза парсера»** от Ильи — какой именно кейс он имел в виду.

### P1 — tech debt (делать после любого из P0)

5. **Fix `seller_type` UPSERT** в `normalize_listings.py`. Колонка есть (`ALTER TABLE` был 2026-04-20), но в `UPSERT_SQL` нет `seller_type = EXCLUDED.seller_type`. Одно SQL-добавление + ретриггер `--refresh --all` на 311 records с detail.
6. **Final refresh normalize** после fetch_details завершения → 127 новых detail записей ещё не refresh-nuty. Команда: `python3 scripts/normalize_listings.py --refresh --all`. ~10 мин Haiku.
7. **Baseline v3 frozen snapshot** — после refresh: rerun `.export_snapshots.py`, положить в `realty-portal/snapshots/2026-04-21-v3/`, коммит (git не трогает `alexey-reference/**`, только snapshots).

### P2 — расширение (с approvals)

8. **LiteLLM `fallbacks:` config** (Groq 429 → deepseek-chat). Канон-совет.
9. **tenure_inference_skill** (LightRAG-powered) — закрывает 39% unknown на текущих записях.
10. **Scraper v3 с Playwright** или переход на Lamudi/Fazwaz — для реальных phones.

---

## Технические routes (для будущих SSH-вызовов)

```
SSH:                 root@193.233.128.21 via C:/Users/97152/.ssh/aeza_ed25519 (paramiko)
Postgres (host):     172.18.0.13:5432 user=postgres (pass in /opt/realty-portal/.env)
LiteLLM (host):      http://172.18.0.6:4000 + Bearer $LITELLM_MASTER_KEY
LiteLLM (docker net): http://realty_litellm:4000
Supabase-db exec:    docker exec supabase-db psql -U postgres -d postgres
Project root (Aeza): /opt/realty-portal/
Scraper scripts:     /opt/realty-portal/scrapers/rumah123/{run.py, fetch_details.py}
Normalizer:          /opt/realty-portal/scripts/normalize_listings.py
Monitor/reporter:    /opt/realty-portal/scripts/{night_monitor.sh, 2h_reporter.sh, morning_report.sh}
Logs:                /var/log/realty/{heartbeat.log, 2h_reports.log}
                     /tmp/{night_v4.log, fetch_all.log, fetch_remaining.log}
Recovery playbook:   /opt/realty-portal/RECOVERY.md
```

### Local paths (Windows)

```
Working dir:         C:\Users\97152\Новая папка
Project:             C:\Users\97152\Новая папка\realty-portal\
Snapshots:           realty-portal\snapshots\2026-04-21\
School mailbox:      realty-portal\docs\school\mailbox\
Library (read-only): C:\Users\97152\Новая папка\.library_cache\   (Q3/Q4 unpacked zips)
Aeza library src:    /opt/tg-export/{library_index.json,media/*}
SSH key:             C:\Users\97152\.ssh\aeza_ed25519
LiteLLM master key:  из /opt/realty-portal/.env → LITELLM_MASTER_KEY
```

### Важные переменные окружения (fail-loud после задачи 2)

```
DATABASE_URL          = postgresql://postgres:<pass>@172.18.0.13:5432/postgres
LITELLM_MASTER_KEY    = sk-... (в /opt/realty-portal/.env)
LITELLM_URL           = http://172.18.0.6:4000/v1/chat/completions
NORMALIZER_MODEL      = claude-haiku
IDR_PER_USD           = 16000 (magic number — задача 3 пункт 6)
```

---

## Библиотека Алексея — прочитано v1

Локально в `.library_cache/` распакованы для read-only:
- `library_index.json` (151 пост от Алексея Колесова, 275 KB)
- `16_ai_seller_rag_unpacked/` — главный Q4 референс (промпты «Юлии» + 3 n8n workflows + SQL schema)
- `14_supabase_unpacked/` — supabase compose + env шаблон
- `17_sql_query.txt` — canonical SQL (agent_prompt_instructions / chat_histories / message_logs / documents / stocks + match_documents/match_stocks functions)
- `30/31/32_supabase_*.json` — n8n workflows (add_docs_to_db, ai_consultant_with_memory ⭐, update_stocks)
- `177_telegram_unpacked/` — Q3 telegram skill с INSTALL.md + anti-spam правила

**Резюмировано в `inbox_from_parser.md` + обратной рекомендацией школе.** v2 может перечитать `.library_cache/` для детализации если нужно.

### Ключевые архитектурные паттерны Алексея (для v2 применимо):

| Pattern | Файл | Применимо у нас |
|---|---|---|
| 1 agent + 2 vector tools + Postgres chat memory | `ai_seller_rag/шаблоны/supabase/supabase_ai_consultant_with_memory.json` | Для conversation с агентами недвижимости (Задача 3 inbox) |
| pgvector + match_documents/match_stocks function | `17_sql_query.txt` | Для tenure_inference_skill (v2 может проектировать) |
| Промпты хранятся в БД (не в коде) | `agent_prompt_instructions` table | Нужно добавить в нашу схему Supabase |
| Whisper transcribe для voice-to-text | Workflow pattern | Для voice-ответов от агентов на индонезийском |
| OpenRouter multi-model | Workflow pattern | У нас LiteLLM — эквивалент |
| Отдельный TG-аккаунт через sms-activate | `177_telegram_unpacked/telegram/INSTALL.md` | Канон для TG outreach — не делать с основного |
| Read-only mode by default + write-access toggle | Тот же INSTALL.md | Safety pattern для любого write-ready skill |

---

## Конкретные команды для v2 (cheatsheet)

### Проверить что всё живо

```bash
ssh root@193.233.128.21 'pgrep -af "night_monitor|2h_reporter"; bash /opt/realty-portal/scripts/morning_report.sh'
```

### Запустить final refresh normalize (после approval)

```bash
ssh root@193.233.128.21 'cd /opt/realty-portal && set -a; source .env; set +a; python3 scripts/normalize_listings.py --refresh --all --rate-limit 1 2>&1 | tail -50'
```

### Сделать baseline v3 snapshot

Локально: `python .export_snapshots.py` (уже написан, см. `C:/work/.export_snapshots.py`).  Может потребоваться поменять `OUT_DIR` на `2026-04-21-v3`.

### Отправить tg-уведомление Илье (когда добавит через `/telegram:access`)

MCP tool `plugin_telegram_telegram__reply`, chat_id `5642329195`.

---

## Mailbox — что открыто

- **`outbox_to_parser.md`** — 4 задачи от school-v1 (все ОТВЕЧЕНЫ в `inbox_from_parser.md`, ждут approvals на 3).
- **`inbox_from_parser.md`** — твой предыдущий (v1) ответ. ПЕРЕЧИТАТЬ СВЕРХУ ВНИЗ, самый свежий блок (от `2026-04-21`) — это то что читает школа сейчас.
- Если school-v1 обновит outbox после handoff — появится новый блок после твоего. Читать его в `outbox_to_parser.md`.

---

## Что НЕ делать v2

- ❌ Переписывать код без approval от школы (канон инвариант).
- ❌ Трогать `docs/school/**` за пределами `mailbox/inbox_from_parser.md` и `handoff/parser-rumah123_v2.md`.
- ❌ Править `/opt/tg-export/**` (домен librarian).
- ❌ Ротировать LiteLLM master_key до завершения фазы эксперимента (живые процессы зависят).
- ❌ Запускать новый scrape без канон-совместимого human-rhythm (v1 уже схватил CF-блоки).
- ❌ Убивать процессы `night_monitor.sh` / `2h_reporter.sh` на Aeza — они независимы и живут.

---

## Контекст-загрузка для v2

При чтении этого handoff + canon_training.yaml + outbox + inbox — v2 стартует с ~25-30% контекста. Остаётся 70%+ для реальной работы. До handoff **v3** есть большой запас.

При росте контекста в v2 до 70% — писать `parser-rumah123_v3.md` + `parser-rumah123_v3.json`.

---

## HANDOFF_NEEDED флаг

✅ **Установлен.** В `inbox_from_parser.md` следующий блок от v1 должен помечать `HANDOFF_NEEDED` — school-v1 увидит при очередном аудите и закроет v1 после подтверждения Ильи.
