# Claude Library — Persistent Knowledge Base

**Локация:** `C:\Users\97152\Documents\claude-library\`  
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
| `kanon/` | КАНОН (принципы) | 📜 | ✅ 1 принцип |
| `navyki/` | НАВЫКИ (skills) | 🛠️ | 🚧 Пусто |
| `spravochniki/` | СПРАВОЧНИКИ | 📖 | 🚧 Пусто |
| `troubleshoot/` | РЕШЕНИЕ ПРОБЛЕМ | 🔧 | 🚧 Пусто |

---

## 📂 Структура библиотеки

```
claude-library/
  ├── _INDEX.md (этот файл)
  │
  ├── metody/              ← МЕТОДЫ
  │   ├── README.md        (описание категории на русском)
  │   └── personal-ai-assistant/
  │       ├── README.md    ("Личный AI Ассистент" на русском)
  │       ├── v1.0-mvp-to-sales.md
  │       └── CHANGELOG.md (на русском)
  │
  ├── rukovodstva/         ← РУКОВОДСТВА
  │   ├── README.md
  │   └── self-learning-memory/
  │       ├── README.md    ("Самообучающаяся Память" на русском)
  │       ├── v1.0-lightrag.md
  │       └── CHANGELOG.md (на русском)
  │
  ├── kanon/               ← КАНОН (готово к заполнению)
  │   └── README.md
  ├── navyki/              ← НАВЫКИ
  │   └── README.md
  ├── spravochniki/        ← СПРАВОЧНИКИ
  │   └── README.md
  └── troubleshoot/        ← ПРОБЛЕМЫ
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
**Путь:** `metody/personal-ai-assistant/`  
**Версия:** v1.0-mvp-to-sales.md  
**Размер:** 767 строк, ~27KB

**О чём:**
- 4 фазы: MVP → Self-Use → Parser/Content → Client Sales
- Архитектура: Memory + Skills + MCP
- 11 принципов Алексея
- Roadmap 20+ недель
- Pricing $49-299/month

**Как читать:**

1. **Краткое описание:**
   ```
   Read C:\Users\97152\Documents\claude-library\metody\personal-ai-assistant\README.md
   ```

2. **Полная методология:**
   ```
   Read C:\Users\97152\Documents\claude-library\metody\personal-ai-assistant\v1.0-mvp-to-sales.md
   ```

3. **История версий:**
   ```
   Read C:\Users\97152\Documents\claude-library\metody\personal-ai-assistant\CHANGELOG.md
   ```

---

### 2. РУКОВОДСТВА / self-learning-memory

**Полное название:** Самообучающаяся Память (RAG)  
**Путь:** `rukovodstva/self-learning-memory/`  
**Версия:** v1.0-lightrag.md  
**Размер:** 620 строк, ~20KB

**О чём:**
- RAG архитектура
- LightRAG integration (уже на Aeza)
- Attribution (КТО/КОГДА/ГДЕ)
- Learning loop
- Use cases

**Как читать:**

1. **Краткое описание:**
   ```
   Read C:\Users\97152\Documents\claude-library\rukovodstva\self-learning-memory\README.md
   ```

2. **Полное руководство:**
   ```
   Read C:\Users\97152\Documents\claude-library\rukovodstva\self-learning-memory\v1.0-lightrag.md
   ```

3. **История версий:**
   ```
   Read C:\Users\97152\Documents\claude-library\rukovodstva\self-learning-memory\CHANGELOG.md
   ```

---

## 🚀 Быстрый старт

### Новому Claude чату:

**Шаг 1 - Прочитай index:**
```
Read C:\Users\97152\Documents\claude-library\_INDEX.md
```

**Шаг 2 - Посмотри категорию:**
```
Read C:\Users\97152\Documents\claude-library\metody\README.md
```

**Шаг 3 - Выбери тему:**
```
Read C:\Users\97152\Documents\claude-library\metody\personal-ai-assistant\README.md
```

**Шаг 4 - Читай контент:**
```
Read C:\Users\97152\Documents\claude-library\metody\personal-ai-assistant\v1.0-mvp-to-sales.md
```

---

## 🔄 Workflow обновлений

### Добавить новую версию:

1. Создай файл:
   ```bash
   cp v1.0-old.md v1.1-new-feature.md
   ```

2. Обнови CHANGELOG.md (на русском)

3. Обнови README.md темы (строка "Версия:")

4. Обнови этот _INDEX.md если нужно

### Добавить новую тему:

1. Создай папку:
   ```bash
   mkdir -p kanon/alexey-11-principles/
   ```

2. Создай файлы:
   ```bash
   touch kanon/alexey-11-principles/README.md
   touch kanon/alexey-11-principles/v1.0-initial.md
   touch kanon/alexey-11-principles/CHANGELOG.md
   ```

3. Заполни README.md (на русском)

4. Обнови _INDEX.md

5. Обнови README.md категории

---

### 3. КАНОН / simplicity-first-principle

**Полное название:** Принцип "Простота Прежде Всего"  
**Путь:** `kanon/simplicity-first-principle.md`  
**Версия:** v1.0  
**Размер:** 605 строк, ~28KB

**О чём:**
- Обязательный чеклист перед ответом AI
- Decision tree простых решений
- Anti-patterns overengineering
- "Бабушка-тест" (объяснить за 30 сек)
- Реальный кейс: 2 часа → 5 минут (git push)

**Как читать:**
```
Read C:\Users\97152\Documents\claude-library\kanon\simplicity-first-principle.md
```

**Или из GitHub:**
```
Read kanon/simplicity-first-principle.md из репозитория ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY
```

---

## 📋 Roadmap

### Ближайшее (планируется):

**Канон:**
- [ ] `kanon/alexey-11-principles/` - 11 принципов с примерами
- [ ] `kanon/waymen-10-rules/` - Waymen правила продуктивности

**Навыки:**
- [ ] `navyki/gmail-check/` - Проверка почты (skill)
- [ ] `navyki/proactive-think/` - Проактивное мышление

**Справочники:**
- [ ] `spravochniki/mcp-servers-setup/` - Настройка всех MCP

**Troubleshooting:**
- [ ] `troubleshoot/lightrag-slow-queries/` - Оптимизация LightRAG

---

## 📊 Статистика

**Всего файлов:** 12  
**Всего строк:** 2398+  
**Категорий:** 6 (3 активные, 3 готовы к заполнению)  
**Тем:** 3 (personal-ai-assistant, self-learning-memory, simplicity-first-principle)  
**Версий:** 3 (все v1.0)

---

## 🔒 Доступ и безопасность

**Доступ:** Только локальная машина (Windows)  
**Permissions:** User files (C:\Users\97152\)  
**Git:** ✅ Git-friendly (транслит латиницей)  
**Backup:** Рекомендуется периодический backup в cloud

---

**Последнее обновление:** 2026-04-24  
**Создано:** librarian-v4  
**Формат:** Универсальный (Git + Человек)
