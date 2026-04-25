#!/usr/bin/env bash
# install-stage-3.5.sh — idempotent installer for Stage 3.5 brief compiler.
# Run as root: sudo bash install-stage-3.5.sh

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/personal-assistant"
USER_NAME="personal-assistant"
GROUP_NAME="personal-assistant"

if [[ $EUID -ne 0 ]]; then
  echo 'install-stage-3.5.sh must run as root' >&2
  exit 1
fi

echo '[install-3.5] copying brief_compiler.mjs'
install -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0640 \
  "${SRC_DIR}/brief_compiler.mjs" "${APP_DIR}/brief_compiler.mjs"

echo '[install-3.5] copying skills/brief.md'
install -d -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0750 "${APP_DIR}/skills"
install -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0640 \
  "${SRC_DIR}/skills/brief.md" "${APP_DIR}/skills/brief.md"

echo '[install-3.5] installing systemd service + timer'
install -o root -g root -m 0644 \
  "${SRC_DIR}/personal-assistant-brief.service" \
  /etc/systemd/system/personal-assistant-brief.service
install -o root -g root -m 0644 \
  "${SRC_DIR}/personal-assistant-brief.timer" \
  /etc/systemd/system/personal-assistant-brief.timer

systemctl daemon-reload
systemctl enable --now personal-assistant-brief.timer

echo '[install-3.5] done. timer status:'
systemctl list-timers personal-assistant-brief.timer --no-pager | head -5
