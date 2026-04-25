# claude-session.ps1 — запуск Claude Code с MCP (Supabase + LightRAG)
#
# Секреты НЕ пишутся на диск. Подтягиваются с сервера по SSH
# в env текущего процесса PowerShell на время сессии.
#
# Использование:  .\scripts\claude-session.ps1

$ErrorActionPreference = "Stop"
$server = "root@193.233.128.21"

Write-Host "→ подтягиваю секреты с сервера (по SSH)..."
$envBlock = ssh $server 'grep -E "^(ANON_KEY|SERVICE_ROLE_KEY|LIGHTRAG_API_KEY|MCP_API_KEY|MCP_AGENT_MAIL_BEARER)=" /opt/realty-portal/.env'
if (-not $envBlock) { throw "не удалось получить .env с сервера" }

foreach ($line in ($envBlock -split "`n")) {
    if ($line -match '^([A-Z_]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

Write-Host "→ открываю SSH-tunnel (8000=Supabase, 9621=LightRAG, 8765=AgentMail)..."
$tunnel = Start-Process ssh -ArgumentList "-N", "-L", "8000:127.0.0.1:8000", "-L", "9621:127.0.0.1:9621", "-L", "8765:127.0.0.1:8765", $server -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2

try {
    Write-Host "→ запускаю Claude Code (Ctrl-C или /quit чтобы выйти)..."
    Set-Location "C:\work\realty-portal"
    claude
}
finally {
    Write-Host "→ закрываю tunnel..."
    if ($tunnel -and -not $tunnel.HasExited) { Stop-Process -Id $tunnel.Id -Force }

    "ANON_KEY","SERVICE_ROLE_KEY","LIGHTRAG_API_KEY","MCP_API_KEY","MCP_AGENT_MAIL_BEARER" | ForEach-Object {
        [Environment]::SetEnvironmentVariable($_, $null, "Process")
    }
}
