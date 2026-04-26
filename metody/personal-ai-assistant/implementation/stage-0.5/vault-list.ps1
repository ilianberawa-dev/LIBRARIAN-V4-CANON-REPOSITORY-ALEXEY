# vault-list.ps1 — list deposited secrets on remote server. NEVER reads content.
#
# Usage: .\vault-list.ps1                 # default server alias 'upcloud'
#        .\vault-list.ps1 -Server upcloud2

param(
    [Parameter(Mandatory = $false)]
    [string]$Server = 'upcloud'
)

Write-Host "Vault inventory on ${Server}:/etc/credstore.encrypted/" -ForegroundColor Cyan
ssh $Server "sudo ls -lh /etc/credstore.encrypted/ 2>/dev/null || echo '(empty or missing)'"
