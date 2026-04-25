---
name: search_properties
description: Поиск объектов в `properties` по фильтрам (район, тип, спальни, диапазон цены). Используется из Claude Code для ручных запросов; позже — для клиентского интерфейса Этапа 6.
---

# search_properties — PLACEHOLDER

**Статус:** заглушка. Реализация — в Этапе 5 канона.

Входы (все опциональные, AND-логика):
- `district` — `"Canggu"`, `"Seminyak"`, …
- `type` — `"villa" | "apartment" | "land" | "house"`
- `bedrooms_min`, `bedrooms_max` — integers
- `price_min`, `price_max` — USD/год
- `rental_period` — `"yearly" | "monthly" | "freehold" | "leasehold"`
- `is_active` — default `true`
- `limit` — default 50

Что должно делать (по архитектуре):
1. Построить WHERE clause из переданных фильтров.
2. `SELECT id, type, district, bedrooms, price_usd, source_url, last_seen_at FROM properties WHERE {filters} ORDER BY last_seen_at DESC LIMIT $limit`.
3. Вернуть JSON-array объектов.
4. Для запросов типа «медиана по Чангу» — использовать `market_snapshots` (последний snapshot), не считать каждый раз.
