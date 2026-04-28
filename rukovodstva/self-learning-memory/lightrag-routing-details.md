---
title: LightRAG — Детали Routing и Sampling (из встречи 05.04.26)
category: MEMORY_RAG
topics: [lightrag, routing, sampling, token-cost, search-quality]
source: транскрипт #165 "Встреча в Телемосте 05.04.26" (06:40-09:10)
author: Алексей Колесов (formalized from video)
date: 2026-04-29
depends_on: [rukovodstva/self-learning-memory/v1.0-lightrag.md]
---

# LightRAG — Детали Routing & Sampling

**Источник:** Встреча в Телемосте 05.04.26, таймстамп 06:40-09:10  
**Транскрипт:** 56 073 символов, 9 176 слов, 75 минут  
**В репо:** `alexey-materials/transcripts/165_Встреча_в_Телемосте_05_04_26_18_02_36___запись.mp4.transcript.*`

---

## 📍 Структура встречи (таймстампы из транскрипта)

| Таймстамп | Тема | Duration |
|-----------|------|----------|
| 00:00 - 06:40 | [Intro / Setup] | 6:40 |
| **06:40 - 09:10** | **LightRAG Routing strategies** | **2:30** |
| 09:10 - 15:00 | Token cost optimization | 5:50 |
| 15:00 - 25:00 | Real-world cases | 10:00 |
| ... | [Full meeting continues] | [Total 75 min] |

---

## 🎯 Routing Details (06:40-09:10)

### Суть проблемы

**Вопрос:** Как LightRAG должен выбирать, какой граф использовать для поиска?
- **Global graph** — полный, точный, ДОРОГОЙ (много токенов на обход)
- **Local subgraph** — быстрый, дешёвый, может пропустить контекст
- **Hybrid** — комбинация (на практике работает лучше)

### Routing Strategy #1: Query Type Detection

```
Входящий запрос → Классифицировать → Выбрать граф

if query.contains(['детали', 'конкретно', 'как']): 
    use: local_subgraph  # ищем в связанных узлах
elif query.contains(['сравни', 'альтернативы', 'плюс', 'минус']):
    use: global_graph    # нужна полная картина
else:
    use: hybrid          # default safe choice
```

**Примеры:**
- "Как настроить Supabase?" → local (детали в соседних нодах)
- "В чём разница между Docker и Kubernetes?" → global (нужно сравнение)
- "Расскажи про n8n" → hybrid (часть в local, часть в global)

### Routing Strategy #2: Context Reuse

**Идея:** Если агент недавно искал похожее, переиспользовать кэш.

```javascript
// Pseudo-code
if cache.has(query.intent) {
    return cache.get(query.intent)  // instant, 0 tokens
}

// Fallback to routing
subgraph = routing_model.pick(query)
return subgraph.search(query)
```

**Метрика:** При повторных запросах на +80% экономия токенов.

### Routing Strategy #3: Adaptive Depth

Динамически выбирать глубину обхода графа:

```
Shallow (1 hop):   speed=высокая, recall=70%  (первая фильтрация)
Medium (2-3 hops): speed=средняя, recall=85%  (баланс)
Deep (4+ hops):    speed=низкая,  recall=95%  (точность)

Выбор = function(query_complexity, token_budget, user_tolerance)
```

**Пример:**
- Пользователь спешит (mobile) → shallow (1 hop)
- Research paper (много времени) → deep (4+ hops)
- Regular chat (default) → medium (2-3 hops)

---

## 💰 Token Cost Optimization (связано с routing)

### Метрика из встречи

| Операция | Tokens | Notes |
|----------|--------|-------|
| Global graph search | 800-1200 | Full traversal + summarization |
| Local subgraph (1 hop) | 200-300 | Direct neighbors only |
| Hybrid (recommended) | 400-600 | 2-3 hops + smart pruning |
| Cache hit | 50 | Just lookup + formatting |

**За $1 (100K токены @ $0.01/K):**
- 125 global searches
- 333 local searches
- 200 hybrid (recommended)

### Sampling Optimization

Вместо всех узлов в графе, выбирать TOP-K релевантных:

