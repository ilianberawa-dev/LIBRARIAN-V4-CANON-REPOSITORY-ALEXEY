#!/bin/bash

# ============================================================
#  Paperclip AI — установщик (Ubuntu/Debian VPS)
#  HTTPS через Caddy (Let's Encrypt)
#  Требования: Ubuntu 22.04+, Node.js 22+, sudo без пароля
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Шапка ──────────────────────────────────────────────────

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${BOLD}   Paperclip AI — установщик${NC}"
echo -e "${BOLD}   Ubuntu/Debian VPS + Caddy HTTPS${NC}"
echo -e "${BOLD}=============================================${NC}"
echo ""

# ── 1. sudo ────────────────────────────────────────────────

sudo true || err "sudo недоступен"

# ── 2. Домен ───────────────────────────────────────────────

if [[ -n "$PC_DOMAIN" ]]; then
  DOMAIN="$PC_DOMAIN"
  info "Домен из PC_DOMAIN: $DOMAIN"
else
  echo -e "${YELLOW}[!]${NC} DNS A-запись домена должна уже указывать на IP этого сервера!"
  echo -e "    Caddy не получит TLS-сертификат без настроенного DNS."
  echo ""
  read -rp "Домен (например: app.example.com): " DOMAIN
  [[ -z "$DOMAIN" ]] && err "Домен обязателен"
fi

DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%/}"
DOMAIN=$(echo "$DOMAIN" | tr -dc 'a-zA-Z0-9.-')
[[ -z "$DOMAIN" ]] && err "Домен содержит недопустимые символы"
info "Домен: $DOMAIN"

# ── 3. IP сервера ───────────────────────────────────────────

SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
  || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
  || hostname -I | awk '{print $1}')
info "IP сервера: $SERVER_IP"

# ── 4. Чистим старые процессы ──────────────────────────────

sudo systemctl stop paperclip 2>/dev/null || true
sudo systemctl stop caddy     2>/dev/null || true
pkill -9 -f "paperclipai" 2>/dev/null || true
pkill -9 -f "tsx.*index.ts" 2>/dev/null || true
# Убиваем всё что держит порт 3100 или 54329
for port in 3100 54329; do
  PIDS=$(ss -tlnp 2>/dev/null | grep ":$port" | grep -oP 'pid=\K[0-9]+' || true)
  [[ -n "$PIDS" ]] && echo "$PIDS" | xargs kill -9 2>/dev/null || true
done
sleep 1

# ── 5. Снимаем dpkg lock ────────────────────────────────────

sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
sudo dpkg --configure -a 2>/dev/null || true

# ── 6. Зависимости ──────────────────────────────────────────

# Node.js
command -v node >/dev/null 2>&1 || err "Node.js не установлен. Установи через nvm: nvm install 22 && nvm use 22"
NODE_VER=$(node -e "console.log(parseInt(process.version.slice(1)))")
[[ "$NODE_VER" -lt 22 ]] && err "Нужен Node.js v22+. Сейчас: $(node -v). Запусти: nvm install 22 && nvm use 22"
log "Node.js $(node -v)"

# git
command -v git >/dev/null 2>&1 || err "git не установлен: sudo apt-get install -y git"

# build tools (нужны для нативных модулей)
if ! command -v g++ >/dev/null 2>&1; then
  info "Устанавливаем build tools (make, g++, python3)..."
  sudo apt-get update -qq
  sudo apt-get install -y python3 make g++ curl
fi

# pnpm
if ! command -v pnpm >/dev/null 2>&1; then
  info "Устанавливаем pnpm..."
  sudo npm install -g pnpm
fi
command -v pnpm >/dev/null 2>&1 || err "pnpm не установлен"
log "pnpm $(pnpm -v)"

# Claude Code CLI
# Paperclip использует локальный Claude Code для запуска агентов.
# ВАЖНО: после установки нужно запустить `claude` вручную и авторизоваться
#         (требуется подписка Pro или выше).
if ! command -v claude >/dev/null 2>&1 && [ ! -f "$HOME/.local/bin/claude" ]; then
  info "Устанавливаем Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
  log "Claude Code установлен"
else
  log "Claude Code уже установлен: $(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")"
fi

