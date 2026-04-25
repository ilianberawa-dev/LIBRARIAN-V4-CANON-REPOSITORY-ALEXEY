#!/usr/bin/env bash
# Stage 4 installer — idempotent (bot + sender, NO TTS, live voice forward)
set -euo pipefail

PA_DIR="/opt/personal-assistant"
PA_USER="personal-assistant"
SOURCE_DIR="${1:-/tmp/stage-4}"

[[ -d "$PA_DIR" ]] || { echo "ERROR: $PA_DIR not found, run Stage 1 first" >&2; exit 1; }

systemctl is-active --quiet personal-assistant-listener || { echo "ERROR: Stage 1 listener not active" >&2; exit 1; }
systemctl is-active --quiet personal-assistant-triage || { echo "ERROR: Stage 2 triage not active" >&2; exit 1; }
systemctl is-active --quiet personal-assistant-draft-gen || { echo "ERROR: Stage 3 draft-gen not active" >&2; exit 1; }

[[ -f "$SOURCE_DIR/bot.mjs" ]] || { echo "ERROR: $SOURCE_DIR/bot.mjs not found" >&2; exit 1; }
[[ -f "$SOURCE_DIR/sender.mjs" ]] || { echo "ERROR: $SOURCE_DIR/sender.mjs not found" >&2; exit 1; }

# Schema migration (idempotent)
echo "[stage-4] Schema migration: drafts.voice_file_id..."
sudo -u "$PA_USER" sqlite3 "$PA_DIR/assistant.db" \
  "SELECT name FROM pragma_table_info('drafts') WHERE name='voice_file_id';" \
  | grep -q voice_file_id || \
  sudo -u "$PA_USER" sqlite3 "$PA_DIR/assistant.db" \
    "ALTER TABLE drafts ADD COLUMN voice_file_id TEXT;"

# Voice files directory
install -d -o "$PA_USER" -g "$PA_USER" -m 755 "$PA_DIR/voice_inbox"

echo "[stage-4] Copying bot.mjs..."
install -o "$PA_USER" -g "$PA_USER" -m 644 "$SOURCE_DIR/bot.mjs" "$PA_DIR/bot.mjs"

echo "[stage-4] Copying sender.mjs..."
install -o "$PA_USER" -g "$PA_USER" -m 644 "$SOURCE_DIR/sender.mjs" "$PA_DIR/sender.mjs"

# Install dependencies (node-telegram-bot-api for receiving callbacks/voice)
echo "[stage-4] Installing npm packages..."
cd "$PA_DIR"
sudo -u "$PA_USER" npm install node-telegram-bot-api --save --omit=dev

echo "[stage-4] Installing systemd units..."
install -m 644 "$SOURCE_DIR/personal-assistant-bot.service" /etc/systemd/system/personal-assistant-bot.service
install -m 644 "$SOURCE_DIR/personal-assistant-sender.service" /etc/systemd/system/personal-assistant-sender.service

systemctl daemon-reload
systemctl enable personal-assistant-bot personal-assistant-sender
systemctl restart personal-assistant-bot
systemctl restart personal-assistant-sender

sleep 3
for svc in personal-assistant-bot personal-assistant-sender; do
  if systemctl is-active --quiet "$svc"; then
    echo "[stage-4] ✓ $svc active"
  else
    echo "[stage-4] ✗ $svc failed" >&2
    journalctl -u "$svc" --no-pager -l | tail -30
    exit 1
  fi
done

echo "[stage-4] DONE. Tail logs:"
echo "  journalctl -u personal-assistant-bot -f"
echo "  journalctl -u personal-assistant-sender -f"
