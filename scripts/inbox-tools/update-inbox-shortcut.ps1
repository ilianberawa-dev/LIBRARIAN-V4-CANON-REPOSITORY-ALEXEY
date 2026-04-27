# Inbox Counter — обновляет ярлык на рабочем столе с числом файлов в inbox/
#
# Использование (одноразово в PowerShell):
#   pwsh -File scripts/inbox-tools/update-inbox-shortcut.ps1 -RepoPath "C:\path\to\repo"
#
# Для автоматизации — настроить Task Scheduler (см. setup-inbox-shortcut.md)

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath
)

$InboxPath = Join-Path $RepoPath "inbox"
if (-not (Test-Path $InboxPath)) {
    Write-Error "Папка inbox/ не найдена: $InboxPath"
    exit 1
}

# Считаем файлы (исключая .gitkeep и README.md)
$count = (Get-ChildItem -Path $InboxPath -File -Force | Where-Object {
    $_.Name -notin @(".gitkeep", "README.md")
}).Count

$desktop = [Environment]::GetFolderPath('Desktop')

# Удаляем все старые ярлыки "inbox*"
Get-ChildItem -Path $desktop -Filter "inbox*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force
}

# Создаём новый ярлык с актуальным числом
$shortcutName = if ($count -gt 0) { "inbox ($count).lnk" } else { "inbox.lnk" }
$shortcutPath = Join-Path $desktop $shortcutName

$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($shortcutPath)
$sc.TargetPath = $InboxPath
$sc.IconLocation = if ($count -gt 0) { "shell32.dll,167" } else { "shell32.dll,3" }
$sc.Description = "Inbox: $count файлов ждут разбора"
$sc.Save()

Write-Host "OK. Ярлык: $shortcutName ($count файлов)"