# Симлинк в /usr/local/bin — нужен чтобы systemd (с урезанным PATH) находил claude
CLAUDE_BIN=$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")
if [[ -f "$CLAUDE_BIN" ]] && [[ "$CLAUDE_BIN" != "/usr/local/bin/claude" ]]; then
  sudo ln -sf "$CLAUDE_BIN" /usr/local/bin/claude
  log "claude → /usr/local/bin/claude"
fi

# Caddy
if ! command -v caddy >/dev/null 2>&1; then
  info "Устанавливаем Caddy..."
  sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https 2>/dev/null || true
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y caddy
fi
CADDY_BIN=$(command -v caddy)
log "Caddy $(caddy version 2>/dev/null | head -1)"

# ── 6. Репозиторий ──────────────────────────────────────────

INSTALL_DIR="$HOME/paperclip"

if [ -d "$INSTALL_DIR/.git" ]; then
  info "Репо уже есть — обновляем..."
  cd "$INSTALL_DIR"
  git fetch origin 2>/dev/null || true
  git pull 2>/dev/null || warn "git pull не удался (продолжаем с текущей версией)"
else
  info "Клонируем Paperclip..."
  git clone https://github.com/paperclipai/paperclip.git "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi
log "Репозиторий готов ($(git rev-parse --short HEAD 2>/dev/null || echo 'unknown'))"

# ── 7. pnpm install ─────────────────────────────────────────

info "pnpm install..."
pnpm install
log "Зависимости установлены"

# ── 8. pnpm build ───────────────────────────────────────────
#
# ВАЖНО: без сборки paperclipai run запускает Vite в dev-режиме,
# который блокирует все внешние хосты (кроме localhost).
# Только при наличии ui/dist сервер переходит в static-режим.

info "pnpm build (может занять 2-5 мин)..."
pnpm build
log "Сборка готова"

# ── 9. Первичная настройка ──────────────────────────────────

PAPERCLIP_HOME="$HOME/.paperclip"
PC_CONFIG="$PAPERCLIP_HOME/instances/default/config.json"

info "Первичная настройка Paperclip (onboard)..."
pnpm paperclipai onboard
log "Onboard завершён"

# ── 10. Применяем конфиг домена ─────────────────────────────

info "Прописываем домен в конфиге..."

python3 - <<PYEOF
import json

path = "$PC_CONFIG"
with open(path) as f:
    d = json.load(f)

# Слушать на всех интерфейсах (нужно для Caddy → localhost:3100)
d['server']['host'] = '0.0.0.0'
d['server']['port'] = 3100

# Разрешить домен
existing = d['server'].get('allowedHostnames', [])
if '$DOMAIN' not in existing:
    existing.append('$DOMAIN')
d['server']['allowedHostnames'] = existing

# Публичный URL для auth (invite links, oauth redirects)
d['auth']['publicBaseUrl'] = 'https://$DOMAIN'

with open(path, 'w') as f:
    json.dump(d, f, indent=2)

print("Конфиг обновлён:")
print(f"  host:          {d['server']['host']}")
print(f"  port:          {d['server']['port']}")
print(f"  allowedHost:   {d['server']['allowedHostnames']}")
print(f"  publicBaseUrl: {d['auth']['publicBaseUrl']}")
PYEOF

log "Конфиг домена применён"

# ── 11. Systemd — Paperclip ──────────────────────────────────

info "Создаём systemd сервис paperclip..."
PNPM_BIN=$(command -v pnpm)

sudo tee /etc/systemd/system/paperclip.service > /dev/null <<EOF
[Unit]
Description=Paperclip AI Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$PNPM_BIN paperclipai run
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=NODE_ENV=production
# Без этого paperclipai run определяет что запускается из исходников
# и принудительно включает Vite dev-сервер, который блокирует внешние хосты.
# С false — используется статическая сборка из ui/dist.
Environment=PAPERCLIP_UI_DEV_MIDDLEWARE=false

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable paperclip
sudo systemctl restart paperclip

info "Ждём запуска Paperclip (15 сек)..."
sleep 15

if sudo systemctl is-active --quiet paperclip; then
  log "Paperclip запущен"
