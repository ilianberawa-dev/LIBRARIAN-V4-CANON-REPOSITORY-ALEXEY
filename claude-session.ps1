# claude-session.ps1 — bootstrap env + MCP probe + start Claude Code
$sshExe = "C:\Program Files\Git\usr\bin\ssh.exe"
$keyPath = "$env:USERPROFILE\.ssh\aeza_ed25519"
$aezaHost = "root@193.233.128.21"

Write-Host "Pulling env from Aeza..." -ForegroundColor Cyan
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
Write-Host "Set $count env vars" -ForegroundColor Green

Write-Host "`nKey check:" -ForegroundColor Cyan
@('MCP_AGENT_MAIL_BEARER','ANON_KEY','SERVICE_ROLE_KEY','MCP_API_KEY','LIGHTRAG_API_KEY') | ForEach-Object {
    $v = [Environment]::GetEnvironmentVariable($_, 'Process')
    if ($v) { Write-Host "  $_`: SET ($($v.Length) chars)" -ForegroundColor Green }
    else { Write-Host "  $_`: missing" -ForegroundColor Yellow }
}

Write-Host "`nMCP probe on localhost:8765..." -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://localhost:8765/mail/health" -Headers @{"Authorization"="Bearer $env:MCP_AGENT_MAIL_BEARER"} -TimeoutSec 3 -UseBasicParsing
    Write-Host "MCP OK (status $($r.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "MCP unreachable — tunnel down?" -ForegroundColor Red
    Write-Host "Open in separate window: & `"$sshExe`" -i `$env:USERPROFILE\.ssh\aeza_ed25519 -L 8765:127.0.0.1:8765 $aezaHost" -ForegroundColor Yellow
    $a = Read-Host "Continue anyway? (y/N)"
    if ($a -ne 'y') { return }
}

Write-Host "`nStarting Claude Code with --model sonnet..." -ForegroundColor Green
claude --model sonnet
