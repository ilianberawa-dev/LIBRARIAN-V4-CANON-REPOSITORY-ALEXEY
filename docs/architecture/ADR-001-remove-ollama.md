# ADR-001: Удаление Ollama из стека Realty Portal

**Статус:** ACCEPTED
**Дата:** 2026-04-26
**Автор:** Claude Opus 4.7 (architect session) по решению Ильи

---

## Контекст

В стэке `realty_lightrag` использовалась локальная Ollama для одной задачи —
embeddings `all-minilm` 384-dim для LightRAG. LLM-инференс уже шёл через LiteLLM
gateway → Anthropic/OpenAI/Gemini/etc. (канон IU3, multi-model triangulation).

## Проблема

| Ресурс | Стоимость Ollama |
|---|---|
| Docker образ | ~10.1 GB |
| RAM (постоянно) | ~1.5 GB (модель + процесс) |
| CPU | embedding requests CPU-bound, конкурируют с Postgres |
| VPS uplift | +$6-8/мес (для покрытия RAM/disk требований 8GB → 6GB рассматриваемой VPS) |
| Скорость | в разы медленнее API-embeddings на маломощных VPS |

**Break-even:** Ollama окупается только при расходах на Claude Sonnet >$100/мес,
когда экономия на токенах перекрывает инфраструктуру. Текущий cumulative LLM
spend = $5.44 (по handoff) — Ollama невыгодна на порядки.

## Решение

Удалить сервис `ollama` из `lightrag/docker-compose.yml`. Перенаправить
embeddings LightRAG на LiteLLM gateway → `text-embedding-3-small` (OpenAI,
1536-dim, $0.02 / 1M tokens).

### Изменения

1. `lightrag/docker-compose.yml`:
   - Удалён сервис `ollama` + volume `realty_ollama_models`.
   - Удалён `depends_on: ollama` в `lightrag`.
   - `EMBEDDING_BINDING: ollama` → `openai`.
   - `EMBEDDING_BINDING_HOST: http://realty_ollama:11434` → `http://realty_litellm:4000`.
   - `EMBEDDING_MODEL: all-minilm` → `text-embedding-3-small`.
   - `EMBEDDING_DIM: 384` → `1536`.
   - Добавлен `litellm_config.yaml` bind-mount + `--config` flag.
   - Добавлены healthchecks для litellm и lightrag.

2. `lightrag/litellm_config.yaml`:
   - Добавлена модель `text-embedding-3-small` (требует `OPENAI_API_KEY` в `.env`).

3. `.env.example`:
   - `OPENAI_API_KEY` уже есть в секции gateway — без изменений.

## Стоимость нового решения

На корпусе канала Алексея (~150 постов × 1 KB ≈ 150 KB) полный
re-embedding ≈ $0.000003. Даже при расширении до клиентских портфелей
(10 000 объявлений × 2 KB = 20 MB) — $0.0004 одноразово, $0.04/мес при
полном перерасчёте раз в день. **Незаметная статья расходов.**

## Соответствие принципам канона

| Принцип | Эффект |
|---|---|
| #0 Simplicity | ✅ один embedding-провайдер вместо двух |
| #1 Portability | ✅ -10GB образ → стэк помещается на 30GB VPS |
| #2 Minimal Integration | ✅ Embeddings через тот же IU3 LiteLLM gateway, не отдельный сервер |
| #6 Single Vault | ✅ `OPENAI_API_KEY` уже в `.env` — переиспользование |
| #8 Validate Before Automate | ✅ Cloud embedding достаточно для текущей нагрузки — миграция назад на локаль возможна когда break-even |

## Откат

При росте корпуса до >10M токенов/мес и стабильного спроса — вернуть Ollama
в отдельном compose-проекте `ollama/docker-compose.yml` (не в lightrag) и
переключить только embedding endpoint LightRAG обратно. LiteLLM остаётся
неизменным.

## Новые требования к серверу

| Компонент | Старое | Новое |
|---|---|---|
| RAM минимум | 8 GB | **4 GB** (рекомендуется 6 GB) |
| Disk | 60 GB | **30 GB** (комфортно — 40 GB) |
| vCPU | 2 | 2 (без изменений) |
| Месячная стоимость VPS (типовая Aeza/Hetzner) | $20-25 | **$10-15** |

**Чистая экономия: ~$8-10/мес VPS + операционная скорость embedding requests
в 5-10 раз выше через API.**
