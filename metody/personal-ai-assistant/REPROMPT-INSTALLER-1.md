# REPROMPT для Чата-Установщика #1 (Personal AI Assistant)

**Дата:** 2026-04-24
**Статус:** REPLACEMENT INSTRUCTIONS — отменяет всё что давалось ранее
**Назначение:** перепромптить установщика после canon double-check + Aeza outage

---

## 🛑 СТОП-ПОПРАВКА

**Архитектура изменилась после полного canon double-check.** Если ты уже начал собирать стек — **остановись, прочитай was/is матрицу ниже, и согласуй с архитектором (этим чатом) ДО любых дальнейших действий**.

---

## 📚 ОБЯЗАТЕЛЬНОЕ ЧТЕНИЕ (новый базис)

Перечитай в указанном порядке (всё на GitHub: `ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY`, ветка `claude/setup-library-access-FrRfh`):

1. `kanon/simplicity-first-principle.md` — Principle #0
2. `kanon/alexey-11-principles.md` — 12 принципов
3. `kanon/alexey-consultation-2026-04-24-agent-canon.md` — канон агентной системы
4. `kanon/alexey-realty-parser-canon-2026-04-24.md` — **НОВЫЙ** канон realty parser (важен раздел про VPS, sub-agents)
5. `metody/personal-ai-assistant/v1.1-mvp-simplified.md` — **АКТУАЛЬНЫЙ ТЗ** (заменяет всё прежнее)
6. `metody/personal-ai-assistant/AUDIT-2026-04-24.md` — обоснование упрощений

**Прежние инструкции архитектора, которые могли быть даны до этого reprompt — невалидны.**

---

## 🔄 WAS / IS МАТРИЦА (что изменилось)

### Архитектура

| Компонент | WAS (как было) | IS (как теперь) |
|-----------|----------------|----------------|
| **VPS** | Aeza (193.233.128.21) | Aeza если жив, ИЛИ новый VPS Asia (см. Задачу 2) |
| **LLM роутер** | LiteLLM proxy + Redis + Docker | НЕТ. Native Anthropic SDK прямо в коде |
| **Модели** | Cascade Qwen + Sonnet (2 провайдера) | ТОЛЬКО Sonnet 4.6 + prompt caching |
| **API ключи** | Anthropic + OpenRouter | ТОЛЬКО Anthropic |
| **Storage** | Supabase ИЛИ vector DB | SQLite + FTS5 (всё-в-одном файле) |
| **RAG** | LightRAG / sqlite-vss / Chroma | НЕТ в MVP. FTS5 заменяет полностью |
| **Embedding model** | nomic-embed / BGE | НЕТ |
| **History ingest** | 3-year full backfill | Только NEW messages с момента старта |
| **Learning loop** | Cron weekly auto | НЕТ автомата. Manual logging первые 2 недели |
| **TTS** | Silero модель скачать (200MB) | НЕТ в MVP. Заглушка кнопки 🎙 |
| **PWA** | Фаза 2B (планшет UI) | НЕТ в MVP. Только TG |
| **Voice intents** | 15 типов | 3 типа (Ответь / Правило / Поиск) |
| **Парсер групп** | Phase 2 архитектурно | Phase 3 после стабилизации MVP |
| **Этапы MVP** | 15 этапов | **Этап 0 + 6 этапов = 7 шагов**, 11-13 дней |
| **Бюджет** | $15-25/мес cascade | $20-22/мес Sonnet-only с caching |
| **SQLite backup** | НЕ упоминалось | **Daily cron backup** (новое требование) |
| **Sub-agents** | НЕ требовалось | **Этап 0: scout-haiku/worker-sonnet/strategist-opus** обязательно |
| **Claude Code Max** | НЕ обозначено | **Явное требование $100/мес** ($20 Pro не хватит) |

### Канонические запреты (новые / усилены)

