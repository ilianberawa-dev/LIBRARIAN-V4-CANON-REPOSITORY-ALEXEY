# Claude Library — индекс для всех чатов

**Что это:** knowledge base проекта Realty Portal + методологий AI-ассистентов.
**Автор канона:** Алексей Колесов (приватный Telegram-канал).

---

## ⚡ ЧЕТЫРЕ ГЛАВНЫХ ПРАВИЛА

1. **YOU MUST** при старте сессии — ритуал онбординга (inbox + 4 вопроса +
   последние `docs/session-memory/`). **При первом заходе в репо** — также
   прочитать `kanon/alexey-11-principles.md` (12 принципов канона).
   См. `.claude/skills/onboarding.md`.

2. **YOU MUST** при архитектурном/дизайн-вопросе — 3-слойный поиск
   (или Слой 0 — мульти-агент при широкой теме). Не отвечай из общих знаний.
   См. `.claude/skills/library-search.md`.

3. **YOU MUST** в конце сессии — записать `docs/session-memory/...md`.
   Адресная передача — `docs/handoff/...` или GitHub Issue с label `handoff`.
   См. `.claude/skills/session-memory.md`.

4. **YOU MUST** при «разбери inbox» — спросить «один проект или несколько?»
   и группировать по проекту, не по типу файла.
   См. `.claude/skills/inbox-triage.md`.

Принцип #0 Алексея (Простота) — фон: `kanon/alexey-11-principles.md`.

---

## 📁 КАРТА ПАПОК

| Папка | Что внутри |
|---|---|
| `inbox/` | Свалка для новых файлов (по команде «разбери inbox») |
| `kanon/` | 12 принципов Алексея + Memory Pyramid (всегда читать архитектору) |
| `dizain/`, `arhitektura/`, `prochee-idei/` | 3 темы для разбора inbox |
| `alexey-materials/` | 154 поста + 44 транскрипта (через `metadata/index_compact.json`) |
| `docs/session-memory/` | Память сессий (broadcast всем чатам) |
| `docs/handoff/` | Адресная передача преемнику (через JSON в первом сообщении) |
| `aeza-archive/`, `school-materials/`, `OLD-PARSER-STRUCTURE/` | Архивы — **не трогать без явной просьбы** |
| `metody/`, `rukovodstva/`, `navyki/`, `spravochniki/`, `troubleshoot/`, `scripts/` | По запросу |

---

## 🔗 МЕЖЧАТНАЯ КОММУНИКАЦИЯ

- **Старт.** Hook печатает 3 последних `session-memory`. При **операционном**
  вопросе дополнительно: `git fetch && git log HEAD..@{u}` +
  `mcp__github__list_issues --label handoff --state open`.
  Подробнее: `.claude/skills/state-check.md`.
- **Конец сессии.** Итог в `docs/session-memory/<date>-<role>-<topic>.md`
  (broadcast). Если нужна адресная передача конкретному чату — плюс
  `docs/handoff/...md` ИЛИ GitHub Issue с label `handoff`.
- **Срочная ссылка между чатами.** Илья называет номер вслух: «чат Б,
  посмотри issue 42» или «PR 17». Чат открывает через MCP.
  **Не ищи где-то — жди номер.**

---

## 📋 ПРАВИЛА ПОВЕДЕНИЯ

- **Имя пользователя — Илья.** Алексей Колесов — автор канона (коуч Ильи),
  не пользователь чата. Не путать.
- **Канон vs чат.** Канон = только `kanon/` + `alexey-materials/`. Слова Ильи
  в чате — запросы пользователя, **не канон**. Детали: `state-check.md`.
- **Лимит ответа.** Каждое сообщение Claude в чат **≤ 10 000 знаков**.
  Длиннее — разбей и спроси «продолжать?». На длинных Claude Code обрывает flow.
- **Только факты + альтернативы.** Не pitch. Длинные файлы кода — Edit/Write,
  в чат summary.
- **Читай только нужное:** `kanon/`, `CLAUDE.md`, `.claude/skills/*.md`,
  `alexey-materials/metadata/index_compact.json`. Без команды не делай
  `find`/`ls`/`grep` по подпапкам.
- **Коридор разрешений** — `.claude/settings.json` (в git, наследуется
  всеми чатами) + `~/.claude/settings.json` (глобальный):
  `rm*`, `sudo`, `git push --force`, `git reset --hard` — **запрещены**.
  `git push`, `npm publish`, `docker build`, MCP `create_pr` — **спрашивают**.
  Остальные безопасные команды (Read/Glob/Grep/Edit/Write/Bash безопасные) —
  **разрешены тихо**.

---

**Версия:** 3.0 (slim+canon-vs-chat+inter-chat) — 2026-04-27
