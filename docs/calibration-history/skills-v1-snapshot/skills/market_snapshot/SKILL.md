---
name: market_snapshot
description: Раз в неделю (воскр 20:00 UTC) считает по районам медиану/мин/макс/тренд, пишет в `market_snapshots`. Текстовое summary кладёт в LightRAG через insert_text.
---

# market_snapshot — PLACEHOLDER

**Статус:** заглушка. Реализация — в Этапе 4 канона (после cron).

Входы: нет (cron-trigger раз в неделю).

Что должно делать (по архитектуре):
1. По каждому `district` из `properties WHERE is_active = true`:
   - медиана, средняя, мин, макс `price_usd`
   - `total_listings = count(*)`, `new_listings_week = count(*) WHERE first_seen_at >= now() - 7 days`
   - тренд vs прошлый snapshot той же district (`up | down | flat`, `price_change_pct`)
2. `INSERT INTO market_snapshots (snapshot_date, district, ...)`.
3. Сгенерировать текстовое `summary_text`:
   ```
   Неделя {date}: {district} — {total} активных, медиана {median} USD/год, тренд {up|down|flat} {pct}%.
   ```
4. В LightRAG: `insert_text(summary_text)` — накопление истории рынка.
