#!/usr/bin/env bash
# Stage 3 Draft Generator installer — idempotent
set -euo pipefail

PA_DIR="/opt/personal-assistant"
PA_USER="personal-assistant"
SOURCE_DIR="${1:-/tmp/stage-3}"

[[ -d "$PA_DIR" ]] || { echo "ERROR: $PA_DIR not found, run Stage 1 first" >&2; exit 1; }
systemctl is-active --quiet personal-assistant-listener || { echo "ERROR: Stage 1 listener not active" >&2; exit 1; }
systemctl is-active --quiet personal-assistant-triage || { echo "ERROR: Stage 2 triage not active" >&2; exit 1; }
[[ -f "$SOURCE_DIR/draft_gen.mjs" ]] || { echo "ERROR: $SOURCE_DIR/draft_gen.mjs not found" >&2; exit 1; }

if ! grep -q '^ANTHROPIC_API_KEY=sk-ant' "$PA_DIR/.env" 2>/dev/null; then
  echo "ERROR: ANTHROPIC_API_KEY missing in .env" >&2
  exit 1
fi

echo "[stage-3] Copying draft_gen.mjs..."
install -o "$PA_USER" -g "$PA_USER" -m 644 "$SOURCE_DIR/draft_gen.mjs" "$PA_DIR/draft_gen.mjs"

echo "[stage-3] Copying skills/draft.md..."
install -d -o "$PA_USER" -g "$PA_USER" -m 755 "$PA_DIR/skills"
install -o "$PA_USER" -g "$PA_USER" -m 644 "$SOURCE_DIR/skills/draft.md" "$PA_DIR/skills/draft.md"

echo "[stage-3] Installing systemd unit..."
install -m 644 "$SOURCE_DIR/personal-assistant-draft-gen.service" \
  /etc/systemd/system/personal-assistant-draft-gen.service

systemctl daemon-reload
systemctl enable personal-assistant-draft-gen
systemctl restart personal-assistant-draft-gen

sleep 3
if systemctl is-active --quiet personal-assistant-draft-gen; then
  echo "[stage-3] ✓ draft generator active"
else
  echo "[stage-3] ✗ draft-gen failed to start" >&2
  journalctl -u personal-assistant-draft-gen --no-pager -l | tail -30
  exit 1
fi

echo "[stage-3] DONE. Tail: journalctl -u personal-assistant-draft-gen -f"
