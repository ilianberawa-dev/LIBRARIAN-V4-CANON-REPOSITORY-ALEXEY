#!/usr/bin/env bash
# Stage 2 Triage installer — idempotent
# Run as root on UpCloud server after Stage 1 deployed and listener active.
set -euo pipefail

PA_DIR="/opt/personal-assistant"
PA_USER="personal-assistant"
SOURCE_DIR="${1:-/tmp/stage-2}"

if [[ ! -d "$PA_DIR" ]]; then
  echo "ERROR: $PA_DIR not found. Run Stage 1 first." >&2
  exit 1
fi

if ! systemctl is-active --quiet personal-assistant-listener; then
  echo "ERROR: personal-assistant-listener not active. Stage 1 must run before Stage 2." >&2
  exit 1
fi

if [[ ! -f "$SOURCE_DIR/triage.mjs" ]]; then
  echo "ERROR: $SOURCE_DIR/triage.mjs not found. Did you git clone?" >&2
  exit 1
fi

if ! grep -q '^ANTHROPIC_API_KEY=' "$PA_DIR/.env" 2>/dev/null || \
   grep -q '^ANTHROPIC_API_KEY=$' "$PA_DIR/.env" 2>/dev/null; then
  echo "ERROR: ANTHROPIC_API_KEY missing in $PA_DIR/.env" >&2
  echo "Add line: ANTHROPIC_API_KEY=sk-ant-..." >&2
  exit 1
fi

echo "[stage-2] Copying triage.mjs..."
install -o "$PA_USER" -g "$PA_USER" -m 644 "$SOURCE_DIR/triage.mjs" "$PA_DIR/triage.mjs"

echo "[stage-2] Copying skills/triage.md..."
install -d -o "$PA_USER" -g "$PA_USER" -m 755 "$PA_DIR/skills"
install -o "$PA_USER" -g "$PA_USER" -m 644 "$SOURCE_DIR/skills/triage.md" "$PA_DIR/skills/triage.md"

echo "[stage-2] Installing @anthropic-ai/sdk..."
cd "$PA_DIR"
sudo -u "$PA_USER" npm install @anthropic-ai/sdk --save --omit=dev

echo "[stage-2] Installing systemd unit..."
install -m 644 "$SOURCE_DIR/personal-assistant-triage.service" \
  /etc/systemd/system/personal-assistant-triage.service

systemctl daemon-reload
systemctl enable personal-assistant-triage
systemctl restart personal-assistant-triage

sleep 3
if systemctl is-active --quiet personal-assistant-triage; then
  echo "[stage-2] ✓ triage worker active"
  systemctl status personal-assistant-triage --no-pager -l | head -20
else
  echo "[stage-2] ✗ triage failed to start" >&2
  journalctl -u personal-assistant-triage --no-pager -l | tail -30
  exit 1
fi

echo "[stage-2] DONE. Tail logs: journalctl -u personal-assistant-triage -f"
