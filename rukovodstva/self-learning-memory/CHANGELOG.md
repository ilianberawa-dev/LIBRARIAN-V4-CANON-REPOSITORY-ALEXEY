# Self-Learning Memory (RAG) - Version History

## v1.0 - LightRAG Integration (2026-04-24)

**Status:** Initial release  
**Creator:** librarian-v4  
**File:** `v1.0-lightrag.md`

### What's included:
- ✅ RAG (Retrieval Augmented Generation) architecture
- ✅ Chunking strategy by document type (transcripts, emails, code, canon)
- ✅ Embedding model: Ollama mxbai-embed-large (768-dim, multilingual)
- ✅ Vector database: LightRAG (graph-based knowledge)
- ✅ Attribution system (WHO/WHEN/WHERE/WHAT/WHY)
- ✅ Learning loop (self-learning after each session)
- ✅ Proactive recall (assistant remembers relevant context)
- ✅ Quality metrics (precision, recall, attribution accuracy, latency)
- ✅ Integration guide for AI Assistant Phase 1 MVP
- ✅ Use cases with examples
- ✅ Troubleshooting section

### Technical stack:
- **Embedding:** Ollama mxbai-embed-large on Aeza (100.97.148.4:11434)
- **Vector DB:** LightRAG on Aeza (100.97.148.4:9621)
- **Storage:** /opt/realty-portal/lightrag/
- **Chunk sizes:** 200-500 tokens depending on document type
- **Overlap:** 30-100 tokens for context preservation

### Chunking strategy:
| Document Type | Chunk Size | Overlap |
|---------------|------------|---------|
| Transcript    | 500 tokens | 100     |
| Email thread  | 300 tokens | 50      |
| Code file     | 200 tokens | 30      |
| Canon doc     | 400 tokens | 80      |
| Chat history  | 250 tokens | 50      |

### Size:
- 620 lines
- ~20KB
- 621 строка контента

### Target audience:
- AI Assistant developers needing semantic memory
- Anyone building RAG systems with LightRAG
- Projects requiring attribution tracking ("who said what when")

---

## Planned updates:

### v1.1 - Improved Chunking (planned)
- [ ] Adaptive chunk sizing based on document complexity
- [ ] Better overlap strategy for technical documents
- [ ] Chunk quality scoring

### v1.2 - Multi-Language Support (planned)
- [ ] Enhanced multilingual embeddings (EN/RU/ID/CN)
- [ ] Language-specific chunking rules
- [ ] Cross-language semantic search

### v2.0 - Advanced Attribution (planned)
- [ ] Confidence scoring for attributions
- [ ] Conflict resolution (when sources disagree)
- [ ] Citation graph visualization

### v2.1 - Performance Optimization (planned)
- [ ] HNSW index configuration
- [ ] Query caching layer
- [ ] Batch embedding processing

---

**Latest version:** v1.0  
**Last updated:** 2026-04-24
