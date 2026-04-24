# Claude Library — Persistent Knowledge Base

**Локация:** `C:\Users\97152\Documents\claude-library\`  
**GitHub:** https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY  
**Назначение:** Доступ из ЛЮБОГО Claude чата на этой машине  
**Создано:** 2026-04-24  
**Создатель:** librarian-v4  
**Номенклатура:** Транслит + Русские README (Git-friendly + Человеко-понятно)

---

## 🗂️ Категории (Маппинг транслит → русский)

| Транслит | Русский | Emoji | Статус |
|----------|---------|-------|--------|
| `metody/` | МЕТОДЫ разработки | 📘 | ✅ 1 тема |
| `rukovodstva/` | РУКОВОДСТВА по компонентам | 📚 | ✅ 1 тема |
| `kanon/` | КАНОН (принципы) | 📜 | ✅ 2 документа |
| `navyki/` | НАВЫКИ (skills) | 🛠️ | 🚧 Пусто |
| `spravochniki/` | СПРАВОЧНИКИ | 📖 | ✅ 1 гайд |
| `troubleshoot/` | РЕШЕНИЕ ПРОБЛЕМ | 🔧 | 🚧 Пусто |

---

## 📂 Структура библиотеки

```
claude-library/
  ├── _INDEX.md (этот файл)
  │
  ├── metody/              ← МЕТОДЫ
  │   ├── README.md
  │   └── personal-ai-assistant/
  │       ├── README.md
  │       ├── v1.0-mvp-to-sales.md (767 lines)
  │       └── CHANGELOG.md
  │
  ├── rukovodstva/         ← РУКОВОДСТВА
  │   ├── README.md
  │   └── self-learning-memory/
  │       ├── README.md
  │       ├── v1.0-lightrag.md (620 lines)
  │       └── CHANGELOG.md
  │
  ├── kanon/               ← КАНОН ✨ ОБНОВЛЕНО
  │   ├── README.md
  │   ├── alexey-11-principles.md (12 принципов)
  │   └── simplicity-first-principle.md (605 lines)
  │
  ├── spravochniki/        ← СПРАВОЧНИКИ ✨ ОБНОВЛЕНО
  │   ├── README.md
  │   └── skills-a-to-ya.md (108KB полный гайд)
  │
  ├── navyki/              ← НАВЫКИ (roadmap)
  │   └── README.md
  │
  └── troubleshoot/        ← ПРОБЛЕМЫ (roadmap)
      └── README.md
```

---

## 🎯 Как работает номенклатура

### ✅ Git-friendly:
- Папки: `metody`, `rukovodstva`, `kanon` (транслитом)
- Файлы: `v1.0-mvp-to-sales.md` (латиницей)
- Коммиты работают везде (Windows/Mac/Linux)

### ✅ Человеко-понятно:
- README.md в КАЖДОЙ папке на русском
- CHANGELOG.md на русском
- Этот _INDEX.md с маппингом

### Принцип:
```
СТРУКТУРА транслитом → ОПИСАНИЕ на русском
```

---

## 📚 Текущее содержимое

### 1. МЕТОДЫ / personal-ai-assistant

**Полное название:** Личный AI Ассистент  
**Файл:** `metody/personal-ai-assistant/v1.0-mvp-to-sales.md`  
**Размер:** 767 строк, ~27KB

**О чём:**
- 4 фазы: MVP → Self-Use → Parser/Content → Client Sales
- Архитектура: Memory + Skills + MCP
- 11 принципов Алексея
- Roadmap 20+ недель
- Pricing $49-299/month

---

### 2. РУКОВОДСТВА / self-learning-memory

**Полное название:** Самообучающаяся Память (RAG)  
**Файл:** `rukovodstva/self-learning-memory/v1.0-lightrag.md`  
**Размер:** 620 строк, ~20KB

**О чём:**
- RAG архитектура
- LightRAG integration
- Attribution (WHO/WHEN/WHERE)
- Learning loop
- Use cases

---

### 3. КАНОН / alexey-11-principles ✨ НОВОЕ

**Полное название:** 12 Принципов Алексея для AI-систем  
**Файл:** `kanon/alexey-11-principles.md`  
**Размер:** ~5KB

**О чём:**
- Принцип #0: Simplicity First (P0)
- Принципы #1-11: Portability → Architectural Privilege Isolation
- Для каждого: правило, почему, деньги, примеры
- Extracted from canon_training.yaml v0.5

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\kanon\alexey-11-principles.md
```

---

### 4. КАНОН / simplicity-first-principle

**Полное название:** Принцип "Простота Прежде Всего"  
**Файл:** `kanon/simplicity-first-principle.md`  
**Размер:** 605 строк, ~28KB

**О чём:**
- Обязательный чеклист перед ответом AI
- Decision tree простых решений
- Anti-patterns overengineering
- "Бабушка-тест" (объяснить за 30 сек)
- Реальный кейс: 2 часа → 5 минут

**Применение:** ОБЯЗАТЕЛЬНО для всех AI перед ответом

---

### 5. СПРАВОЧНИКИ / skills-a-to-ya ✨ НОВОЕ

**Полное название:** Skills от A до Я  
**Файл:** `spravochniki/skills-a-to-ya.md`  
**Размер:** 108KB

**О чём:**
- Полный справочник по AI Skills
- От базовых до продвинутых
- Примеры использования
- Best practices

---

## 🚀 Быстрый старт

### Новому Claude чату:

**Шаг 1 - Прочитай index:**
```
Read C:\Users\97152\Documents\claude-library\_INDEX.md
```

**Шаг 2 - Загрузи обязательный канон:**
```
Read C:\Users\97152\Documents\claude-library\kanon\simplicity-first-principle.md
```

**Шаг 3 - Выбери нужную тему:**
```
Read C:\Users\97152\Documents\claude-library\metody\personal-ai-assistant\v1.0-mvp-to-sales.md
```

---

## 🔄 Workflow обновлений

### Добавить новую версию:

1. Создай файл: `cp v1.0-old.md v1.1-new-feature.md`
2. Обнови CHANGELOG.md
3. Обнови README.md темы
4. Обнови _INDEX.md
5. `git add . && git commit && git push`

---

## 📋 Roadmap

### Ближайшее:

**Навыки:**
- [ ] `navyki/proactive-think/` - Проактивное мышление pattern
- [ ] `navyki/gmail-check/` - Проверка почты skill

**Справочники:**
- [ ] `spravochniki/mcp-servers-setup/` - Настройка MCP серверов
- [ ] `spravochniki/lightrag-api-reference/` - LightRAG API

**Troubleshooting:**
- [ ] `troubleshoot/lightrag-slow-queries/` - Оптимизация LightRAG
- [ ] `troubleshoot/cf-blocks-parser/` - Обход Cloudflare блокировок

---

## 📊 Статистика

**Всего файлов:** 18  
**Всего строк:** 3500+  
**Категорий:** 6 (4 активные, 2 в roadmap)  
**Тем:** 5 (personal-ai-assistant, self-learning-memory, alexey-principles, simplicity-first, skills-a-to-ya)  
**Размер репо:** ~180KB

---

## 🔒 Доступ и безопасность

**Доступ:** Только локальная машина + GitHub (private/public по выбору)  
**Git:** ✅ Git-friendly (транслит латиницей)  
**Backup:** GitHub auto-backup при каждом push

---

**Последнее обновление:** 2026-04-24  
**Создано:** librarian-v4  
**Формат:** Универсальный (Git + Человек)
