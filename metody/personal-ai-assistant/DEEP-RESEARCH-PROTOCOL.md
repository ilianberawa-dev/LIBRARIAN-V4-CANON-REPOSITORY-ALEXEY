# Deep Research Protocol — Канон #0 Simplicity First в действии

**Назначение:** перед принятием архитектурного решения о новой интеграции/инструменте/сервисе — провести систематический ресёрч "что реально делают люди", а не довериться первому правдоподобному варианту из training data модели.

**Зачем:** training data устаревает (cutoff Jan 2026). Реальные практики 2025-2026 живут в Reddit-тредах, GitHub issues, YouTube комментариях, indie-hacker блогах. Документация даёт "правильный" путь, который часто не самый простой.

---

## Принцип

> "Проще и дешевле почти всегда есть решение — даже если на сегодня его нет в твоей базе"
> — Алексей, 2026-04-26

Архитектор обязан **сомневаться** в собственном первом ответе и проверять его через grassroots-поиск. Если первый ответ требует "месяцы документов + $150 + риск отказа" — это сигнал, что есть короткий путь, которого ты не видишь.

---

## Векторы поиска (используй параллельно через `Agent` tool)

### Вектор 1 — Официальный layer
Documentation, спецификации, vendor docs. Даёт корректность но не простоту.
Search patterns:
- `"<topic>" official documentation 2025`
- `"<topic>" SDK <language> latest version`

### Вектор 2 — Reddit / форумы
Реальные жалобы и success stories. Самый честный layer.
Search patterns:
- `site:reddit.com "<topic>" experience OR review`
- `site:news.ycombinator.com <topic>`
- `"<topic>" reddit "actually works" OR "use this"`

### Вектор 3 — YouTube популярность
Что реально снимают и смотрят = что используют.
Search patterns:
- `"<topic> tutorial" youtube 2025 most viewed`
- `"<topic>" beginner tutorial nodejs 2025`

### Вектор 4 — GitHub trending
Звёзды + дата последнего коммита = живость.
Search patterns:
- `"<topic>" github trending 2025`
- `"<topic>" awesome-list github`

### Вектор 5 — Indie Hacker / Product Hunt / Dev.to
Что shipят solo-разработчики в 2025-2026.
Search patterns:
- `site:indiehackers.com "<topic>"`
- `site:dev.to "<topic>" 2025`
- `site:producthunt.com "<topic>"`

### Вектор 6 — Twitter/X dev community
Свежие хаки, дешёвые workarounds.
Search patterns:
- `site:twitter.com OR site:x.com "<topic>" 2025 simple OR cheap`

### Вектор 7 — Alternatives
Заведомо ищем "не топ-3" чтобы найти hidden gems.
Search patterns:
- `"alternative to <topic>" reddit 2025`
- `"<topic>" 10 alternatives compared`
- `"cheap <topic> service" indie 2025`

### Вектор 8 — Pain-points / "почему все избегают"
Контр-сигнал: что разработчики обходят и почему.
Search patterns:
- `"<topic>" "too complicated" OR "easier way" 2025`
- `"<topic>" pain points complaints reddit`

### Вектор 9 — Free / sandbox / personal use
Каждый сервис обычно имеет тихий бесплатный путь для personal use.
Search patterns:
- `"<topic>" free tier sandbox personal 2025`
- `"<topic>" "no credit card" testing`

### Вектор 10 — Случаи похожие на наш use case
Узкий фокус на личных ассистентов / ботов / маленькие проекты.
Search patterns:
- `"personal ai assistant" "<topic>" github 2025`
- `"<topic>" solo developer setup simplest`

---

## Workflow

```
1. ОПРЕДЕЛИТЬ TOPIC (1 минута)
   └── Узкая, конкретная задача (не "AI", а "WhatsApp Cloud API receive messages Node.js")

2. СПАВН АГЕНТОВ (одно сообщение, параллельно)
   └── Минимум 4 агента (4 разных вектора)
   └── Идеально 6-8 агентов для критичного решения

3. СВОДНАЯ ТАБЛИЦА (5 минут)
   ├── Метод | Цена | Сложность | Время до работы | ToS-риск | Объём в коде
   ├── Колонка с цитатой/URL источника на КАЖДОЕ утверждение
   └── Никаких pri-knowledge claims без URL

4. ПРОВЕРКА АРХИТЕКТОРА (1 минута)
   ├── Соответствие канону (#0, #2, #3, #6)
   ├── Lock-in риск (если сервис закроется)
   ├── Стоимость через 12 месяцев
   └── Кривая сложности при росте объёма

5. РЕКОМЕНДАЦИЯ
   ├── Quick path (запускаемся сегодня)
   ├── Long-term path (через N недель параллельно)
   └── Что обходим явно и почему
```

---

## Ошибки которые этот протокол ловит

1. **First-good-answer bias** — модель находит правдоподобный ответ из training data и останавливается. Реальный мир ушёл вперёд.
2. **Documentation bias** — официальные docs показывают "правильный" путь, который часто overengineered.
3. **Enterprise bias** — много контента написано для enterprise, которому неважна цена/сложность.
4. **Stale data** — модель не знает про сервис который запустился 6 месяцев назад.
5. **Vendor capture** — топ результатов в Google часто проплачены, индивидуальные блоги дают честнее.

---

## Шаблон для применения

```
Архитектор: "Нужно интегрировать <X>. Что есть простого?"

Шаг 1. Архитектор спавнит 4-8 параллельных Agent(Explore):
  - Reddit/форумы
  - YouTube популярность
  - GitHub trending alternatives
  - Indie Hackers + Dev.to
  - "Easier alternatives to <main approach>"
  - "<X> personal use free tier"

Шаг 2. Архитектор сводит в таблицу:
  - Минимум 8-12 методов
  - Сравнение по 6 столбцам
  - Каждое утверждение с URL

Шаг 3. Архитектор предлагает 2-track план:
  - Quick (запускаемся за часы)
  - Long-term (правильный путь параллельно)
```

---

## История применения

- **2026-04-26:** WhatsApp интеграция. Первый ответ: Cloud API + PT PMA верификация (2-3 недели + $150 переводы). Второй цикл нашёл WAHA (Docker, 30 мин, $0) + WhatsApp MCP (HN viral) + WASenderAPI ($6/мес). Решение: WAHA quick + Cloud API параллельно.

- *(добавлять каждый раз когда применяется)*
