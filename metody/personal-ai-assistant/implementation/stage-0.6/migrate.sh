#!/bin/bash
# Stage 0.6 Migration Script
# Migrates 6 services from .env to systemd-creds vault
# Canon: #5 Fail Loud - stops on any error

set -euo pipefail

STAGE_DIR="/tmp/stage-0.6-deploy"
APP_DIR="/opt/personal-assistant"
BACKUP_DIR="/opt/personal-assistant.pre-0.6.$(date +%s)"
UNITS_BACKUP="/tmp/units-pre-0.6"

log() {
  echo "[$(date -Iseconds)] $*" >&2
}

fail() {
  log "FATAL: $*"
  exit 1
}

# Verify Part 1 completed
log "Verifying Stage 0.5 infrastructure..."
[[ -d /etc/credstore.encrypted ]] || fail "/etc/credstore.encrypted/ not found"
[[ -f /etc/personal-assistant/config.env ]] || fail "/etc/personal-assistant/config.env not found"
[[ -f /opt/personal-assistant/lib/vault.mjs ]] || fail "/opt/personal-assistant/lib/vault.mjs not found"

CRED_COUNT=$(ls /etc/credstore.encrypted/*.cred 2>/dev/null | wc -l)
[[ "$CRED_COUNT" -ge 4 ]] || fail "Expected ≥4 credentials, found $CRED_COUNT"

log "Stage 0.5 verified: $CRED_COUNT credentials in vault"

# Backup application directory
log "Backing up $APP_DIR to $BACKUP_DIR..."
sudo cp -a "$APP_DIR" "$BACKUP_DIR"

# Backup systemd units
log "Backing up systemd units to $UNITS_BACKUP..."
mkdir -p "$UNITS_BACKUP"
sudo cp /etc/systemd/system/personal-assistant-*.service "$UNITS_BACKUP/"

# Deploy updated .mjs files
log "Deploying updated .mjs files..."
for f in listener triage draft_gen brief_compiler bot sender; do
  if [[ -f "$STAGE_DIR/${f}.mjs" ]]; then
    log "  Deploying ${f}.mjs"
    sudo install -o personal-assistant -g personal-assistant -m 0640 \
      "$STAGE_DIR/${f}.mjs" "$APP_DIR/${f}.mjs"
  else
    fail "Missing ${f}.mjs in $STAGE_DIR"
  fi
done

# Deploy updated service units
log "Deploying updated service units..."
for svc in listener triage draft-gen brief bot sender; do
  if [[ -f "$STAGE_DIR/personal-assistant-${svc}.service" ]]; then
    log "  Deploying personal-assistant-${svc}.service"
    sudo install -o root -g root -m 0644 \
      "$STAGE_DIR/personal-assistant-${svc}.service" \
      "/etc/systemd/system/personal-assistant-${svc}.service"
  else
    fail "Missing personal-assistant-${svc}.service in $STAGE_DIR"
  fi
done

# Reload systemd
log "Running systemctl daemon-reload..."
sudo systemctl daemon-reload

# Restart services one by one with health checks
log "Restarting services with health verification..."

for svc in listener triage draft-gen brief bot sender; do
  SERVICE_NAME="personal-assistant-${svc}"

  log "  Restarting $SERVICE_NAME..."
  sudo systemctl restart "$SERVICE_NAME" || fail "Failed to restart $SERVICE_NAME"

  sleep 5

  if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    log "  ✓ $SERVICE_NAME is active"
  else
    log "  ✗ $SERVICE_NAME failed to start"
    log "  Last 30 lines of journal:"
    sudo journalctl -u "$SERVICE_NAME" -n 30 --no-pager
    fail "$SERVICE_NAME failed to start"
  fi

  # Check for vault errors in last 10 seconds of logs
  ERRORS=$(sudo journalctl -u "$SERVICE_NAME" --since "10 seconds ago" --no-pager | \
    grep -iE 'vault_not_initialized|vault_secret_missing|missing_env|fatal' | wc -l)

  if [[ "$ERRORS" -gt 0 ]]; then
    log "  ✗ $SERVICE_NAME has vault/fatal errors in logs"
    sudo journalctl -u "$SERVICE_NAME" --since "10 seconds ago" --no-pager | \
      grep -iE 'vault_not_initialized|vault_secret_missing|missing_env|fatal'
    fail "$SERVICE_NAME has errors"
  fi

  log "  ✓ $SERVICE_NAME healthy (no vault errors)"
done

# Final check - all services running
log "Final verification - checking all services..."
ALL_ACTIVE=true
for svc in listener triage draft-gen bot sender; do
  if ! sudo systemctl is-active --quiet "personal-assistant-${svc}"; then
    log "  ✗ personal-assistant-${svc} is NOT active"
    ALL_ACTIVE=false
  else
    log "  ✓ personal-assistant-${svc} is active"
  fi
done

if [[ "$ALL_ACTIVE" != "true" ]]; then
  fail "Not all services are active"
fi

log "SUCCESS: All 6 services migrated to vault and running"
log "Backup: $BACKUP_DIR"
log "Units backup: $UNITS_BACKUP"
log ""
log "Next steps:"
log "  1. Monitor logs for 5 minutes: journalctl -u 'personal-assistant-*' -f"
log "  2. If stable, remove .env: sudo rm /opt/personal-assistant/.env"
log "  3. Archive .env to /root: sudo install -o root -g root -m 0600 /opt/personal-assistant/.env /root/.env.pre-0.6.archive.\$(date +%s)"
