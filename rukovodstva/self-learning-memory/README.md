# Самообучающаяся Память (RAG)

**Категория:** Руководство по компоненту  
**English:** Self-Learning Memory (RAG System)  
**Транслит:** self-learning-memory  
**Статус:** ✅ v1.0 Release

---

## 📋 Описание

RAG (Retrieval Augmented Generation) система для AI ассистента с семантическим поиском, attribution tracking и самообучением.

**Проблема решает:** "Кто предлагал X?" "Что я забыл по теме Y?" "Эволюция идеи Z"

---

## 🎯 Что включено

### Архитектура RAG:
1. **Document Chunker** - разбивка по типам (transcript, email, code, canon, chat)
2. **Embedding Model** - Ollama mxbai-embed-large (768-dim, multilingual)
3. **Vector Database** - LightRAG (graph-based, уже на Aeza)
4. **Retriever** - semantic search
5. **Attribution** - WHO/WHEN/WHERE/WHAT/WHY
6. **Learning Loop** - самообучение после каждой сессии

### Chunking Strategy:
| Тип | Размер | Overlap |
|-----|--------|---------|
| Transcript | 500 tokens | 100 |
| Email | 300 tokens | 50 |
| Code | 200 tokens | 30 |
| Canon | 400 tokens | 80 |
| Chat | 250 tokens | 50 |

### LightRAG уже установлен:
- Docker: `realty_lightrag`
- Port: `100.97.148.4:9621`
- Storage: `/opt/realty-portal/lightrag/`

### Use Cases:
- "Кто предлагал правила Waymen?" → Alexey, transcript-147, 2026-04-15
- "Что я забыл по OpenClaw?" → 3 напоминания с attribution
- "Эволюция идеи парсера" → Timeline 15 апр → 24 апр

---

## 📂 Версии

### v1.0-lightrag.md (текущая)
**Дата:** 2026-04-24  
**Размер:** 620 строк, ~20KB  
**Статус:** Initial release

**Читать:**
```
Read C:\Users\97152\Documents\claude-library\rukovodstva\self-learning-memory\v1.0-lightrag.md
```

**История версий:**
```
Read C:\Users\97152\Documents\claude-library\rukovodstva\self-learning-memory\CHANGELOG.md
```

---

## 🚀 С чего начать

1. Прочитай руководство (v1.0)
2. LightRAG уже работает на Aeza (проверь: `docker ps | grep lightrag`)
3. Ingest existing knowledge (transcripts, canon, memory)
4. Test semantic search: "Найди правила Алексея"
5. Добавь в AI Assistant (Phase 1 MVP)

**Время установки:** 30-60 мин (если LightRAG уже работает)

---

## 🎓 Для кого

- ✅ AI Assistant developers - нужна долгосрочная память
- ✅ RAG builders - работают с LightRAG
- ✅ Projects с attribution - "кто что когда сказал"

---

## 🔗 Связанные материалы

- **Метод:** `metody/personal-ai-assistant/` - интеграция RAG в Phase 1
- **Troubleshoot:** `troubleshoot/lightrag-slow-queries/` (планируется)

---

**Создано:** librarian-v4, 2026-04-24  
**Последнее обновление:** 2026-04-24
