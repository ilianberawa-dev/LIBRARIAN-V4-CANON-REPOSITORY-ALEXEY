# FARSight Canggu Statistics — 2025 Snapshot

**Получено от Ильи:** 2026-04-21 (Telegram attachment).
**Провайдер:** FARSIGHT Villas & Hotels Management (farsight24.com, Bali PMC с 300+ villa в управлении).
**Файлы:**
- `statistics_of_canggu.pdf` — оригинальный 2-страничный dashboard
- `extracted_data.json` — структурированные таблицы (machine-readable)
- Данные в Supabase: `public.market_benchmarks` WHERE source='farsight_2025' (10 строк: 5 BR × 2 года)

---

## 🚨 CRITICAL SCOPE CAVEAT (Илья 2026-04-21)

> **«FARSight управляет виллами в сегменте выше среднего в short-term rentals. Эти данные НЕ ложатся на всю выборку, а только на узкий сегмент.»**

**Что значит**:
- ❌ **НЕ использовать** для расчёта yield на всей нашей базе 422 properties
- ❌ **НЕ применять** на long_term / mixed / budget-сегменты
- ❌ **НЕ экстраполировать** на non-PMC villa (owner-managed, budget STR)

**Что значит OK**:
- ✅ Использовать как **market trends** (YoY динамика по BR-категориям)
- ✅ Сравнить наши premium short-term records (rental_suitability='short_term' + price_idr в верхнем квартиле) — туда FARSight benchmark применим
- ✅ Показывать брокерам как reference "upper-mid STR segment performance"
- ✅ Мониторить Canggu market trend ("2BR RevPAR YoY -28%" — это сигнал oversupply + падение спроса)

---

## Ключевые инсайты (2025 vs 2024)

### 2BR сегмент — худшая динамика в Canggu
- **Revenue -24%**, **ADR -19%**, **Occupancy -9%**, **RevPAR -28%**
- При этом **listings +7%** — классический oversupply + падение спроса
- Для 2026 закладывать ещё -10-15% прогноз

### Занятости по BR-сегментам 2025
- 1BR: 65% occupancy, ADR $103 → RevPAR $67
- 2BR: 66% occupancy, ADR $135 → RevPAR $89 (worst YoY)
- 3BR: 65% occupancy, ADR $197 → RevPAR $128
- 4BR: 61% occupancy, ADR $306 → RevPAR $187
- 5BR: 55% occupancy, ADR $517 → RevPAR $284

### Размер рынка (FARSight-tracked)
- Всего 2,908 listings в Canggu STR upper-mid segment
- Самый большой сегмент — 3BR (963), потом 2BR (890)

---

## Структура dashboard (для reference при повторном чтении PDF)

**Страница 1**:
- Таблица 12-month averages (5 BR × 6 метрик)
- Bar chart: Revenue per month
- Pie chart: Shares by listing category
- Grid 5×3 time-series (BR × [revenue/ADR/occupancy]) с линиями 2023/2024/2025/2026

**Страница 2**:
- Сравнительная таблица 2024 vs 2025 с процентными изменениями (5 BR × 5 метрик × 2 года)

---

## Provenance chain (источник → нам)

```
Airbnb/Vrbo/Booking public data (или внутренний scrape FARSight)
        ↓
    FARSight internal analytics stack (вероятно Looker Studio)
        ↓
    Export PDF → Илья получил → переслал в Telegram
        ↓
    parser-rumah123-v2 extracted 2026-04-21
        ↓
    Supabase public.market_benchmarks (source='farsight_2025', narrow_premium_str caveat)
```

Downstream-источник FARSight **не указан** в документе. Предположения: (а) они используют AirDNA/AirROI, (б) собственный scrape Airbnb, (в) mix с их portfolio data. Это не проверяемо без запроса FARSight.

---

## Что НЕ нужно делать с этими данными

- Не покупать AirDNA subscription (~$5-15k/год) пока не зайдёт первый paying client — эти данные уже закрывают Canggu STR market reference.
- Не пересчитывать implied_yield на всю базу 422 — **вернётся гипер-оптимистичная оценка** для non-premium villa.
- Не использовать occupancy 66% (2BR aggregate) как base для budget villa — их реальная occupancy ниже 30-40%.

## Что СТОИТ сделать (по согласованию со школой)

- Отдельный yield-estimator **только для subset** `rental_suitability='short_term' AND price_idr > quartile_75(price_idr in same area)` — на этот subset FARSight benchmark применим. Разметить в БД как `premium_str_subset=true`.
- Квартальный refresh: попросить Илью повторно запросить FARSight dashboard для 2026 Q2/Q3 обновления этих строк.
- Попросить Илью пополнить PMC-collection: такие же quarterly PDF от OXO / Bukit Vista / Propertia (если он к ним имеет доступ).

---

## MUST READ on session start (для следующих ролей)

Этот README + `extracted_data.json` **обязательны к прочтению** для:
- `parser-rumah123-v<N≥3>` — при пересоздании сессии после handoff
- `school-v<N>` — при ревизии валидности наших STR-heuristic и yield-оценок
- `secretary-v<N>` — если он будет готовить документы для инвесторов с market trends

Путь в canon: `realty-portal/snapshots/market_data/farsight_canggu_2025/README.md`.
