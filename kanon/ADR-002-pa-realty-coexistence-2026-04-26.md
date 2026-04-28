# ADR-002 — PA Assistant + Realty Portal: Сосуществование на одном VPS

**Дата:** 2026-04-26
**Статус:** ACCEPTED
**Автор:** Архитектор L-1
**Авторитет:** Канонический — переопределяет любые решения об объединении стеков

---

## Контекст

На одном UpCloud VPS планируется запуск двух систем:
- **Personal AI Assistant** (MVP разгрузки личных чатов Ильи)
- **Realty Portal** (B2B парсинг недвижимости Бали/Дубай/Сочи)

Вопрос: объединять ли стеки, переиспользовать ли компоненты?

## Решение: НЕ объединять, сосуществовать

### Главный конфликт — разная архитектурная философия

| | Personal AI Assistant | Realty Portal |
|---|----------------------|---------------|
| Стек | systemd + SQLite + native Anthropic SDK | Docker (18 ctnr) + Postgres + LiteLLM + LightRAG |
| Канон | #2 Minimal Integration: запрет LiteLLM | LiteLLM как gateway |
| RAG | Запрещён (FTS5 only) | LightRAG как ядро памяти |
| Domain | Single-user message triage | Multi-tenant property parsing |
| Бюджет | $20/мес одна модель | Multi-model triangulation |
| Скейл | 1 владелец | N брокеров в перспективе |

**Слить = взорвать оба канона.** PA Assistant потеряет simplicity, Realty потеряет multi-tenant scale.

---

## Архитектура сосуществования: 3 уровня

### Уровень 1 — Shared Infrastructure (сейчас)

На одном UpCloud VPS, **разные процессы, разные директории**:

```
/opt/personal-assistant/     ← systemd, 6+1 сервисов, ~500MB RAM
/opt/realty-portal/          ← Docker stack, 18 ctnr, ~1.5GB RAM
/opt/tg-export/              ← общий host pipeline (realty)
```

**RAM расчёт:** 2GB Realty + 500MB PA + 200MB OS = **2.7GB → нужен 4GB VPS** (~$26/мес).

### Уровень 2 — Shared Resources (мелкие интеграции, можно сейчас)

| Ресурс | Решение |
|--------|---------|
| xAI API key | ✅ Один в vault `xai-api-key`, оба читают |
| Anthropic API key | ✅ Один в vault `anthropic-api-key`, оба читают |
| MTProto session | ❌ НЕТ — у каждого свой (Canon #11 Privilege Isolation) |
| transcribe.sh | ❌ НЕ объединять — Realty=batch (архив), PA=per-file (real-time). Разные интерфейсы |

### Уровень 3 — MCP Bridge (Stage 8+, осень 2026)

Правильный путь интеграции. Realty уже имеет MCP server (`/opt/mcp_agent_mail/` :8765, POC T1-T10 зачёт).

```
Владелец → Claude Desktop → MCP запрос
                              ├─→ PA MCP:     "сколько срочных от Маши за неделю?"
                              └─→ Realty MCP: "найди 2BR в Чангу до $200K"
```

Они **не знают друг о друге** — оба обслуживают Claude Desktop. Это **canon-clean integration**.

---

## Что НЕ делать (явные запреты)

- ❌ Тащить LiteLLM в PA Assistant — нарушает Canon #2
- ❌ Тащить LightRAG в PA — нарушает решение «FTS5 хватает»
- ❌ Переходить на Postgres в PA — для single-user это overengineering
- ❌ Переходить на Docker в PA — нарушает «systemd only»
- ❌ Сливать БД — разные домены, разные schema, нет общих сущностей

---

## Что взять из Realty в PA канон

| Артефакт | Применение в PA | Когда |
|----------|----------------|-------|
| MCP server pattern (`/opt/mcp_agent_mail/` JSON-RPC :8765) | Stage 8 PA MCP server | Осень 2026 |
| Heartbeat pattern (`docs/school/skills/heartbeat-common.md`, 720 строк) | Stage 6 PA heartbeat | После MVP |
| EVL skills структура | Stage 7+ vision-classification skills | После MVP |
| Tailscale→SSH-tunnel миграция | Урок для публичного endpoint | Если понадобится |

---

## Дорожная карта

1. **Сейчас:** Довести PA Assistant до MVP (Stage 5+6 deploy, ~1-2 недели).
2. **После MVP:** Развернуть Realty Portal на том же VPS (`docker compose up`, deploy-ready).
3. **К августу 2026:** Stage 8 MCP bridge — обе системы доступны из Claude Desktop.

**VPS:** UpCloud 4GB ($26/мес) — хватает на оба стека с запасом.

---

## Связь с каноном

- Canon #0 (Simplicity First) — каждая система простая внутри своего домена
- Canon #1 (Portability) — оба репо deploy-ready независимо
- Canon #2 (Minimal Integration) — минимум связей между системами
- Canon #11 (Privilege Isolation) — отдельные MTProto sessions, отдельные vault credentials
- ADR-001 — Ollama removal (Realty, предшествующий ADR)
