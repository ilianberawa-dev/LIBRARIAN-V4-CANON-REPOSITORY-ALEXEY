---
name: normalize_listing
description: Берёт raw_listings.id в статусе `pending`, через Claude извлекает структурированные поля по JSON-схеме канона, пишет в `properties`. При ошибке — статус `failed` + error_message.
---

# normalize_listing — PLACEHOLDER

**Статус:** заглушка. Реализация — в Этапе 2 канона.

Входы:
- `raw_listing_id` — UUID из `public.raw_listings` со статусом `pending`

Что должно делать (по архитектуре):
1. `SELECT raw_text FROM raw_listings WHERE id = $1 AND status = 'pending'`.
2. Через Claude (structured output) извлечь JSON строго по схеме канона:
   ```json
   {
     "type": "villa | apartment | land | house",
     "district": "Canggu | Seminyak | Ubud | Kuta | Sanur | Uluwatu | Jimbaran | ...",
     "bedrooms": 3, "bathrooms": 2, "area_m2": 120,
     "price_usd_yearly": 15000,
     "rental_period": "yearly | monthly | freehold | leasehold",
     "lease_years": 25,
     "contact": {"name": "...", "phone": "...", "whatsapp": "..."}
   }
   ```
3. Успех → `store_to_supabase` (следующий скилл).
4. Ошибка → `UPDATE raw_listings SET status='failed', error_message=$err`.

JSON-схема жёсткая — модель возвращает только строгий формат, никакой свободной прозы.
