#!/usr/bin/env bash
# install.sh — idempotent installer for Personal AI Assistant Stage 1.
# Run as root: sudo bash install.sh
# Source files expected in the same directory as this script.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/personal-assistant"
LOG_DIR="/var/log/personal-assistant"
USER_NAME="personal-assistant"
GROUP_NAME="personal-assistant"
ENV_FILE="${APP_DIR}/.env"
SYSTEMD_UNIT="/etc/systemd/system/personal-assistant-listener.service"

log() { printf '[install] %s\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo 'install.sh must run as root' >&2
  exit 1
 fi

log 'creating system user (idempotent)'
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "${APP_DIR}" --shell /usr/sbin/nologin "${USER_NAME}"
else
  log 'user already exists, skipping useradd'
fi

log 'creating directories'
install -d -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0750 "${APP_DIR}"
install -d -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0750 "${LOG_DIR}"

log 'copying source files'
for f in listener.mjs auth.mjs schema.sql package.json; do
  if [[ -f "${SRC_DIR}/${f}" ]]; then
    install -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0640 "${SRC_DIR}/${f}" "${APP_DIR}/${f}"
  else
    echo "missing source file: ${SRC_DIR}/${f}" >&2
    exit 1
  fi
done

log 'preparing .env skeleton (chmod 600)'
if [[ ! -f "${ENV_FILE}" ]]; then
  cat > "${ENV_FILE}" <<'EOF'
# Personal AI Assistant — single secret vault (Canon #6).
# Stage 1 fills: TG_API_ID, TG_API_HASH, TG_SESSION_STRING, BOT_TOKEN,
#                CHANNEL_CHAT_ID, PHONE, HCPING_URL.
# Stage 2-3 fills: ANTHROPIC_API_KEY.

TG_API_ID=
TG_API_HASH=
TG_SESSION_STRING=
BOT_TOKEN=
CHANNEL_CHAT_ID=
PHONE=
HCPING_URL=
ANTHROPIC_API_KEY=
DB_PATH=/opt/personal-assistant/assistant.db
EOF
fi
chown "${USER_NAME}:${GROUP_NAME}" "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

log 'installing systemd unit'
install -o root -g root -m 0644 "${SRC_DIR}/personal-assistant-listener.service" "${SYSTEMD_UNIT}"
systemctl daemon-reload
systemctl enable personal-assistant-listener.service >/dev/null

log 'install.sh complete'
log 'next steps:'
log '  1. fill /opt/personal-assistant/.env with TG_API_ID + TG_API_HASH'
log "  2. sudo -iu ${USER_NAME} -- bash -lc 'cd ${APP_DIR} && npm install --omit=dev'"
log "  3. sudo -iu ${USER_NAME} -- bash -lc 'cd ${APP_DIR} && set -a; source .env; set +a; node auth.mjs'"
log '  4. append TG_SESSION_STRING + remaining vars to .env'
log "  5. sudo -u ${USER_NAME} sqlite3 ${APP_DIR}/assistant.db < ${APP_DIR}/schema.sql"
log '  6. sudo systemctl start personal-assistant-listener'
log '  7. sudo journalctl -u personal-assistant-listener -f'
