# Консультация Алексея — Канон Realty Parser для Ильи

**Дата:** 2026-04-24
**Тип:** Авторитетный канон автора метода (вторая консультация)
**Применение:** Realty аналитический портал (Бали/Дубай/Сочи)
**Контекст:** Прямая консультация Алексея с Ильёй, после неудач с Paperclip и OpenClaw на локалке
**Статус:** CANONICAL

---

## Краткое резюме

**Целевой проект:** аналитика недвижимости с парсингом площадок Бали, накоплением данных, AI-обработкой.

**Стек (стандартный, проверенный):**
- Claude Code (Max $100/мес) — разработка скиллов
- OpenClaw (на VPS) — production runner
- Supabase (self-hosted) — структурированные данные
- LightRAG (self-hosted) — knowledge база (районы, типы, специфика)

**Главный принцип:** Один агент + набор скиллов + крон. Никаких пирамид агентов.

---

## Ключевые тезисы для применения

### 1. Главный flow

```
Claude Code (dev на ноуте) → пишешь и тестишь СКИЛЛЫ →
закидываешь их в OpenClaw → OpenClaw запускает их автономно по крону.
```

### 2. Локация владельца и legal

- Илья на Бали → 152-ФЗ НЕ применяется
- Данные не российские
- VPS лучше брать в Азии (Linode Jakarta / Vultr Singapore)

### 3. Стоимость стека

| Компонент | Стоимость |
|-----------|-----------|
| Claude Code Max | $100/мес (Pro $20 не хватит) |
| VPS Asia (Linode Jakarta / Vultr SG) | $5-13/мес |
| OpenClaw self-hosted | Бесплатно |
| Supabase self-hosted | Бесплатно |
| LightRAG self-hosted | Бесплатно |
| Модель для OpenClaw | $10-30/мес |
| **ИТОГО** | **~$50-70/мес** |

### 4. VPS — рекомендации

| Провайдер | Локация Asia | Цена | Комментарий |
|-----------|-------------|------|-------------|
| **Linode (Akamai)** | **Jakarta**, Singapore, Tokyo | $5+/мес | Jakarta идеально для Бали |
| Vultr | Singapore, Tokyo | $6+/мес | простой UI, почасовая оплата |
| DigitalOcean | Singapore, Bangalore | $6+/мес | отличная документация |
| OVH | Singapore | €4+/мес | дешевле, чуть менее удобно |
| AWS Lightsail | Singapore, Tokyo, Jakarta, Mumbai | $5+/мес | если уже в AWS экосистеме |

**НЕ Hetzner** — только EU/US локации.

**AdminVPS** (промокод `AK-PRIVATE60` 60% скидка первого месяца) — запасной вариант, только европейские локации.

### 5. Модель для OpenClaw в проде

| Модель | Применение |
|--------|-----------|
| **Qwen 3.5 (самая маленькая)** | детерминированные скиллы, дешёвый старт |
| **MiniMax M2.7** | дефолт Алексея, ~в 15× дешевле Opus |
| **OpenAI gpt-5.1-mini** | альтернатива |
| **Claude Sonnet 4.6** | если скиллы сложные с большой вариативностью |

**Принцип:** для разработки (Claude Code) — Opus/Sonnet. Для прода (OpenClaw) — дешёвые. Чем жёстче скилл → тем дешевле модель.

---

## Три слоя архитектуры

```
АГЕНТ   = модель + системный промпт + тулы
          Claude Code знает "как работать в роли"
           ↓ использует ↓
СКИЛЛ   = markdown-инструкция под конкретную задачу
          "как сделать вот эту штуку"
           ↓ использует ↓
ИНСТРУМЕНТ = MCP / bash / HTTP API
             физическое действие
```

### Глобальные субагенты (~/.claude/agents/)

| Агент | Модель | Зачем |
|-------|--------|-------|
| **scout-haiku** | Haiku | Быстрый поиск: файлы, LightRAG, справки. Дёшево |
| **worker-sonnet** | Sonnet | Основной исполнитель: пишет скиллы, парсеры. Дефолт |
| **strategist-opus** | Opus | Глубокое мышление: архитектура, планы. Редко |

CLAUDE.md роутит задачу нужному субагенту. **80% простых задач уходят на Haiku** (в 15× дешевле Opus).

---

## 5 скиллов для парсера realty (приоритеты)

| Скилл | Приоритет | Что делает |
|-------|-----------|-----------|
| **parse_listings_web** | P1 | Парсит площадки (Rumah123, OLX, Balirealty). Playwright/httpx. → `raw_listings` |
| **normalize_listing** | P1 | Claude нормализует кривые поля по JSON-схеме → `properties` |
| **store_to_supabase** | P1 | Дедуп по url+address+price. INSERT/UPDATE |
| **market_snapshot** | P2 | Раз в неделю: медианы по районам, тренды → `market_snapshots` + LightRAG |
| **search_properties** | P2 | SELECT по фильтрам. Используется из Claude Code |

**НЕ делаем в начале:** Telegram парсинг, Telegram бот, Facebook Marketplace, любые интерфейсы.

---

## Supabase schema

