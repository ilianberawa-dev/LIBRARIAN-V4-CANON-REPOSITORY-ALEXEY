# vault-deposit.ps1 — Personal AI Assistant Stage 0.5 vault tool.
# Deposit or rotate ONE secret into /etc/credstore.encrypted on UpCloud server.
#
# Usage:
#   .\vault-deposit.ps1 -KeyName anthropic-api-key
#   .\vault-deposit.ps1 -KeyName xai-api-key -RestartService personal-assistant-triage
#   .\vault-deposit.ps1 -KeyName bot-token -Server upcloud
#
# Behavior:
#   - Reads the secret via Read-Host -AsSecureString (RAM only, no shell history).
#   - Pipes plaintext over SSH to systemd-creds encrypt; the .cred file is
#     readable only by root, encryption tied to host key (TPM-backed if avail).
#   - Overwrites if exists (single-key rotation).
#   - Optionally restarts ONE systemd unit afterward.
#   - Clears the variable + GC ensures the secret is not persisted on Windows.

param(
    [Parameter(Mandatory = $true)]
    [string]$KeyName,

    [Parameter(Mandatory = $false)]
    [string]$Server = 'upcloud',

    [Parameter(Mandatory = $false)]
    [string]$RestartService = $null
)

$ErrorActionPreference = 'Stop'

if ($KeyName -notmatch '^[a-z0-9][a-z0-9_-]*$') {
    Write-Error "KeyName must be lowercase alphanumeric, dashes/underscores only. Got: $KeyName"
    exit 1
}

Write-Host "Depositing secret '$KeyName' into ${Server}:/etc/credstore.encrypted/" -ForegroundColor Cyan
$secure = Read-Host -Prompt "Paste secret value for '$KeyName'" -AsSecureString

$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if ([string]::IsNullOrWhiteSpace($plain)) {
    Write-Error 'Secret value is empty. Aborting.'
    exit 1
}

$remoteCmd = "sudo install -d -o root -g root -m 0700 /etc/credstore.encrypted && " +
             "sudo systemd-creds encrypt --name=$KeyName - /etc/credstore.encrypted/$KeyName.cred && " +
             "sudo chmod 0600 /etc/credstore.encrypted/$KeyName.cred && " +
             "sudo chown root:root /etc/credstore.encrypted/$KeyName.cred && " +
             "echo OK_DEPOSITED"

# Pipe plain via stdin to ssh — avoids -EncodedCommand history leak.
$plain | ssh $Server $remoteCmd
$sshExit = $LASTEXITCODE

# Hard-clear plaintext from memory.
Clear-Variable -Name plain -ErrorAction SilentlyContinue
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

if ($sshExit -ne 0) {
    Write-Error "SSH command failed (exit $sshExit). Secret NOT deposited."
    exit $sshExit
}

Write-Host "Secret '$KeyName' deposited / rotated." -ForegroundColor Green

if ($RestartService) {
    if ($RestartService -notmatch '^personal-assistant-[a-z0-9-]+$') {
        Write-Warning "RestartService '$RestartService' does not look like a personal-assistant unit. Skipping restart."
    } else {
        Write-Host "Restarting $RestartService on $Server..." -ForegroundColor Cyan
        ssh $Server "sudo systemctl restart $RestartService && sudo systemctl is-active $RestartService"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Restart command did not return active state. Check journalctl -u $RestartService."
        } else {
            Write-Host "$RestartService active." -ForegroundColor Green
        }
    }
}