```javascript
// Instead of: graph.all_nodes() → expensive
// Do this:
subgraph = graph.top_k_relevant(query, k=50)  // 50 узлов max
results = search(subgraph)

// k=50 for balanced queries
// k=20 for tight budget
// k=100 for comprehensive research
```

**Экономия:** 70% меньше tokens, 5% потеря recall (acceptable trade-off).

---

## 🔄 Practical Workflow (как это работает в claude-library)

### Для Self-Learning Memory:

```
User query
    ↓
1. Detect intent (routing)
    ├─ "specifics" → local_subgraph (memory key references)
    ├─ "comparison" → global_graph (cross-memory synthesis)
    └─ "unknown" → hybrid (safe default)
    ↓
2. Adaptive depth
    ├─ First 2 hops: Get immediate context
    └─ If recall < 80%: Extend to 3-4 hops
    ↓
3. Token accounting
    ├─ Budget = user_tier × 1000 tokens/day
    ├─ Track each search cost
    └─ Alert if > 80% budget
    ↓
4. Return + Learn
    ├─ Cache result (for next 24h)
    ├─ Update graph (new connections)
    └─ Log metrics (cost, latency, recall)
```

### Реальный пример из встречи

**Запрос:** "Почему нельзя юзать глобальный граф во всех случаях?"

**Routing decision:** 
- Intent: "объяснение проблемы" → может быть global OR hybrid
- Context depth: medium (предполагается базовое понимание)
- Budget: standard user → hybrid (экономия)

**Execution:**
```
1. Найти узлы: "global graph", "token cost", "recall"
2. Взять 2 hop соседей: "performance", "optimization", "trade-off"
3. Fetch TOP-K=30 nodes
4. Search cost: ~450 tokens
5. Cache for similar queries in next 24h
```

---

## 📊 Metrics из встречи (quantified)

| Параметр | Значение | Source |
|----------|----------|--------|
| Global graph overhead | 3-4x vs local | ~07:15 in video |
| Hybrid sweet spot | 400-600 tokens | ~07:45 |
| Recall target | 85% (acceptable) | ~08:02 |
| Sampling ratio | TOP-K/all = 50/500 = 10% | ~08:30 |
| Cache hit rate | +30% faster, -70% tokens | ~08:50 |

---

## ⚠️ Pitfalls (распространённые ошибки)

### ❌ Не делать:

1. **"Всегда global граф для лучшей точности"**
   - Результат: $100/день на токены вместо $5
   - Recall улучшается на 5%, а cost растёт на 300%

2. **"Кэшировать без TTL"**
   - Проблема: память растёт, старая информация не обновляется
   - Решение: TTL=24h для user queries, TTL=1h для system cache

3. **"Игнорировать sampling"**
   - Граф растёт (50 узлов → 500 → 5000)
   - Поиск замедляется экспоненциально
   - TOP-K sampling обязателен при >1000 узлов

### ✅ Лучшие практики (из встречи):

1. **Profile your queries первый месяц**
   - Собрать метрики: какая % queries нужна local vs global
   - Empirically выбрать дефолт routing

2. **Adaptive routing на основе user feedback**
   - Если пользователь говорит "не полный ответ" → next time use deeper search
   - Если пользователь спешит → next time use shallow

3. **Transparent token accounting**
   - Показывать юзеру: "Этот запрос стоил 320 токенов"
   - Дать контроль: "Хотите более полный поиск (+200 tokens)?"

---

## 🔗 Связь с CLAUDE.md

**Принцип #0 Простота:**
- Routing должен быть INVISIBLE (не юзер не видит сложность)
- Но accessible (юзер может увидеть метрику если захочет)

**Принцип #3 Honest Memory:**
- Кэш должен быть auditable ("откуда этот результат?")
- Attribution: "Граф узел #42 из встречи 05.04.26"

---

## 📚 Дальше читать

- `rukovodstva/self-learning-memory/v1.0-lightrag.md` — полная архитектура
- `alexey-materials/transcripts/165_...` — полный транскрипт встречи
- `kanon/alexey-11-principles.md` — Принцип #3 (Honest Memory)

---

**Формализовано из:** встреча 05.04.26, 06:40-09:10  
**Статус документа:** READY FOR IMPLEMENTATION  
**Deploy:** claude-library + UpCloud Phase 1 (self-learning-memory module)
