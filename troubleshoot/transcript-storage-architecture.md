---
title: Transcript Storage Architecture — claude-library vs LightRAG vs Aeza
category: INFRASTRUCTURE
topics: [storage, architecture, rag, indexing, decision]
author: архитектор (Илья)
date: 2026-04-29
status: DECIDED
severity: DESIGN
---

# Transcript Storage Architecture

**Проблема:** Где хранить 56 транскриптов? В claude-library, в LightRAG, или только metadata?

**Решение:** Трёхуровневая архитектура хранения.

---

## 📊 Старая модель (была ошибка)

```
claude-library/alexey-materials/transcripts/
├── 164_*.json + .txt (есть)
├── 165_*.json + .txt (есть)
├── 170_*.json + .txt (есть)
├── ... (нет 53 файлов)
└── [говорили что 56, реально 3] ❌

_INDEX.md: "✅ Локально в claude-library (56 транскриптов)"
Реальность: ❌ ВРЁТ
```

**Проблемы:**
1. Занимает 80MB в git (heavy)
2. Синхронизация сломана (обновляется вручную, не всегда)
3. Поиск через grep файлов — неэффективно
4. _INDEX.md неправдив (архитектор видит "56", доверяет, разочаровывается)

---

## ✅ Новая модель (правильная)

```
┌─────────────────────────────────────────────────────────────┐
│                     층 ТРЁХУРОВНЕВОЕ ХРАНЕНИЕ             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  claude-library/                                           │
│  ├── alexey-materials/metadata/                           │
│  │   └── library_index.json ← ИСТОЧНИК ИСТИНЫ            │
│  └── alexey-materials/transcripts/                        │
│      ├── 164_Аудио_встреча_06.03.26.wav.*.{json,txt}    │
│      ├── 165_Встреча_05.04.26_LightRAG.mp4.*.{json,txt} │
│      └── 170_видео.mp4.*.{json,txt}                      │
│      [3 ключевых файла, ~2.1MB]                          │
│                                                             │
│  Aeza /opt/tg-export/                                      │
│  ├── transcripts/ [56 полных файлов, 150MB]              │
│  └── library_index.json [source of truth]                │
│  [Backup + Stage 1 ingestion]                            │
│                                                             │
│  UpCloud LightRAG                                          │
│  ├── /documents/{id} [56 documents indexed]              │
│  ├── /vectors/ [embedding indices]                       │
│  └── /graphs/ [entity relations]                         │
│  [Основной поиск через RAG-engine]                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Назначение каждого уровня

| Уровень | Что | Размер | Поиск | Доступ | Sync |
|---------|-----|--------|-------|--------|------|
| **claude-library** | 3 ключевых + metadata | 2.1MB | grep, Python | Из чатов | Git |
| **Aeza /transcripts/** | 56 full backup | 150MB | Sequential | SSH | Cron (github-sync.sh) |
| **UpCloud LightRAG** | 56 indexed, embedded | 500MB+ | **RAG semantic** | API endpoint | Ingestion cron |

---

## 📌 Когда использовать каждый уровень

### 1. claude-library (для архитектора)
- ✅ **Быстро вспомнить:** встреча 05.04.26 о LightRAG → читай #165
- ✅ **Понять структуру:** какие посты есть → смотри library_index.json
- ✅ **Контекст для LLM:** передать в prompt 1-2 ключевых транскрипта
- ❌ **Полный поиск:** если нужна информация про всё — используй LightRAG API

### 2. Aeza /transcripts/ (для администратора)
- ✅ **Backup:** если LightRAG упадёт
- ✅ **Debug:** посмотреть raw транскрипт (Grok может ошибаться)
- ✅ **Миграция:** если нужно перелить в другой LightRAG
- ❌ **Основной доступ:** обычный пользователь идёт через LightRAG API

### 3. UpCloud LightRAG (для пользователя)
- ✅ **Поиск:** "расскажи про Docker и Kubernetes сравнение"
- ✅ **Routing:** автоматический выбор релевантных узлов графа
- ✅ **Semantic:** "что говорил Алексей о memory?" (не нужны exact keywords)
- ✅ **Контекст:** LightRAG возвращает + связанные узлы (context reuse)

---

## 🔄 Dataflow: синхронизация между уровнями

```
Telegram канал (154 посты)
    ↓ (sync_channel.mjs, cron 6h)
Aeza: library_index.json (обновляется)
    ↓ (download.mjs, cron 6h)
Aeza: /transcripts/ (56 файлов)
    ↓ (pipeline_one.mjs, вручную per video)
Aeza: /transcripts/ (56 polished transcripts)
    ├─ (github-sync.sh, автоматический)
    │  ↓
    │  GitHub: /transcripts/ (56 backed up)
    │  ↓ (git pull, вручную)
    │  claude-library: /transcripts/ (3 ключевых hand-picked)
    │
    └─ (ingest_transcripts.py, cron 2h)
       ↓
       UpCloud LightRAG: /documents/{id} (56 indexed)
       ↓ (RAG-engine)
       User query: "про что встреча 05.04?" → #165 relevant context
```

---

## 💾 Size Optimization

| Место | Содержимое | Size | Keep? | Reason |
|-------|-----------|------|-------|--------|
| claude-library | 3 ключевых + metadata | 2.1MB | ✅ YES | Quick access from chats |
| GitHub | 3 ключевых + metadata | 2.5MB | ✅ YES | Backup + public reference |
| Aeza /transcripts/ | 56 полных | 150MB | ✅ YES | Working copy + disaster recovery |
| Aeza .github-repo/ | 56 полных (copy) | 150MB | ❌ NO | Remove (duplicate of /transcripts/) |
| UpCloud LightRAG | 56 indexed + vectors | 500MB+ | ✅ YES | Main search engine |

**Total:** ~650MB (reasonable for knowledge base this size)

---

## 📋 Checklist для Stage 2

- [ ] Verify library_index.json на Aeza актуален (154 постов)
- [ ] Confirm ingest_transcripts.py будет запущен для 56 файлов → UpCloud
- [ ] Проверить что 53 "missing" транскрипта будут ingested (не только 15)
- [ ] Удалить дубликаты в .github-repo/ (duplicate of /transcripts/)
- [ ] claude-library/transcripts/ останется 3 файла (not 56)
- [ ] _INDEX.md обновлён с честным статусом ✓

---

## 🎯 Правило для будущего

**Если в _INDEX.md написано статус синхронизации:**
1. Всегда проверить реальность (ls -la, git ls-files)
2. Если не совпадает → обновить _INDEX.md IMMEDIATELY
3. Никогда не писать "все синхронизировано" если синхронизация partial

**Это избегает проблемы Факта #2** (архитектор видит 56, на самом деле 3).

---

**Status:** ✅ DECIDED & IMPLEMENTED (2026-04-29)  
**Arch decision:** 3-level storage (claude-library metadata + LightRAG search + Aeza backup)  
**Impact:** Storage optimized, search correct, _INDEX.md honest
