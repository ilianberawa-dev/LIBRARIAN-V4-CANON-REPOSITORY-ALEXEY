# start-role.ps1 — универсальный launcher для mesh ролей
# Usage: .\scripts\start-role.ps1 librarian-v4
# Usage: .\scripts\start-role.ps1 school-v4

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("librarian-v4", "school-v4", "parser-rumah123-v4", "ai-helper-v3")]
    [string]$RoleName
)

$ErrorActionPreference = "Stop"

# Читаем agents.yaml для получения конфига роли
$agentsYaml = Get-Content "C:\work\realty-portal\agents.yaml" -Raw
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Installing powershell-yaml module..." -ForegroundColor Yellow
    Install-Module powershell-yaml -Force -Scope CurrentUser -Confirm:$false
}
Import-Module powershell-yaml
$config = (ConvertFrom-Yaml $agentsYaml).agents[$RoleName]

if (-not $config) {
    Write-Error "Role $RoleName not found in agents.yaml"
    exit 1
}

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Starting: $($config.window_title)" -ForegroundColor Cyan
Write-Host "  Model: $($config.model)" -ForegroundColor Cyan
Write-Host "  CWD: $($config.working_directory)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

# 1. Pull env vars from Aeza
$sshExe = "C:\Program Files\Git\usr\bin\ssh.exe"
$keyPath = "$env:USERPROFILE\.ssh\aeza_ed25519"
$aezaHost = "root@193.233.128.21"

Write-Host "`n→ Pulling env from Aeza..." -ForegroundColor Yellow
$envFiles = @("/opt/mcp_agent_mail/.env", "/opt/realty-portal/.env")
$count = 0
foreach ($f in $envFiles) {
    $content = & $sshExe -i $keyPath -o StrictHostKeyChecking=no $aezaHost "cat $f 2>/dev/null"
    foreach ($line in $content) {
        if ($line -match "^([A-Z_][A-Z0-9_]*)=(.*)$") {
            $name = $matches[1]
            $value = $matches[2] -replace '^"|"$', ''
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
            $count++
        }
    }
}
Write-Host "✓ Set $count env vars" -ForegroundColor Green

# 2. Verify key env vars
Write-Host "`n→ Key check:" -ForegroundColor Yellow
$keyVars = @('MCP_AGENT_MAIL_BEARER','ANON_KEY','SERVICE_ROLE_KEY','MCP_API_KEY','LIGHTRAG_API_KEY')
$allSet = $true
foreach ($var in $keyVars) {
    $v = [Environment]::GetEnvironmentVariable($var, 'Process')
    if ($v) {
        Write-Host "  ✓ $var (${($v.Length)} chars)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $var MISSING" -ForegroundColor Red
        $allSet = $false
    }
}

if (-not $allSet) {
    Write-Error "Some env vars missing. Check Aeza server .env files."
    exit 1
}

# 3. Set role-specific env var
[Environment]::SetEnvironmentVariable("CLAUDE_ROLE", $RoleName, 'Process')

# 4. Change to working directory
Set-Location $config.working_directory

# 5. Show bootstrap instructions
Write-Host "`n═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Bootstrap instructions:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ты — $RoleName" -ForegroundColor Green
Write-Host ""
Write-Host "1. Прочитай $($config.launcher_file) для контекста предыдущей версии"
Write-Host "2. Выполни MCP bootstrap sequence:"
Write-Host "   - health_check"
Write-Host "   - ensure_project(project_key='/opt/realty-portal/docs/school')"
Write-Host "   - register_agent(name='$RoleName', ...)"
Write-Host "   - request_contact с librarian-v4 и school-v4"
Write-Host "   - send presence ping в thread 'presence'"
Write-Host "3. После bootstrap скажи: 'Bootstrap complete, ready for work'"
Write-Host ""
Write-Host "Responsibilities:" -ForegroundColor Yellow
foreach ($resp in $config.responsibilities) {
    Write-Host "  - $resp"
}
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

# 6. Start Claude Code
$modelFlag = switch ($config.model) {
    "claude-opus-4-7" { "opus" }
    "claude-sonnet-4-6" { "sonnet" }
    default { "sonnet" }
}

Write-Host "`n→ Starting Claude Code (model: $modelFlag)..." -ForegroundColor Green
Write-Host ""

claude --model $modelFlag
