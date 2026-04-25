---
name: store_to_supabase
description: Принимает нормализованный объект, дедупит по `source_url + district + price_usd`, INSERT или UPDATE в `properties`. Отмечает `price_changed_at` при изменении цены.
---

# store_to_supabase — PLACEHOLDER

**Статус:** заглушка. Реализация — в Этапе 2 канона.

Входы:
- нормализованный JSON-объект (см. `normalize_listing`)

Что должно делать (по архитектуре):
1. Dedup key: `(source_url, district, price_usd)`.
2. `SELECT id, price_usd FROM properties WHERE source_url = $1 AND district = $2`.
3. Если нет:
   - `INSERT INTO properties (...)` с полями из JSON + `first_seen_at = now()`, `last_seen_at = now()`, `is_active = true`.
   - Выставить флаг «новый объект» для будущих алертов.
4. Если есть:
   - `UPDATE ... SET last_seen_at = now()`.
   - Если `price_usd` изменилось — `price_changed_at = now()`, `price_original = старое_значение`.
5. После записи — `UPDATE raw_listings SET status='processed', property_id=$1, parsed_at=now() WHERE id=$raw_id`.
