# Personal AI Assistant — Vault Keys Map (Stage 0.5)

Per-service inventory of credstore keys required via
`LoadCredentialEncrypted=<name>:/etc/credstore.encrypted/<name>.cred`
in each systemd unit.

Stage 0.5 only creates the vault. Stage 0.6 migrates services to load
from credstore (separate commit).

## Service → Required Keys

| Service                          | Keys (LoadCredentialEncrypted)                    |
|----------------------------------|---------------------------------------------------|
| personal-assistant-listener      | tg-api-hash, tg-session-string                    |
| personal-assistant-triage        | anthropic-api-key                                 |
| personal-assistant-draft-gen     | anthropic-api-key                                 |
| personal-assistant-brief         | anthropic-api-key                                 |
| personal-assistant-bot           | bot-token, anthropic-api-key                      |
| personal-assistant-sender        | bot-token, tg-api-hash, tg-session-string         |
| personal-assistant-voice (S5)    | xai-api-key, anthropic-api-key                    |

Non-secret config (`TG_API_ID`, `OWNER_TG_ID`, polling intervals, paths)
lives in `/etc/personal-assistant/config.env` loaded via `EnvironmentFile=`
in each unit.

## Recipes

### Deposit / rotate ONE key

Rotate Anthropic key across all services that use it (only the 4 in the
table below):

```powershell
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-triage
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-draft-gen
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-brief
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-bot
```

Do NOT restart services that do not use the rotated key.

### Rotate everything (full sweep)

`.\vault-rotate-all.ps1` (provided in Stage 0.6+) walks the table and
prompts each key in order.

### Replace Telegram account (new number / new session)

```powershell
.\vault-deposit.ps1 -KeyName tg-session-string -RestartService personal-assistant-listener
.\vault-deposit.ps1 -KeyName tg-session-string -RestartService personal-assistant-sender
```

`tg-api-hash` is per-app, not per-account — leave as is unless you also
rotated `API_ID`/`API_HASH` on my.telegram.org.

### Inventory check

```powershell
.\vault-list.ps1
```

## Security guarantees (systemd-creds)

- `/etc/credstore.encrypted/<name>.cred` encrypted with host key
  (TPM-backed if available, else system seed).
- Decryption only happens when systemd starts a service unit with
  `LoadCredentialEncrypted=` for that file.
- Plaintext exists ONLY at `$CREDENTIALS_DIRECTORY/<name>` for the
  process lifetime, in tmpfs, readable only by service user.
- A backup of `/etc/credstore.encrypted/` to a different host is useless
  without the source host key.

### Before Stage 0.5 (old .env approach):
- ❌ Secrets in `/opt/personal-assistant/.env` (640 personal-assistant:personal-assistant)
- ❌ Any process as `personal-assistant` user can read ALL secrets
- ❌ Accidental `git add .env` risk
- ❌ Logs may leak secrets (no redaction)

### After Stage 0.5 (vault approach):
- ✅ Secrets in `/etc/credstore.encrypted/` (600 root:root, host-key encrypted)
- ✅ Each service sees ONLY its own credentials via `$CREDENTIALS_DIRECTORY`
- ✅ Rotation via PowerShell (key never touches Windows disk or SSH logs)
- ✅ `vault.redact()` strips secrets from logs
- ✅ Privilege isolation (Canon #11): listener can't see bot-token, bot can't see tg-session-string

---

## Troubleshooting

### `vault_not_initialized` fatal error

**Symptom:** Service fails with JSON log `{"level":"fatal","msg":"vault_not_initialized"}`

**Cause:** Service started without `LoadCredentialEncrypted` in unit file.

**Fix:**
```bash
# Add to service unit (example):
[Service]
LoadCredentialEncrypted=anthropic-api-key:/etc/credstore.encrypted/anthropic-api-key.cred

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart personal-assistant-triage
```

### `credential_missing` error

**Symptom:** Service fails with JSON log `{"level":"fatal","msg":"credential_missing","name":"..."}`

**Cause:** Service expects a credential that doesn't exist in vault.

**Fix:**
```powershell
# Deposit the missing credential
.\vault-deposit.ps1 -KeyName <missing-key-name> -RestartService <service-name>
```

### Encrypted file corrupt / wrong format

**Symptom:** systemd logs `Failed to decrypt credential` or service can't read `$CREDENTIALS_DIRECTORY/<name>`

**Cause:** Manual editing of `.cred` files or systemd version mismatch.

**Fix:**
```powershell
# Re-deposit the credential (overwrites corrupted file)
.\vault-deposit.ps1 -KeyName <key-name>
```

---

## Migration Checklist (Stage 0.6)

**DO NOT do this in Stage 0.5** — infrastructure only.

Stage 0.6 will migrate existing services from `.env` to vault:

- [ ] Add `LoadCredentialEncrypted` directives to each `.service` file (per table above)
- [ ] Add `EnvironmentFile=/etc/personal-assistant/config.env` to units
- [ ] Rewrite `listener.mjs`, `triage.mjs`, etc. to use `import { getSecret } from './lib/vault.mjs'`
- [ ] Remove `EnvironmentFile=/opt/personal-assistant/.env` from units
- [ ] Backup `/opt/personal-assistant/.env` to `/root/.env.backup.stage0.6`
- [ ] Delete `/opt/personal-assistant/.env` (secrets now in vault)
- [ ] Deposit all 5 credentials using `vault-deposit.ps1`
- [ ] Test each service restarts cleanly
- [ ] Verify no secrets in logs via `journalctl | grep -E 'sk-ant-|xai-|[0-9]{10}:[a-zA-Z]'`
- [ ] Commit migration

---

## Operational Examples

### Audit vault + verify service access

```powershell
# List vault contents (metadata only)
.\vault-list.ps1

# On server, test if triage can decrypt its key
ssh upcloud "sudo systemd-run --unit=test-vault \
  --property=LoadCredentialEncrypted=anthropic-api-key:/etc/credstore.encrypted/anthropic-api-key.cred \
  --property=User=personal-assistant \
  --wait \
  bash -c 'cat \$CREDENTIALS_DIRECTORY/anthropic-api-key | head -c 20 && echo ...'"
# Should print first 20 chars of key + "..." (proving decryption works)
```

### Emergency key rotation (leaked key)

```powershell
# 1. Revoke old key at provider (anthropic.com/account)
# 2. Generate new key
# 3. Rotate vault + restart affected services
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-triage
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-draft-gen
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-brief
.\vault-deposit.ps1 -KeyName anthropic-api-key -RestartService personal-assistant-bot

# 4. Verify services started successfully
ssh upcloud "systemctl status personal-assistant-{triage,draft-gen,brief,bot} --no-pager"
```
