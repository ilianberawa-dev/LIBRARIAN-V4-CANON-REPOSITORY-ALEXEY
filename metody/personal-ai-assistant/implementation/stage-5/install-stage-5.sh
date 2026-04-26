#!/usr/bin/env bash
# install-stage-5.sh — idempotent installer for Stage 5 voice command worker.
# Run as root: sudo bash install-stage-5.sh

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/personal-assistant"
USER_NAME="personal-assistant"
GROUP_NAME="personal-assistant"

if [[ $EUID -ne 0 ]]; then
  echo 'install-stage-5.sh must run as root' >&2
  exit 1
fi

echo '[install-5] copying voice.mjs'
install -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0640 \
  "${SRC_DIR}/voice.mjs" "${APP_DIR}/voice.mjs"

echo '[install-5] copying skills/voice_intent.md'
install -d -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0750 "${APP_DIR}/skills"
install -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0640 \
  "${SRC_DIR}/skills/voice_intent.md" "${APP_DIR}/skills/voice_intent.md"

echo '[install-5] verifying transcribe.sh'
if [[ ! -f "${APP_DIR}/transcribe.sh" ]]; then
  if [[ -f /opt/tg-export/transcribe.sh ]]; then
    install -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0750 \
      /opt/tg-export/transcribe.sh "${APP_DIR}/transcribe.sh"
    echo '[install-5] reused /opt/tg-export/transcribe.sh'
  else
    echo 'WARN: transcribe.sh not found in /opt/personal-assistant/ or /opt/tg-export/.'
    echo 'Voice service will fail at startup until transcribe.sh exists.'
    echo 'Worker: copy a Grok STT shell wrapper that takes (file_path, language) args and prints transcript to stdout.'
  fi
fi

echo '[install-5] ensuring /tmp/pa-voice writable by personal-assistant'
install -d -o "${USER_NAME}" -g "${GROUP_NAME}" -m 0750 /tmp/pa-voice

echo '[install-5] installing systemd unit'
install -o root -g root -m 0644 \
  "${SRC_DIR}/personal-assistant-voice.service" \
  /etc/systemd/system/personal-assistant-voice.service

systemctl daemon-reload
systemctl enable personal-assistant-voice
echo '[install-5] enabled (NOT started). Verify GROK_API_KEY in .env, then:'
echo '  sudo systemctl start personal-assistant-voice'
echo '  sudo journalctl -u personal-assistant-voice -f'