else
  warn "Paperclip не стартовал. Логи:"
  sudo journalctl -u paperclip -n 30 --no-pager 2>/dev/null || true
  err "Paperclip не поднялся — исправь ошибки выше"
fi

# ── 12. Caddy ───────────────────────────────────────────────

info "Настраиваем Caddy..."

sudo mkdir -p /etc/caddy /var/lib/caddy
sudo chown -R caddy:caddy /var/lib/caddy 2>/dev/null || true

sudo tee /etc/caddy/Caddyfile > /dev/null <<CADDYEOF
$DOMAIN {
    reverse_proxy localhost:3100
}
CADDYEOF

if ! sudo "$CADDY_BIN" validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>/dev/null; then
  warn "Caddyfile невалиден:"
  sudo cat /etc/caddy/Caddyfile
  err "Ошибка в Caddyfile"
fi
log "Caddyfile OK"

sudo systemctl enable caddy
sudo systemctl restart caddy
sleep 3

if sudo systemctl is-active --quiet caddy; then
  log "Caddy запущен"
else
  warn "Caddy не стартовал. Логи:"
  sudo journalctl -u caddy -n 20 --no-pager 2>/dev/null || true
  err "Caddy не поднялся"
fi

# ── 13. Firewall ─────────────────────────────────────────────

for port in 80 443; do
  if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow "$port/tcp" >/dev/null 2>&1 || true
  fi
  sudo iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
    || sudo iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
done
log "Firewall: открыты порты 80 и 443"

# ── 14. Invite URL ────────────────────────────────────────────

INVITE_URL=$(sudo journalctl -u paperclip -n 100 --no-pager 2>/dev/null \
  | grep "Invite URL" | tail -1 | grep -oP 'https://[^ ]+' || echo "")

# ── 16. Итог ─────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}${BOLD}✅ Paperclip AI установлен!${NC}"
echo ""
echo -e "  Панель:   ${CYAN}https://$DOMAIN${NC}"
echo ""

if [[ -n "$INVITE_URL" ]]; then
  echo -e "  ${BOLD}CEO Invite:${NC}"
  echo -e "    ${CYAN}$INVITE_URL${NC}"
  echo -e "    ${YELLOW}(действует 3 дня — создай аккаунт сейчас)${NC}"
  echo ""
fi

echo -e "  ${YELLOW}${BOLD}⚠  Обязательно после установки:${NC}"
echo -e "  1. Запусти Claude Code и авторизуйся:"
echo -e "     ${CYAN}claude${NC}"
echo -e "     ${YELLOW}(нужна подписка Pro или выше)${NC}"
echo -e "  2. Проверь что claude доступен из systemd:"
echo -e "     ${CYAN}sudo -u $USER /usr/local/bin/claude --version${NC}"
echo -e "  3. Перезапусти Paperclip после авторизации:"
echo -e "     ${CYAN}sudo systemctl restart paperclip${NC}"
echo ""
echo -e "  ${BOLD}Конфиг:${NC}   $PC_CONFIG"
echo -e "  ${BOLD}Логи:${NC}     journalctl -u paperclip -f"
echo -e "  ${BOLD}Рестарт:${NC}  sudo systemctl restart paperclip"
echo ""
echo -e "  ${YELLOW}${BOLD}После регистрации — закрыть регу:${NC}"
echo "    python3 -c \""
echo "    import json; path='$PC_CONFIG'"
echo "    d=json.load(open(path)); d['auth']['disableSignUp']=True"
echo "    json.dump(d, open(path,'w'), indent=2)"
echo "    \""
echo "    sudo systemctl restart paperclip"
echo ""
echo -e "  ${BOLD}Обновление:${NC}"
echo "    cd $INSTALL_DIR"
echo "    git pull"
echo "    pnpm install"
echo "    pnpm build"
echo "    sudo systemctl restart paperclip"
echo ""
echo -e "  ${BOLD}Удаление:${NC}"
echo "    sudo systemctl stop paperclip caddy"
echo "    sudo systemctl disable paperclip caddy"
echo "    sudo rm -f /etc/systemd/system/paperclip.service /etc/caddy/Caddyfile"
echo "    sudo systemctl daemon-reload"
echo "    rm -rf $INSTALL_DIR $PAPERCLIP_HOME"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
