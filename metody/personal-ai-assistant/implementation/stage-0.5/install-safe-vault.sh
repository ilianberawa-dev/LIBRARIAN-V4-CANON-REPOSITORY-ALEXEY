#!/usr/bin/env bash
# install-safe-vault.sh — Stage 0.5 idempotent installer for systemd-creds vault.
# Run as root: sudo bash install-safe-vault.sh
#
# Creates encrypted credstore + non-secret config dir + vault helper module.
# DOES NOT touch existing .env or service unit files (that is Stage 0.6).

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo 'install-safe-vault.sh must run as root' >&2
  exit 1
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/personal-assistant"
CREDSTORE="/etc/credstore.encrypted"
CONFIG_DIR="/etc/personal-assistant"
USER_NAME="personal-assistant"
GROUP_NAME="personal-assistant"

log() { printf '[safe-vault] %s\n' "$*"; }

# 1. systemd-creds availability check
SYSTEMD_VERSION=$(systemctl --version | awk 'NR==1 {print $2}')
if (( SYSTEMD_VERSION < 250 )); then
  echo "FATAL: systemd ${SYSTEMD_VERSION} < 250, systemd-creds not available." >&2
  exit 1
fi
log "systemd ${SYSTEMD_VERSION} OK"

# 2. encrypted credstore dir (root-only)
log "ensuring ${CREDSTORE}"
install -d -o root -g root -m 0700 "${CREDSTORE}"

# 3. non-secret config dir (readable by service group)
log "ensuring ${CONFIG_DIR}"
install -d -o root -g "${GROUP_NAME}" -m 0750 "${CONFIG_DIR}"

# 4. non-secret config.env (idempotent: only create if missing)
CONFIG_ENV="${CONFIG_DIR}/config.env"
if [[ ! -f "${CONFIG_ENV}" ]]; then
  log "writing ${CONFIG_ENV} (non-secrets template)"
  cat > "${CONFIG_ENV}" <<'EOF'
# Personal AI Assistant — non-secret config (Stage 0.5).
# Secrets live in /etc/credstore.encrypted/ via systemd-creds.
# Each service unit loads via:
#   LoadCredentialEncrypted=<name>:/etc/credstore.encrypted/<name>.cred

DB_PATH=/opt/personal-assistant/assistant.db
OWNER_TG_ID=
TG_API_ID=
POLL_INTERVAL_MS=2000
TRIAGE_POLL_MS=2000
VOICE_POLL_MS=3000
VOICE_INBOX=/tmp/pa-voice
LOG_LEVEL=info
MONTHLY_BUDGET_USD=22
EOF
  chmod 0640 "${CONFIG_ENV}"
  chown root:"${GROUP_NAME}" "${CONFIG_ENV}"
else
  log "${CONFIG_ENV} exists, leaving as-is (idempotent)"
fi

# 5. install vault helper module
log "installing lib/vault.mjs"
install -d -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0750 "${APP_DIR}/lib"
install -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0640 \
  "${SRC_DIR}/lib/vault.mjs" "${APP_DIR}/lib/vault.mjs"

log 'Stage 0.5 install complete.'
log 'Next: deposit secrets from dev machine via vault-deposit.ps1'
log 'Next: Stage 0.6 — migrate services to LoadCredentialEncrypted (separate commit).'
