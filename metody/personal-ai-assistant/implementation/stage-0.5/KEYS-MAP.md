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
