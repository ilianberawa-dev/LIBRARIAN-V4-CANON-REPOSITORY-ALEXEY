#!/bin/bash
# install-stage-8.sh — Stage 8: GOWA + wa-listener deploy
# Idempotent. Run as root on UpCloud.
set -euo pipefail

APP_DIR=/opt/personal-assistant
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_DIR=/etc/systemd/system

log() { echo "[$(date -Iseconds)] $*"; }

# --- 1. Docker ---
if ! command -v docker &>/dev/null; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
else
  log "Docker already installed: $(docker --version)"
fi

# --- 2. GOWA volume dir ---
GOWA_DATA="${APP_DIR}/gowa-data"
mkdir -p "$GOWA_DATA"
chown personal-assistant:personal-assistant "$GOWA_DATA"
chmod 0750 "$GOWA_DATA"

# --- 3. GOWA container (idempotent) ---
if docker inspect gowa &>/dev/null; then
  log "GOWA container exists — recreating with current config"
  docker stop gowa 2>/dev/null || true
  docker rm   gowa 2>/dev/null || true
fi

log "Starting GOWA container..."
docker run -d \
  --name gowa \
  --restart always \
  -p 127.0.0.1:3001:3000 \
  -v "${GOWA_DATA}:/app/storages" \
  aldinokemal2104/go-whatsapp-web-multidevice:latest \
  --webhook http://127.0.0.1:3005/webhook \
  --port 3000

log "GOWA container started"

# --- 4. wa-listener.mjs ---
install -m 0640 -o root -g personal-assistant \
  "${SRC_DIR}/wa-listener.mjs" "${APP_DIR}/wa-listener.mjs"
log "wa-listener.mjs deployed"

# --- 5. Schema migration ---
MIGRATION="${SRC_DIR}/migrations/002-add-wa-messages.sql"
if sqlite3 "${APP_DIR}/assistant.db" \
    "SELECT 1 FROM schema_version WHERE version='1.4';" 2>/dev/null | grep -q 1; then
  log "Schema 1.4 already applied — skipping migration"
else
  log "Applying schema migration 1.4..."
  sqlite3 "${APP_DIR}/assistant.db" < "$MIGRATION"
  chown personal-assistant:personal-assistant "${APP_DIR}/assistant.db"
  log "Migration applied"
fi

# --- 6. Systemd services ---
install -m 0644 "${SRC_DIR}/personal-assistant-gowa.service"        "${SERVICE_DIR}/"
install -m 0644 "${SRC_DIR}/personal-assistant-wa-listener.service" "${SERVICE_DIR}/"
systemctl daemon-reload

systemctl enable personal-assistant-gowa
systemctl enable personal-assistant-wa-listener

systemctl restart personal-assistant-gowa
sleep 2
systemctl restart personal-assistant-wa-listener

log "Services started"

# --- 7. Smoke check ---
sleep 3
for svc in personal-assistant-gowa personal-assistant-wa-listener; do
  status=$(systemctl is-active "$svc" 2>&1)
  if [ "$status" = "active" ] || [ "$status" = "activating" ]; then
    log "OK: $svc is $status"
  else
    log "WARN: $svc is $status"
    journalctl -u "$svc" -n 20 --no-pager >&2
  fi
done

log "Stage 8 install complete."
log ""
log "NEXT STEP — QR scan (run once):"
log "  docker logs gowa    # shows QR in ASCII"
log "  OR: curl http://127.0.0.1:3001/app/login"
log "Then open WhatsApp Business → Settings → Linked Devices → Link a Device"
