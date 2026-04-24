# Alexey reference — knowledge base

**Автор материалов:** Алексей Колесов
**Источник:** подписка на приватку через Tribute (начата 2026-04-20)
**Назначение:** личный knowledge base для Realty Portal, НЕ для публикации
**Статус в git:** полностью в `.gitignore`

## Структура

```
docs/alexey-reference/
├── INDEX.md                        # этот файл
└── guides/
    ├── skills-a-to-ya.pdf          # оригинал PDF (53 страницы, апрель 2026)
    └── skills-a-to-ya.md           # извлечённый markdown (67KB)
```

## Содержимое

### guides/skills-a-to-ya — «Skills от А до Я»

Полное руководство Алексея по созданию Agent Skills. 53 страницы. Содержит:

**Часть I — Мотивация (pages 3-4):** 8 агентов → 1 скилл, история devops-ak
**Часть II — Анатомия скилла (pages 5-13):**
- Skill = Markdown-файл с пошаговыми инструкциями
- 3 уровня сложности: Level 1 (just SKILL.md), Level 2 (+ references/), Level 3 (+ scripts/)
- Контекст = всё (principle: load only what's needed now)
- Global `~/.claude/skills/` vs project `.claude/skills/`
- Activation: автоматическая (по description) или `/skill-name` slash-команда
- CLAUDE.md vs SKILL.md — не путать
- Single format работает в Claude Code / Gemini CLI / Codex / Perplexity / OpenClaw / Cursor / Windsurf / Kilo

**Часть III — Создание скиллов (pages 14-35):**
- 3 способа: из чата / `/skill-creator` / вручную
- Практика: review-reply скилл через skill-creator (full example)
- Description formula: ЧТО + КОГДА + ТРИГГЕРЫ (bilingual!)
- allowed-tools YAML field
- Testing через skill-creator (60/40 train/test, 5 iterations)

**Часть IV — Production devops-ak (pages 36-39):**
- File structure: SKILL.md (91 lines) + 10 references + 15 scripts + assets
- Line-by-line SKILL.md breakdown
- When scripts needed vs когда достаточно инструкций

**Часть V — Production-ready (pages 40-45):**
- От прототипа к стабильной системе
- Автоматизация (cron / schedule)
- Воркфлоу / цепочки / оркестрация (relevant для нашего EVL-ORC-016)
- Security (чужие скиллы = audit перед использованием)

**Справочник (pages 46-51):**
- SKILL.md шаблон (canonical format)
- Чеклист готовности (pre-use + pre-production)
- Глоссарий
- Ссылки на skills.sh (91K+), SkillsMP.com (66K+), NeuralDeep, awesome-agent-skills

## Ключевые выводы для Realty Portal

### Канонические правила которые мы должны соблюдать

1. **description formula:** ЧТО + КОГДА + ТРИГГЕРЫ на РУССКОМ + английском. Наши 16 EVL-* descriptions только на английском — **нужно добавить русские триггеры**.

2. **SKILL.md < 5000 токенов.** Если больше — выносить в `references/`. Наш EVL-NOR-004 ~12KB ≈ 3000 токенов — на грани, но OK.

3. **Канонический шаблон секций:**
   - `## When activated` (2-4 situations)
   - `## Instructions` (numbered steps)
   - `## Examples` (typical + edge)
   - `## Troubleshooting` (2+ scenarios)
   - `## Rules (ALWAYS follow)` — секция в конце

   **Наши 16 EVL-* имеют:** Mission / Inputs / Outputs / Logic (draft) / Architectural lineage / Calibration history. **Это НЕ каноничный формат Алексея.** Нужна ревизия.

4. **`allowed-tools: ["Bash", "Read", "Write"]`** — критично для автономности. У нас не прописано.

5. **3 уровня сложности** — мы пока Level 1 (только SKILL.md). Для production нужен Level 3 (+ scripts/ для детерминированных действий, + references/ для деталей).

6. **Скилл может объединять несколько действий** — **подтверждает ADR-021** (конслидация 15→13 скиллов допустима).

### Ресурсы для reconnaissance

- **skills.sh** (91K+ скиллов): `npx skills add <name>` — проверить на похожие для CLS / NAR / COMP
- **SkillsMP.com** (66K+ ZIP-download)
- **NeuralDeep** — российские сервисы
- **awesome-agent-skills** — curated list

### Инструменты которые стоит внедрить

1. **`/skill-creator`** — встроенный в Claude Code, создаёт + тестит скиллы (60/40 split, 5 iterations, HTML report). Идеально для наших llm_prompt скиллов (CLS-002/003, NAR-015).
2. **TodoWrite** — канонический паттерн Алексея для длинных контекстов. Мы используем редко.
3. **Minimal tool surface** — отключить ненужные MCP при работе над конкретным скиллом.

## Что делать дальше

### Перед Phase B (code buildout)
1. Ревизовать 16 SKILL.md под canonical template Алексея (When activated / Instructions / Examples / Troubleshooting / Rules)
2. Добавить русские триггеры в descriptions
3. Добавить `allowed-tools` YAML field
4. Recon на skills.sh — нет ли готовых для CLS / NAR / comps retrieval

### Во время Phase B
- Каждый скилл с детерминированной логикой (COMP-*, NOR-004, STAT-*) → добавить `scripts/` для предсказуемых действий
- LLM-скиллы (CLS-002, CLS-003, NAR-015) → добавить `references/` с деталями C1-C5 matrix, zone hints, narrative templates

### Process
- Создать **ADR-022: "Adopt Alexey's canonical SKILL.md template (Skills A-to-Ya guide 2026-04)"**
- Обновить `sales-comparison-logic.md` §5 skill table — добавить ссылки на canonical format
- Обновить `tool-architecture.md` — reference to Alexey guide
