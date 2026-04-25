---
name: parse_listings_web
description: Парсит веб-площадки Бали и пишет сырые карточки объявлений в public.raw_listings (status='pending'); обновляет public.sources (last_parsed_at, total_parsed, error_count, last_error). MVP-источник rumah123_bali (/jual/bali/rumah/, страницы 1-2, ~40 карточек/цикл) через curl_cffi impersonate=chrome120 с warm-up-сессией. Вызывается как CLI ./scrapers/rumah123/run.py из /opt/realty-portal/.
---

# parse_listings_web

## Цель
Взять `source_name` → запустить соответствующий скрейпер → записать карточки в `public.raw_listings` со `status='pending'` → обновить `public.sources`. Нормализация и вывод в `public.properties` — задача отдельного скилла `normalize_listing`.

## Поддерживаемые источники (канон MVP)

| source_name    | status   | путь скрейпера                         | файл    |
|----------------|----------|----------------------------------------|---------|
| rumah123_bali  | active   | /opt/realty-portal/scrapers/rumah123/  | run.py  |
| olx_bali       | pending  | /opt/realty-portal/scrapers/olx_bali/  | TODO    |
| balirealty     | pending  | /opt/realty-portal/scrapers/balirealty/| TODO    |

## Вызов для rumah123_bali

Запуск из `/opt/realty-portal/`:

```bash
set -a; . ./.env; set +a
export DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@127.0.0.1:5432/postgres"
./scrapers/.venv/bin/python3 ./scrapers/rumah123/run.py \
  --source-name rumah123_bali \
  --max-pages 2 \
  --rate-limit 6
```

Dry-run (без записи в БД, JSON-превью первых 3 карточек):

```bash
./scrapers/.venv/bin/python3 ./scrapers/rumah123/run.py \
  --source-name rumah123_bali --max-pages 1 --dry-run
```

## Детерминированная логика парсинга (Rumah123)

1. **Warm-up:** GET `https://www.rumah123.com/` (без Referer). Если `status != 200` или body содержит `"Just a moment"` → пометить `sources.last_error`, exit 2.
2. **List pages:** для `page in 1..max_pages`:
   - URL: `https://www.rumah123.com/jual/bali/rumah/` для `page=1`, `.../jual/bali/rumah/?page=N` для `page>1`.
   - Referer: предыдущая URL (home для page=1).
   - `sleep(rate_limit)` между запросами.
   - При 403/CF → stop loop, записать `sources.last_error='CF challenge at page N'`, продолжить flush.
3. **Селектор карточки:** `a[href*="/properti/"][href*="priceCurrency=IDR"]`.
4. **Поля карточки:**
   - `source_url` = `https://www.rumah123.com` + `a[href]`.
   - `title` = `a[title]` (атрибут).
   - `price_text` = `a [data-testid="ldp-text-price"]` → text.
   - `location` = `a p.text-greyText.truncate.px-4` → text.
   - `bedrooms` = regex `(\d+)\s*Kamar Tidur` на полном тексте карточки; fallback `(\d+)\s*KT`.
   - `bathrooms` = regex `(\d+)\s*Kamar Mandi`; fallback `(\d+)\s*KM`.
   - `land_area_m2` = regex `LT[:\s]*(\d+)\s*m`.
   - `building_area_m2` = regex `LB[:\s]*(\d+)\s*m`.
   - `raw_text` = `a.get_text(" ", strip=True)`.
   - `raw_html` = `str(a)` (outerHTML карточки).
5. **INSERT:**
   ```sql
   INSERT INTO public.raw_listings (source_name, source_url, raw_text, raw_html, status)
   VALUES ($1, $2, $3, $4, 'pending')
   ON CONFLICT (source_url) DO NOTHING;
   ```
   (требуется миграция `0002_raw_listings_unique.sql`)
6. **UPDATE sources** всегда в конце:
   ```sql
   UPDATE public.sources
   SET last_parsed_at = now(),
       total_parsed   = COALESCE(total_parsed,0) + $inserted,
       error_count    = COALESCE(error_count,0) + $err_increment,
       last_error     = $last_error_text
   WHERE name = $source_name;
   ```

## Exit codes

| code | смысл                                                                 |
|------|-----------------------------------------------------------------------|
| 0    | успех: ≥1 карточка распаршена (INSERT'ы могут вернуть 0 из-за дедупа) |
| 2    | warm-up не прошёл (home → 403 / CF); `sources.last_error` обновлён    |
| 1    | internal error (DB down, неожиданный exception)                       |

## Политика anti-bot

- `curl_cffi` с `impersonate="chrome120"` (TLS/JA3 fingerprint реального Chrome).
- Один `Session()` на весь run → единый cookie-jar.
- Референтная цепочка (Referer всегда = предыдущая URL).
- Rate-limit 6 сек (конфигурируется `--rate-limit`).
- При первом 403 / "Just a moment" — graceful stop, не retry внутри одного run (следующий cron — новая сессия = новый JA3).

## Текущие ограничения MVP

- Только `/jual/bali/rumah/` страницы 1-2 → ~40 уникальных карточек за цикл.
- Типы `villa`, `tanah`, `ruko`, `sewa/*` + фильтр `?search=<district>` → 403 даже с warm-up. Добавятся в Этапе 6 (через Playwright или proxy).
- District не извлекается здесь — делается `normalize_listing` из `source_url` (`/properti/<kabupaten>-<kecamatan>/...`) и `location` текста.
- Детальные страницы объявлений НЕ качаются (экономия запросов). `raw_html` содержит только outerHTML карточки со списка.