```sql
CREATE TABLE raw_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL,
  source_url TEXT,
  raw_text TEXT NOT NULL,
  raw_html TEXT,
  status TEXT DEFAULT 'pending',
  property_id UUID,
  error_message TEXT,
  parsed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  district TEXT,
  address TEXT,
  bedrooms INTEGER,
  bathrooms INTEGER,
  area_m2 NUMERIC,
  land_area_m2 NUMERIC,
  price_usd NUMERIC,
  price_original TEXT,
  rental_period TEXT,
  lease_years INTEGER,
  contact_name TEXT,
  contact_phone TEXT,
  contact_whatsapp TEXT,
  source_url TEXT,
  source_name TEXT,
  image_urls TEXT[],
  raw_text TEXT,
  is_active BOOLEAN DEFAULT true,
  first_seen_at TIMESTAMPTZ DEFAULT now(),
  last_seen_at TIMESTAMPTZ DEFAULT now(),
  price_changed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE market_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
  district TEXT,
  total_listings INTEGER,
  median_price_usd NUMERIC,
  price_trend TEXT,
  price_change_pct NUMERIC,
  breakdown JSONB,
  summary_text TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  url TEXT,
  config JSONB DEFAULT '{}',
  parse_interval_minutes INTEGER DEFAULT 180,
  is_active BOOLEAN DEFAULT true,
  last_parsed_at TIMESTAMPTZ,
  total_parsed INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## Дорожная карта realty parser

### Этап 1 — Фундамент (1-2 дня)
- VPS Asia (Linode Jakarta / Vultr SG)
- Docker + Compose
- Compose: Supabase + LightRAG + OpenClaw
- Подключить Supabase MCP + LightRAG MCP к Claude Code
- Проверка: Claude Code ходит в обе

### Этап 2 — Первые скиллы (неделя 1)
- Выбрать 2-3 веб-площадки Бали
- `parse_listings_web` для одного источника
- `normalize_listing` с JSON-схемой
- `store_to_supabase` с дедупом
- Тест на 50-100 объявлениях

### Этап 3 — LightRAG (неделя 1-2)
- Загрузить knowledge: районы Бали, типы, freehold/leasehold, сезонность
- markdown → `insert_text`

### Этап 4 — Деплой OpenClaw (неделя 2)
- Перенос отлаженных скиллов в OpenClaw
- Крон: парсинг каждые 3 часа, snapshot по воскресеньям
- Health-check скилл

### Этап 5 — Поиск через Claude Code (неделя 3)
- `search_properties`
- Запросы: "медиана по Чангу", "свежие объявления по критериям"

### Этап 6 — Расширение (месяц 2+)
- 2-3 новых источника
- Аномалии (скачки цен)
- Сравнение vs рынок
- Клиентский интерфейс — В ПОСЛЕДНЮЮ ОЧЕРЕДЬ когда данные накопились

---

## Что НЕ делать (явные запреты Алексея)

❌ **Paperclip** и AI-компании — застрянешь в setup
❌ **Мульти-агентные системы** (orchestrator+analyst+strategist+critic) — жрут токены, ломаются
❌ **OpenClaw на локалке через openclaw.gdn** — нестабильно, переезд на VPS обязателен
❌ **Facebook Marketplace** — банит, меняет структуру
❌ **Telegram (парсинг каналов или бот)** на этом этапе — фокус на веб-источники
❌ **Писать скилл сразу в OpenClaw** — сначала Claude Code → тест → потом OpenClaw
❌ **«Саморазвивающаяся система»** — маркетинг. Реальность: ты пишешь скиллы, система накапливает данные

---

## SaaS-потенциал

Supabase — правильный выбор для будущего SaaS:
- Авторизация встроена
- Платёжка прикручивается
- Дашборд цепляется как обвязка

**Принцип:** интерфейс делается В ПОСЛЕДНЮЮ ОЧЕРЕДЬ — когда данные накоплены и понятно ЧТО показывать.

Архитектура на Supabase позволяет добавить новые рынки (Дубай, Сочи) без переработки — просто новые `sources` и `district`.

---

## Применение к Personal AI Assistant

**ВАЖНО:** Этот канон написан для **realty parser проекта**, не для Personal AI Assistant. Они разные:

| Аспект | Realty Parser | Personal AI Assistant |
|--------|--------------|----------------------|
| Триггер | Cron каждые 3 часа | Live event (NewMessage) |
| Данные | Структурированные realty | Личная переписка |
| Storage | Supabase (для SaaS) | SQLite (изоляция, MVP) |
| Knowledge base | LightRAG (районы, типы) | FTS5 (поиск истории) |
| Runtime | OpenClaw + cron | systemd live listener |
| Модель | MiniMax/Qwen для прода | Sonnet 4.6 для MVP |
| Локация VPS | Asia (для Бали парсинга) | Aeza (где есть) |

**Что переиспользуется (одинаково оба проекта):**
- Claude Code Max для разработки
- ~/.claude/agents/ (scout/worker/strategist sub-agents)
- Skills > Agents принцип
- "Сначала данные, потом интерфейс"
- Канон 12 принципов

**Что разное:**
- Стек прода (OpenClaw для realty / systemd для personal)
- Storage (Supabase vs SQLite)
- Knowledge (LightRAG vs FTS5)
- Тип runtime (cron vs event-driven)

---

## Связь с другими канон-документами

- `kanon/alexey-11-principles.md` — 12 принципов (применяются к ОБОИМ проектам)
- `kanon/simplicity-first-principle.md` — Principle #0 (применяется к ОБОИМ)
- `kanon/alexey-consultation-2026-04-24-agent-canon.md` — первая консультация (skills>agents)
- `metody/personal-ai-assistant/v1.1-mvp-simplified.md` — Personal AI Assistant (наш текущий проект)
- `troubleshoot/telegram-parser-recreation.md` — пример parser скилла

---

**Создано:** 2026-04-24
**Авторитет:** Алексей Колесов (автор канона)
**Назначение:** Realty parser архитектура для Ильи (Бали)
**Статус:** CANONICAL для realty проекта
