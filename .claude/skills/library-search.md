---
name: library-search
description: 3-layer search protocol for Alexey's library (taxonomy → compact index → full-text grep). Use for ANY architectural or design question to find relevant materials before answering from general knowledge.
---

# 3-слойный поиск в библиотеке

При архитектурном/дизайн-вопросе **обязательно** ищи в библиотеке. Не отвечай
из общих знаний если в библиотеке есть материал.

## Слой 1 — таксономия (мгновенно)

1. Прочитай `alexey-materials/metadata/synonyms.json` — преобразуй термины
   запроса в канонические теги
2. Прочитай `alexey-materials/metadata/taxonomy.json` — выбери **1 категорию**
   из 10 (AI_AGENTS, SKILLS_MCP, WORKFLOW, DATA_STORAGE, MEMORY_RAG, INFRA,
   COMMUNICATION, PARSING, PRODUCTS_AK, PRINCIPLES_BIZ)

## Слой 2 — компактный индекс (быстро)

3. Открой `alexey-materials/metadata/index_compact.json`
4. Отфильтруй по выбранной `category`
5. Найди 1-3 поста по `topics` или `transcript_keys`
6. Прочитай `preview` каждого

## Слой 3 — полный текст (только если нужно)

7. Если в превью **видно нужное** — прочитай `text_full` через
   `library_index.json` для конкретного `msg_id`
8. Если в превью **не очевидно** — запусти
   `bash scripts/search_transcripts.sh "<запрос>"`
   и читай транскрипты найденных файлов

## Правила качества

- **Максимум 3 поста на 1 запрос** — если мало, спроси пользователя
- **Если все 3 финалиста слабо релевантны** — НЕ применяй молча, скажи:
  *"точного материала нет, ближайшее — X, Y. Использовать?"*
- **Цитируй источник:** *"согласно посту #181 (browser-ak): '...Camoufox обходит Cloudflare...'"*
- При сомнении — **спроси**, не выдавай ответ из общих знаний под видом библиотеки
