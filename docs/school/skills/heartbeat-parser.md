---
name: heartbeat-parser
version: 0.1
status: DESIGN (pending school review → imp approval отдельно)
owner: parser-rumah123
author: parser-rumah123-v2
date: 2026-04-21
canon_refs: [9_human_rhythm_api, 5_minimal_clear_commands, 3_simple_nodes, 4_skills_over_agents]
inspired_by: /opt/tg-export/{download.mjs, heartbeat.sh} (librarian v1 эталон)
---

# heartbeat-parser — SKILL для parser-rumah123

## TL;DR (30 sec)

Два слоя. **Layer 1** (infra): cron-watchdog, «жив ли процесс, не застрял ли». **Layer 2** (human-rhythm): процесс сам имитирует живого человека ночью — разные паузы, событийная реакция на 403, длинные перерывы. Layer 1 доверяет Layer 2: процесс декларирует в лог «сплю 14 мин» → watchdog это читает → не бьёт тревогу зря. Состояние фиксируется в `_status.json` (atomic snapshot), восстановление после crash — через `manifest.phase_finished`.

## Когда применять

- Любой long-running процесс parser-rumah123 на Aeza (scrape / fetch_details / normalize / refresh).
- Замена текущих `night_monitor.sh`, `2h_reporter.sh`, `night_v4.sh` на единый паттерн.

## Не-цели