| Запрет | Почему |
|--------|--------|
| ❌ Docker для основного процесса | systemd service напрямую (один сервис, не нужен оверхэд) |
| ❌ LiteLLM в любой форме | избыточно для одного провайдера |
| ❌ LightRAG / Chroma / vector store | избыточно для personal scope, FTS5 хватает |
| ❌ Не лезть в `/opt/tg-export/` | парсер канала Алексея, не ломать |
| ❌ Не лезть в `realty_lightrag` / `realty_ollama` / `supabase-*` | другой проект, изоляция данных (#11) |
| ❌ НЕ копировать архитектуру `kanon/alexey-realty-parser-canon-2026-04-24.md` 1-в-1 | тот канон для realty parser, не для Personal Assistant. Skills/sub-agents переиспользуй, runtime/storage другой |
| ❌ Auto-reply без human review | принципиально, никогда |

---

## 🆘 КРИТИЧНОЕ: Aeza упал на несколько дней

### Задача 2 (выполнить ПЕРВЫМ): Анализ азиатских VPS по канону

Канон Алексея (`kanon/alexey-realty-parser-canon-2026-04-24.md`) рекомендует азиатскую локацию VPS. У нас два кандидата:

**Кандидат A: Linode Jakarta**
- Оператор: Akamai
- Локация: Джакарта, Индонезия
- Прямо в стране Бали (где живёт владелец) — минимальная latency

**Кандидат B: Vultr Singapore**
- Оператор: Vultr
- Локация: Сингапур
- Почасовая оплата, простой UI

### Что ты должен сделать

Провести **сравнительный анализ** по 8 критериям и дать рекомендацию архитектору:

1. **Базовая цена** ($/мес) для tier с минимум 2 GB RAM, 1 vCPU, 40 GB SSD
2. **Часы работы поддержки** в часовом поясе Бали (WITA, UTC+8)
3. **Uptime SLA** официальный
4. **Bandwidth/трафик** включённый в тариф
5. **IPv4 / IPv6** доступность
6. **Backups встроенные** (есть/платно/нет)
7. **Latency** до Telegram serverов (DC4/DC5 в Амстердаме/Нью-Йорке) — критично для MTProto
8. **Latency** до Anthropic API (us-east) — критично для draft generation

### Формат отчёта (mapping report — см. секцию ниже)

Сравнительная таблица + рекомендация одного варианта + обоснование.

---

## 🎯 ПЛАН РАБОТЫ (новый, после reprompt)

Выполнять строго по порядку:

### Задача 1: Прочитать новый ТЗ и канон
- 6 файлов (см. "Обязательное чтение" выше)
- Понять стек, изоляцию, 6 этапов MVP

### Задача 2: VPS analysis (Linode Jakarta vs Vultr Singapore)
- См. критерии выше
- Mapping report → архитектор

### Задача 3: ROLLBACK что уже сделано на Aeza
- Если ты уже что-то поставил/сконфигурировал на Aeza до её падения — **отчитайся что именно**
- Архитектор решит: чистить или переносить

### Задача 4: Stop & Wait
- Пока архитектор не утвердит mapping report, новых действий не предпринимать
- Ничего не ставь на новый VPS до approval

---

## 📋 ФОРМАТ MAPPING REPORT (обязательный)

Отчитайся архитектору одним сообщением со следующими секциями:

```
## 1. UNDERSTOOD (что я понял из новой базы)

- ТЗ: [одна фраза summary]
- Архитектура: [ключевые компоненты]
- Что в MVP: [список из 7 этапов 0-6]
- Что отложено: [bullet list]
- Изоляция от чего: [явные запреты]
- Бюджет: [финальная цифра]
- 12 принципов: подтверждаю компетентность по каждому ✅/⚠️

## 2. WAS → IS DIFF (что я делал по старым инструкциям)

- На Aeza до падения было сделано: [список или "ничего"]
- Какие компоненты уже стояли: [Docker / LiteLLM / итд или "никаких"]
- Что нужно отменить: [список или "нечего"]

## 3. VPS ANALYSIS (Linode Jakarta vs Vultr Singapore)

| Критерий | Linode Jakarta | Vultr Singapore |
|----------|----------------|-----------------|
| Цена /мес | ... | ... |
| Поддержка | ... | ... |
| Uptime SLA | ... | ... |
| Bandwidth | ... | ... |
| IPv4/IPv6 | ... | ... |
| Backups | ... | ... |
| Latency to TG | ... | ... |
| Latency to Anthropic | ... | ... |

**Моя рекомендация:** [Linode Jakarta | Vultr Singapore]
**Обоснование:** [3-5 строк]

## 4. CLARIFY QUESTIONS (если есть)

[Список вопросов которые нужно решить перед началом Этапа 1]

## 5. NEXT ACTION REQUEST

Готов начать Этап 1 (Listener live) после твоего approval, при условии:
- VPS выбран и куплен владельцем
- Получены credentials [список]
```

---

## 🚦 РЕЖИМ РАБОТЫ — orchestration

- Ты — **исполнитель** одного этапа
- Я (архитектор) — даю ТЗ, ревьюю результат, даю следующее
- Один Claude Code чат = один этап (потом новый чат)
- Если упёрся в неясность — **СТОП**, спроси архитектора, не импровизируй
- Если хочешь добавить компонент — **СТОП**, согласуй (Phase 2 фичи могут добавляться только по trigger conditions)

---

## ⚠️ ПОСЛЕДНЕЕ ВАЖНОЕ

1. **Принцип #0 Simplicity First** перед каждым решением
2. **Не путай два проекта Ильи:**
   - Realty Parser (по `kanon/alexey-realty-parser-canon-2026-04-24.md`) — другой проект
   - Personal AI Assistant (по `metody/personal-ai-assistant/v1.1-mvp-simplified.md`) — НАШ
3. Канон realty parser **только для reference паттернов** (sub-agents, skills>agents) — runtime/storage у нас ДРУГИЕ
4. Все 11 принципов Алексея + Simplicity First применяются к ОБОИМ проектам

---

**Подтверди понимание этого reprompt mapping-отчётом. После одобрения архитектора — переходим к Задаче 1.**

---

**Создано:** 2026-04-24
**Статус:** ACTIVE — отменяет все прежние инструкции этому установщику
