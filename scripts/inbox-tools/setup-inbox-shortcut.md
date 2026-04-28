# Триггер 2 — ярлык inbox со счётчиком на рабочем столе

**Что это:** на рабочем столе появляется ярлык `inbox (3)` где `3` — число файлов в `inbox/`. Автоматически обновляется. Кликаешь → открывается папка. Перетаскиваешь файл на ярлык → копируется в inbox.

**Платформа:** Windows (PowerShell). Для Mac/Linux — см. раздел "Альтернативы" внизу.

---

## Шаг 1 — Запустить скрипт вручную (проверка)

Откройте PowerShell **в папке репозитория** и выполните:

```powershell
pwsh -File scripts\inbox-tools\update-inbox-shortcut.ps1 -RepoPath (Get-Location).Path
```

Результат: на рабочем столе появится ярлык `inbox.lnk` (или `inbox (N).lnk` если в inbox есть файлы).

---

## Шаг 2 — Автоматизация через Task Scheduler

Чтобы счётчик обновлялся сам каждые 10 минут:

```powershell
# ВАЖНО: замените "C:\path\to\repo" на свой путь к репо
$repoPath = "C:\path\to\repo"
$scriptPath = "$repoPath\scripts\inbox-tools\update-inbox-shortcut.ps1"

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -RepoPath `"$repoPath`""

$trigger1 = New-ScheduledTaskTrigger -AtLogOn
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 10) `
    -RepetitionDuration (New-TimeSpan -Days 365)

Register-ScheduledTask `
    -TaskName "Inbox Counter" `
    -Action $action `
    -Trigger @($trigger1, $trigger2) `
    -Description "Updates desktop inbox shortcut with file count" `
    -RunLevel Limited
```

После этого ярлык будет:
- Обновляться при входе в Windows
- Обновляться каждые 10 минут пока ты залогинен

Проверить что задача создана:
```powershell
Get-ScheduledTask -TaskName "Inbox Counter"
```

Удалить задачу (если надоест):
```powershell
Unregister-ScheduledTask -TaskName "Inbox Counter" -Confirm:$false
```

---

## Шаг 3 — Использование

- **Видишь `inbox (3)` на рабочем столе** → пора разобрать
- **Кликаешь на ярлык** → открывается папка `inbox/`
- **Перетаскиваешь файл с рабочего стола на ярлык** → файл копируется в inbox
- В чате говоришь «разбери inbox» — чат разложит по темам

---

## Альтернативы (Mac / Linux)

### Mac

Создать псевдоним папки:
```bash
ln -s /path/to/repo/inbox ~/Desktop/inbox
```

Для счётчика — bash-скрипт + launchd (по аналогии). Не приоритет, скажи если нужно.

### Linux

Аналогично через `ln -s` и cron.

---

## Если что-то сломалось

- **PowerShell ругается на ExecutionPolicy** → запусти PowerShell от админа и выполни:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
  ```
- **Скрипт не находит inbox** → проверь что папка `inbox/` существует в репо и `RepoPath` указан правильно
- **Ярлык не появляется** → запусти скрипт вручную (Шаг 1) и посмотри ошибку в выводе
