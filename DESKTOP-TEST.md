# Тест доступа из Claude Desktop

Скопируй эту команду в свой Claude Desktop чат:

```
Read C:\Users\97152\Documents\claude-library\_INDEX.md
```

Если увидишь содержимое файла - доступ работает ✅

Затем выполни быструю проверку:

```
Read C:\Users\97152\Documents\claude-library\QUICK-CHECK.md

Выполни все 5 шагов из этого файла и верни краткий результат.
```

---

Если получишь ошибку "file not found" - значит Desktop тоже в sandbox и нужно добавить путь в settings.
