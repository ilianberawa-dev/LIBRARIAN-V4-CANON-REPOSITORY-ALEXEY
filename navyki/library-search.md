# Тематический поиск в библиотеке (без LightRAG)

**Когда использовать:** вопрос «что Алексей говорил про X?»  
**Слоёв:** 2 (synonyms → index_compact → контент)

---

## Алгоритм

### Шаг 1 — термины → теги
```
Read alexey-materials/metadata/synonyms.json
```
Найди русский термин из вопроса → получи канонические теги.  
Пример: «память» → `["RAG", "LightRAG", "MEMORY_RAG"]`

Если термина нет в synonyms — используй его напрямую как тег.

### Шаг 2 — теги → посты
```
Read alexey-materials/metadata/index_compact.json
```
Фильтруй посты где `topics[]` ИЛИ `category` содержит найденные теги.  
Смотри на `has_transcript` и `preview`.

### Шаг 3 — читать контент

**Если `has_transcript: true`:**
```
Read alexey-materials/transcripts/[id]_*.txt
```

**Если `has_transcript: false`:**  
`preview` в index_compact — первые ~250 символов поста.  
Если мало — grep в Private.md:
```
Grep pattern="\*#[id]\*" path=alexey-materials/Алексей Колесов - Private.md
```

---

## Пример: «что Алексей говорил про LightRAG?»

1. synonyms: «память» → `["RAG","LightRAG","MEMORY_RAG"]`
2. index_compact фильтр по topics ⊃ LightRAG:
   - #165 `has_transcript:true` — Встреча 05.04.26 ⭐ (роутинг, настройки, токены)
   - #160 `has_transcript:false` — пакет по LightRAG (preview достаточен)
   - #167 `has_transcript:false` — 20 минут собрать базу знаний
3. Читаем #165 транскрипт → таймстамп 06:40 = настройки поиска

---

## Известные дыры synonyms.json

| Термин | Что добавить |
|--------|-------------|
| «роутинг» | LightRAG, LLM ✅ добавлено 2026-04-29 |
| «сервер» | INFRA, Docker |
| Новые промахи | Добавлять сюда + в synonyms.json |

---

## Ограничения (когда нужен LightRAG)

- Вопрос семантический: «как Алексей подходит к X» без точного термина
- Нужны связи между концепциями
- Корпус вырос > 300-400 постов

**До 300 постов — file-based достаточен.**
