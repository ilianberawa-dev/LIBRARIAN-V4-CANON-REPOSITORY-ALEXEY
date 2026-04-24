#!/usr/bin/env bash
# Personal Assistant - Stage 1 installer (Ubuntu 22.04 / Debian 12).
# Idempotent. Safe to re-run. Never overwrites an existing .env.
#
# Requires:
#   - Root (sudo).
#   - Node.js >= 20 already installed (apt Node or NodeSource).
#
# After install, see the printed "Next steps". One-time SMS auth is
# a separate manual action (auth.mjs) because it needs interactive input.

set -euo pipefail

INSTALL_DIR=/opt/personal-assistant
SERVICE_NAME=personal-assistant-listener
PA_USER=personal-assistant
STAGE1_DIR="$(cd "$(dirname "$0")" && pwd)"

say() { printf '[install] %s\n' "$*"; }
die() { printf '[install][fatal] %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "run as root (sudo)"
}

require_node20() {
  command -v node >/dev/null || die "node not found — install Node.js 20+ first"
  local major
  major=$(node -v | sed 's/^v//; s/\..*//')
  [[ "$major" -ge 20 ]] || die "node $(node -v) too old — need >= 20"
}

create_user() {
  if ! id -u "$PA_USER" >/dev/null 2>&1; then
    useradd --system --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin "$PA_USER"
    say "created system user $PA_USER"
  fi
}

create_dirs() {
  install -d -o "$PA_USER" -g "$PA_USER" -m 750 "$INSTALL_DIR"
}

copy_sources() {
  install -o "$PA_USER" -g "$PA_USER" -m 640 "$STAGE1_DIR/listener.mjs"   "$INSTALL_DIR/listener.mjs"
  install -o "$PA_USER" -g "$PA_USER" -m 640 "$STAGE1_DIR/auth.mjs"       "$INSTALL_DIR/auth.mjs"
  install -o "$PA_USER" -g "$PA_USER" -m 640 "$STAGE1_DIR/schema.sql"     "$INSTALL_DIR/schema.sql"
  install -o "$PA_USER" -g "$PA_USER" -m 640 "$STAGE1_DIR/package.json"   "$INSTALL_DIR/package.json"
  say "copied sources into $INSTALL_DIR"
}

install_deps() {
  # better-sqlite3 needs build tools on Debian/Ubuntu.
  if ! dpkg -s build-essential python3 >/dev/null 2>&1; then
    say "installing build-essential python3 (needed by better-sqlite3)"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential python3
  fi
  sudo -u "$PA_USER" -H bash -lc "cd '$INSTALL_DIR' && npm install --no-audit --no-fund --omit=dev"
  say "npm deps installed"
}

seed_env() {
  local env_file="$INSTALL_DIR/.env"
  if [[ -f "$env_file" ]]; then
    say ".env already exists — not touching"
    return
  fi
  cat > "$env_file" <<'ENV'
# Personal Assistant — Stage 1 secrets.
# chmod 600, owned by personal-assistant.
TG_API_ID=
TG_API_HASH=
TG_SESSION_STRING=
BOT_TOKEN=
CHANNEL_CHAT_ID=
ENV
  chown "$PA_USER:$PA_USER" "$env_file"
  chmod 600 "$env_file"
  say ".env created — fill in the five blanks before starting the service"
}

install_service() {
  install -m 644 "$STAGE1_DIR/$SERVICE_NAME.service" "/etc/systemd/system/$SERVICE_NAME.service"
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME.service" >/dev/null
  say "systemd unit installed and enabled"
}

print_next_steps() {
  cat <<EOF

[install] done.

Next steps (on this host, run as root unless noted):

  1. Fill in the first two secrets so auth.mjs can run:
       sudo -u $PA_USER editor $INSTALL_DIR/.env
       # set TG_API_ID and TG_API_HASH (from https://my.telegram.org)

  2. One-time SMS auth to produce TG_SESSION_STRING:
       sudo -iu $PA_USER
       cd $INSTALL_DIR
       set -a; source .env; set +a
       node auth.mjs
       # paste the phone, the Telegram code, 2FA if any.
       # Copy the printed TG_SESSION_STRING=... back into .env.

  3. Fill in the bot credentials in .env:
       BOT_TOKEN=          # from @BotFather
       CHANNEL_CHAT_ID=    # chat_id of the AI Assistant channel

  4. Start the service:
       systemctl start $SERVICE_NAME
       systemctl status $SERVICE_NAME
       journalctl -u $SERVICE_NAME -f

  5. Send yourself a test DM and verify it reaches the channel in <=3s.

Rollback:
  systemctl disable --now $SERVICE_NAME
  rm /etc/systemd/system/$SERVICE_NAME.service
  systemctl daemon-reload
  # To wipe state as well:
  #   rm -rf $INSTALL_DIR
  #   userdel $PA_USER

EOF
}

main() {
  require_root
  require_node20
  create_user
  create_dirs
  copy_sources
  install_deps
  seed_env
  install_service
  print_next_steps
}

main "$@"
