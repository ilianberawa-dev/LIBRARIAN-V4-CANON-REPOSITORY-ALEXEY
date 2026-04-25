# mesh-boot.ps1 — автоматический запуск всех 4 ролей в Windows Terminal
# Usage: .\mesh-boot.ps1

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Realty Portal — Mesh Boot" -ForegroundColor Cyan
Write-Host "  Запуск 4 ролей в Windows Terminal" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Проверка что мы в правильной директории
$currentPath = (Get-Location).Path
if ($currentPath -notlike "*realty-portal*") {
    Write-Host "⚠ Warning: не в директории realty-portal" -ForegroundColor Yellow
    Write-Host "Текущий путь: $currentPath" -ForegroundColor Yellow
    $continue = Read-Host "Продолжить? (y/N)"
    if ($continue -ne "y") {
        exit 0
    }
}

# Роли для запуска (в порядке startup_order)
$roles = @(
    @{
        name = "librarian-v4"
        emoji = "📘"
        color = "#4A90E2"
        model = "opus"
    },
    @{
        name = "school-v4"
        emoji = "🎓"
        color = "#E24A90"
        model = "opus"
    },
    @{
        name = "parser-rumah123-v4"
        emoji = "🔍"
        color = "#50C878"
        model = "sonnet"
    },
    @{
        name = "ai-helper-v3"
        emoji = "🤖"
        color = "#FFB347"
        model = "sonnet"
    }
)

Write-Host "→ Запускаю роли:" -ForegroundColor Green
foreach ($role in $roles) {
    Write-Host "  $($role.emoji) $($role.name) ($($role.model))" -ForegroundColor White
}
Write-Host ""

# Строим команду для Windows Terminal
# Формат: wt -w 0 new-tab --title "..." --tabColor "#..." -d "C:\..." powershell -NoExit -Command "..."

$wtCommand = "wt -w 0"

$isFirst = $true
foreach ($role in $roles) {
    $title = "$($role.emoji) $($role.name)"
    $color = $role.color
    $workDir = "C:\work\realty-portal"
    $startScript = ".\scripts\start-role.ps1 $($role.name)"

    if ($isFirst) {
        # Первый таб — заменяет текущий
        $wtCommand += " new-tab --title `"$title`" --tabColor `"$color`" -d `"$workDir`" powershell -NoExit -Command `"$startScript`""
        $isFirst = $false
    } else {
        # Остальные табы — добавляются
        $wtCommand += " ; new-tab --title `"$title`" --tabColor `"$color`" -d `"$workDir`" powershell -NoExit -Command `"$startScript`""
    }
}

Write-Host "→ Команда Windows Terminal:" -ForegroundColor Yellow
Write-Host $wtCommand -ForegroundColor DarkGray
Write-Host ""

# Запуск
Write-Host "→ Открываю Windows Terminal с 4 ролями..." -ForegroundColor Green
try {
    Invoke-Expression $wtCommand
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✓ Mesh запущен!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Открыто 4 таба в Windows Terminal:" -ForegroundColor White
    Write-Host ""
    Write-Host "  Tab 1: 📘 librarian-v4 (infra lead, Opus)" -ForegroundColor Cyan
    Write-Host "  Tab 2: 🎓 school-v4 (orchestrator, Opus)" -ForegroundColor Magenta
    Write-Host "  Tab 3: 🔍 parser-rumah123-v4 (scraping, Sonnet)" -ForegroundColor Green
    Write-Host "  Tab 4: 🤖 ai-helper-v3 (generic, Sonnet)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Переключение: Ctrl+Tab или клик на таб" -ForegroundColor White
    Write-Host ""
    Write-Host "В каждом табе скажи Claude:" -ForegroundColor White
    Write-Host "  'Выполни bootstrap sequence из инструкций'" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "После bootstrap ролей - они готовы к работе!" -ForegroundColor Green
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "✗ Ошибка при запуске:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Fallback: запусти роли вручную:" -ForegroundColor Yellow
    Write-Host "  .\start-librarian.ps1" -ForegroundColor DarkGray
    Write-Host "  .\start-school.ps1" -ForegroundColor DarkGray
    Write-Host "  .\start-parser.ps1" -ForegroundColor DarkGray
    Write-Host "  .\start-ai-helper.ps1" -ForegroundColor DarkGray
    exit 1
}