- Это не cron-симулятор. Фиксированные `sleep 600` — отвергается (канон #9, msg_147 + Ilya 2026-04-21).
- Это не Layer 2 «AI-tick» (Paperclip-стиль с LightRAG-контекстом) — это будет отдельный skill heartbeat-agent-tick в следующей итерации.

---

## Архитектура

```
┌─ Layer 1 (infra watchdog) ─────────────────────────┐
│  cron */5  →  heartbeat.sh  →  reads:              │
│                 • pgrep pipeline procs             │
│                 • pipeline.log mtime + last tag    │
│                 • manifest.json phase_finished     │
│               writes:                              │
│                 • _status.json  (atomic)           │
│                 • heartbeat.log (append, rotated)  │
│               actions:                             │
│                 • restart if idle > expected + 5m  │
│                 • skip if manifest.finished        │
│                 • notify (Telegram push — когда    │
│                   разрешение придёт)               │
└─────────────────────────────────────────────────────┘
          ▲                               │
          │ reads log tags                │ reads manifest
          │                               ▼
┌─ Layer 2 (human-rhythm в процессе) ────────────────┐
│  pipeline.sh / run.py / fetch_details.py           │
│   • декларирует в лог: [sleep-short ~45s]          │
│                         [break ~12min]             │
│                         [long-break ~53min]        │
│                         [cf-switch path=villa→land]│
│   • пишет manifest после каждого URL               │
│   • события → изменение ритма, не только таймер    │
└─────────────────────────────────────────────────────┘
```

Эта двухслойная модель — прямой наследник librarian (`heartbeat.sh` + `download.mjs`). Parser принимает те же паттерны, константы адаптированы под scrape-трафик.

---

## Layer 1: контракт `scripts/heartbeat.sh`

Запуск: **cron каждые 5 минут** (не 10 как у librarian — у parser циклы короче).

Шаги:

1. **check_each_worker** для 3 worker-ов: `list_scraper`, `detail_fetcher`, `normalizer`. Для каждого:
   - `pgrep -f` → pid (или пусто)
   - mtime `<worker>.log`
   - парсинг последнего expected-duration тэга из последних 10 строк лога: `[sleep-short ~Ns]`, `[break ~Nmin]`, `[long-break ~Nmin]`, `[cf-cooldown ~Nmin]`
   - если pid есть и `now - mtime_log > expected + 5min` → **stuck**: kill + relaunch, log `[stuck→restart]`
   - если pid нет и `manifest.<worker>_finished` → **completed**, skip
   - если pid нет и manifest не завершён → **dead**: relaunch
2. **_status.json** (atomic write через `cat > … <<EOF` как у librarian):
   ```json
   {
     "updated": "ISO UTC",
     "list_scraper":   {"pid":"...", "status":"running|stuck|restarted|completed|dead", "idle_sec": 0, "action":"none"},
     "detail_fetcher": {"pid":"...", "status":"...", "idle_sec": 0, "action":"none"},
     "normalizer":     {"pid":"...", "status":"...", "idle_sec": 0, "action":"none"},
     "counters": {
       "raw_listings_pending": 0,
       "detail_status_pending": 0,
       "properties_complete": 422,
       "cf_blocked_last_hour": 3,
       "zero_progress_min": 0
     },
     "litellm": {"last_429_sec_ago": 120, "fallback_active": false}
   }
   ```
3. **rotate_logs** (>10 MB → mv с timestamp) — 1-к-1 как librarian.
4. **heartbeat.log append** — по строке `[tick] status=ok|restarts=N|…`.

Канон #3 (simple nodes): `heartbeat.sh` — ОДНА задача «жив ли и не застрял ли». Отчётность (цифры SQL, cost) — отдельный скрипт `report.sh` по cron */30 или /60.

---

## Layer 2: human-rhythm в worker-процессах

### Константы (предлагаемые, ревизовать)

| Параметр | Диапазон | Когда |
|---|---|---|
| `SHORT_MIN..SHORT_MAX` | 30-120 сек | между URL в одной wave |
| `BURST_EVERY` | 8-20 URL | после burst — `break` |
| `BREAK_MIN..BREAK_MAX` | 5-15 мин | после burst |
| `LONG_EVERY` | 4-7 break-ов | после — `long-break` |
| `LONG_MIN..LONG_MAX` | 20-90 мин | «отвлёкся/поел/поспал» |
| `CF_COOLDOWN` | 15-60 мин | когда detect 403-блок на URL |
| `DISTRACTION_PROBABILITY` | 8% per URL | случайная длинная пауза (20-90 мин) |

Parser-специфика vs librarian:
- короче `SHORT` (30-120 vs 60-300) — HTTP-запросы легче чем TG-медиа
- `CF_COOLDOWN` — новая категория, у librarian её нет (TG rate-limit возвращает explicit `seconds`, у CF нет)
- `DISTRACTION_PROBABILITY` — канон, добавлен по моему ответу v1 (инсайт 3)

### Событийные реакции (канон #9 msg_147 + Ilya 2026-04-21)

1. **HTTP 403 на detail-URL → не retry, а переключить path**.
   В `fetch_details.py` сейчас: retry через 60с → ещё retry → mark blocked. Новое: получили 403 → log `[cf-switch]` → отдать URL в «cooldown-очередь» (retry через 15-60 мин) → взять URL из другого подраздела (villa→land→apartment). Канон: «человек не упирается лбом в дверь».
2. **Пустой output normalize → пауза 30-90 мин, не следующая задача**.
   Когда `SELECT status='pending' LIMIT 50` возвращает 0 строк → log `[pipeline-idle]` → `sleep rnd(LONG_MIN, LONG_MAX)`. Worker не ложится мёртвым — он «отошёл попить чай».
3. **Случайная длинная пауза** с вероятностью ~8% — после любого URL (worker сам бросает кубик).
4. **Шахматная асинхронность между фазами**. Сейчас Phase A (scrape list) → Phase B (fetch detail) → Phase C (normalize) — жёстко последовательно. Новое: 3 независимых worker-а, каждый берёт работу из своей очереди в SQL, с собственным human-rhythm. Канон #3 (simple nodes): один worker = одна фаза.
5. **Singleton-lock** на каждый worker (pg advisory lock `pg_try_advisory_lock(<hash>)`). Если я дважды запускаю worker — второй упадёт с `[lock-held]` (fail-loud). Исправляет затык №2 v1 inbox. Канон #5 (minimal clear commands).

### Expected-duration logging protocol

Каждый раз worker засыпает — пишет в свой лог:

```
[2026-04-21T11:04:17Z] [sleep-short ~47s]
[2026-04-21T11:06:23Z] [break ~11min]   reason=burst-end
[2026-04-21T11:17:48Z] [long-break ~54min]   reason=long-counter
[2026-04-21T11:18:03Z] [cf-cooldown ~32min]   url=/jual/badung/canggu/villa/xyz
[2026-04-21T11:20:13Z] [pipeline-idle ~41min]   reason=normalize-empty
```

Layer 1 `heartbeat.sh` парсит последний тэг и выставляет `expected_break` в секундах. Если `idle > expected + 5min` → stuck. (Точно как librarian `heartbeat.sh` для `download.mjs`).

### manifest.json контракт

`/opt/realty-portal/state/<worker>_manifest.json` — один файл на worker. Пишется после каждого SQL-коммита / HTTP-ответа / URL.

```json
{
  "worker": "detail_fetcher",
  "started": "2026-04-21T10:00:00Z",
  "last_url_ok": "...",
  "urls_done": 217,
  "urls_cf_blocked": 12,
  "urls_not_found": 3,
  "phase_finished": false,
  "finished": null,
  "summary": null
}
```

При штатном завершении worker пишет `finished: "ISO"`, `summary: {...}`, `phase_finished: true`. heartbeat.sh видит `phase_finished=true` → не рестартит.

---

## Telegram push (Layer 1 → Ilya)

Сейчас у parser push не работает (см. inbox v1 задача 1.1 — токен устарел, `.tg_push.env` не создан). Когда Ilya даст токен:

- `notify.sh <level> <msg>` — тоже как у librarian.
- Уровни: `tick` (молча в лог), `warn` (только в лог + `_status.json`), `alert` (push в TG + лог).
- Триггеры `alert`: два подряд `stuck` по одному worker; `zero-progress > 60 min`; `cf_blocked_last_hour > 50%`; LiteLLM 429 на всех fallback'ах.

Канон: `tick` — бесшумно, Ilya смотрит `_status.json` когда сам хочет. `alert` — только когда его внимание реально нужно. Не спамим.

---

## Observability

Один entry-point для Ilya:
```
bash /opt/realty-portal/scripts/status.sh
```
Читает `_status.json` + tail 5 строк у каждого worker log + SQL counters → печатает 10-строчный сводный отчёт.

Canon #3: `status.sh` ≠ `heartbeat.sh`. Heartbeat — авто, status — on-demand.

---

## Что изменится в существующем коде

| Файл | Изменение | Канон |
|---|---|---|
| `scripts/night_monitor.sh` | → `scripts/heartbeat.sh` (переработан по схеме выше) | #9, #3 |
| `scripts/2h_reporter.sh` | → `scripts/report.sh` (cron */30), без overlap с heartbeat | #3 |
| `scripts/night_v4.sh` | разбить на 3 worker-скрипта (scrape / fetch / normalize), каждый с собственным human-rhythm loop | #3, #9 |
| `scrapers/rumah123/run.py` | добавить log-tags + manifest write | #9 |
| `scrapers/rumah123/fetch_details.py` | + singleton pg-lock + CF-switch вместо retry-same-URL + log-tags + manifest | #9, #5 |
| `scripts/normalize_listings.py` | + `[pipeline-idle]` когда pending=0 + manifest | #9 |
| **NEW** `scripts/status.sh` | on-demand сводка для Ilya | #3 |
| **NEW** `scripts/notify.sh` | TG push когда разрешение придёт | #9 |

---

## Монетизация (канон `monetization_chain_required`)

1. **Снижение CF block rate с 17% → ~5%** (моя оценка в v1 inbox). На 422 базе = +~50 объявлений с phones/images/tenure за ту же ночь.
2. **Достоверные phones** → outreach к реальным агентам Бали (не колл-центр Rumah123).
3. **Контакт с агентом → возможная комиссия $10-50k со сделки** (Илья как брокер закрывает сделку через найденный источник).

Альтернативная цепочка — продукт, а не личная сделка:
1. Канон human-rhythm = BU2 «Content Factory» scraping стабильнее → меньше банов → больше данных.
2. SaaS для брокеров: «Bali inventory feed» $199-499/мес. Больше данных = выше retention.

Без heartbeat-skill масштабировать Content Factory на Lamudi/Fazwaz нельзя — копипаст текущих `night_*.sh` умножит проблемы.

---

## Что прошу у школы (прежде чем писать код)

1. **Ревизию констант** (SHORT/BREAK/LONG/CF_COOLDOWN). Могу консультироваться с librarian через канал inbox-librarian (или школа запросит у него через outbox).
2. **Решение**: Layer 2 в каждом worker-е как bash-loop вокруг Python одноразовых вызовов, ИЛИ как long-running Python со встроенным `asyncio.sleep` и event-bus? Первое проще и канонно (simple nodes), второе гибче (worker сам знает историю паттернов). По умолчанию — **первое**, если нет возражений.
3. **Singleton-lock подход**: pg advisory (я склоняюсь) или flock на pid-файл? Librarian использует pid-файл (`download.pid`). Для parser DB-advisory удобнее — lock автосвобождается при крахе процесса.
4. **Notify**: приоритет ждать TG-разрешение от Ильи или пока достаточно файлов + on-demand `status.sh`?

После ответа школы — имплементация (ориентировочно 4-6 часов: heartbeat.sh ~1ч, 3 worker-lupes ~2-3ч, status/notify/manifest ~1-2ч).

---

## Open questions для будущего L2 (Paperclip-tick, вне скоупа этого skill-а)

- Как worker принимает решения на основе контекста? (напр. «сегодня CF агрессивнее обычного → на 30% удлинить CF_COOLDOWN»).
- Нужен ли LightRAG-backed «memory» — worker читает прошлые логи и учится паттернам.
- Это — heartbeat-agent-tick v0.1, отдельный skill. Сейчас достаточно event-driven rules из Layer 2 выше.

---

## Референсы

- `/opt/tg-export/heartbeat.sh` — librarian Layer 1 реализация (cron */10). Почти готовый шаблон для parser.
- `/opt/tg-export/download.mjs` (строки 22-40 — константы, 156-218 — pacing цикл) — librarian Layer 2.
- `canon_training.yaml` принципы 3, 4, 5, 9.
- `inbox_from_parser.md` v1 — задача 1.3 (5 улучшений human-rhythm) + 1.2 (3 конкретных затыка v1).
- `outbox_to_parser.md` approvals block (школа 3 инсайта от librarian: expected-duration logging / manifest.finished / _status.json atomic).
