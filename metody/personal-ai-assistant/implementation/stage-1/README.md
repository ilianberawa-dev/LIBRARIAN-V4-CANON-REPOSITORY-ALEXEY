# Personal Assistant — Stage 1: Listener Live

**Status:** implementation ready. Not yet deployed on Aeza.
**Target host:** `root@193.233.128.21`, path `/opt/personal-assistant/`.
**Mission:** `PA-STAGE-1-LISTENER-LIVE`.

## What this stage delivers

An MTProto listener running as a system service on Aeza that:

1. Receives every incoming **private DM** sent to the operator's personal
   Telegram account via a gramjs `NewMessage` handler.
2. Upserts the sender into `contacts`, inserts the message into `messages`
   (and thus `messages_fts`) in `assistant.db`.
3. Forwards a short one-line summary to the **AI Assistant channel** via the
   Telegram Bot API, format `📩 HH:MM от <Name>: <text>`.

Everything else — classification, drafts, LLM calls, voice, inline buttons,
heartbeat/budget — is **out of scope** and deferred to Stage 2-6.

## Files in this directory

| File | Purpose |
|---|---|
| `listener.mjs` | Main process. gramjs client, NewMessage handler, SQLite writes, Bot API forward. |
| `schema.sql` | SQLite schema v1: `contacts`, `messages`, `messages_fts` (active) + `drafts`, `rules`, `voice_samples`, `budget_log` (scaffolds for later stages). Idempotent. |
| `auth.mjs` | One-time helper to obtain `TG_SESSION_STRING` via SMS / 2FA. |
| `package.json` | Three deps only: `telegram`, `better-sqlite3`, `dotenv`. |
| `personal-assistant-listener.service` | systemd unit. `User=personal-assistant`, `Restart=always`, `ProtectSystem=strict`, `ReadWritePaths=/opt/personal-assistant`. |
| `install.sh` | Idempotent installer for Ubuntu 22.04 / Debian 12. Creates user, copies sources, installs deps, seeds `.env`, installs and enables the unit. Does **not** overwrite an existing `.env`. |
| `HANDOFF.json` | Execution report for the architect and Stage 2 successor. |

## Canon alignment

- **#0 Simplicity-First.** Three npm deps. No Docker. No Redis. Logs → journald.
  Schema applied by the listener on startup, so no sqlite3 CLI needed on host.
- **#1 Portability.** Clone repo → `sudo bash install.sh` → fill `.env` → run
  `auth.mjs` → `systemctl start`. Works on a fresh Ubuntu 22.04.
- **#2 Minimal integration.** gramjs as-is for MTProto; plain `fetch` to the
  Bot API. No custom wire-level code.
- **#6 Single secret vault.** All secrets in `/opt/personal-assistant/.env`
  (chmod 600). Zero fallbacks in code — missing env aborts with a loud error.
- **#11 Privilege isolation.** Dedicated `personal-assistant` system user,
  `nologin` shell. systemd hardening restricts the process to writing only
  `/opt/personal-assistant`. The listener has no generic SQL or Bot API
  tool — only the three prepared statements and `forwardToChannel`. A prompt
  injection in a DM cannot `DROP TABLE` or post elsewhere.

## Prerequisites (operator checklist)

Blockers that must be resolved before the service will start:

1. **SSH as root/sudo to `193.233.128.21`.**
2. **Node.js >= 20** installed on the host (`node -v`). If Aeza has an older
   Node, upgrade via NodeSource before running the installer:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```
3. **Telegram API credentials** from <https://my.telegram.org>:
   `TG_API_ID`, `TG_API_HASH`.
4. **Bot token** from @BotFather (`TG_BOT_TOKEN`).
5. **Channel chat_id** of the AI Assistant channel. Create the channel, add
   the bot as admin, then `chat_id` is returned by e.g.
   `curl https://api.telegram.org/bot<BOT_TOKEN>/getUpdates` after posting
   anything in the channel.
6. **A personal Telegram account** that receives the DMs you want to forward.

No Anthropic key, no VIP list, no healthcheck URL — those belong to Stage 2+.

## Deployment

On Aeza:

```bash
# 1. Clone this repo somewhere (your home is fine — install.sh copies out).
git clone https://github.com/ilianberawa-dev/LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY.git
cd LIBRARIAN-V4-CANON-REPOSITORY-ALEXEY/metody/personal-ai-assistant/implementation/stage-1

# 2. Install.
sudo bash install.sh

# 3. Put TG_API_ID and TG_API_HASH into .env so auth.mjs can see them.
sudo -u personal-assistant nano /opt/personal-assistant/.env

# 4. One-time SMS login (interactive).
sudo -iu personal-assistant
cd /opt/personal-assistant
set -a; source .env; set +a
node auth.mjs
# Follow the prompts. Copy the printed TG_SESSION_STRING=... into .env.
exit

# 5. Fill in BOT_TOKEN and CHANNEL_CHAT_ID.
sudo -u personal-assistant nano /opt/personal-assistant/.env

# 6. Start.
sudo systemctl start personal-assistant-listener
sudo systemctl status personal-assistant-listener
sudo journalctl -u personal-assistant-listener -f
```

## Acceptance test

1. Send any text message to your personal Telegram from a different account.
2. The AI Assistant channel should receive a post in **≤ 3 seconds** of the
   form `📩 14:07 от Иван Иванов: привет`.
3. On the host:
   ```bash
   sudo -u personal-assistant sqlite3 /opt/personal-assistant/assistant.db \
     "SELECT c.first_name, c.last_msg_at, m.text FROM contacts c JOIN messages m USING(tg_user_id) ORDER BY m.ts DESC LIMIT 5;"
   ```
   should show a row for the sender and for the message.
4. `systemctl status personal-assistant-listener` reports `active (running)`.
5. Reboot Aeza (`sudo reboot`), wait for it to come back, and confirm the
   listener restarts automatically without manual intervention.

## Resource envelope

- RAM: expected < 150 MB RSS steady-state. `MemoryMax=300M` in the unit
  is a safety ceiling.
- CPU: idle < 1 % on 1 vCPU. Message bursts are O(1 write + 1 HTTP).
- Disk: each message ≈ a few hundred bytes in SQLite + the same in the FTS
  index. Expect < 100 MB for several years at a normal DM rate.

## Failure modes and what happens

| Failure | Behaviour |
|---|---|
| Missing secret in `.env` | Process exits with code 2 and a loud log line. systemd backoff kicks in. |
| `FLOOD_WAIT` from Telegram | gramjs waits the requested interval and resumes; no crash. |
| Connection drop | gramjs `autoReconnect` reconnects with `retryDelay: 2000`. |
| Bot API call fails | Warning logged, DM is still persisted to SQLite. Nothing is retried (Stage 1 is fire-and-forget for the channel). |
| DB write fails | Handler logs the error and returns. One bad message never kills the process. |
| Process crash | systemd `Restart=always` with `RestartSec=5`; `StartLimitBurst=10` over 5 min prevents hot loops. |

## Rollback

```bash
sudo systemctl disable --now personal-assistant-listener
sudo rm /etc/systemd/system/personal-assistant-listener.service
sudo systemctl daemon-reload

# Wipe code and data as well (destructive):
sudo rm -rf /opt/personal-assistant
sudo userdel personal-assistant
```

The uninstall touches nothing outside `/opt/personal-assistant`, the unit
file, and the `personal-assistant` system user. `/opt/tg-export` and the
`realty_*` Docker containers are never touched by this stage.

## Isolation boundaries (explicit)

This stage does **not**:

- touch `/opt/tg-export/**`
- touch `realty_lightrag`, `realty_ollama`, `realty_litellm`, `supabase-*`
  containers or volumes
- share a user, port, or DB with any existing service
- talk to any network endpoint other than Telegram's MTProto servers and
  `api.telegram.org`

## What's next (Stage 2)

Stage 2 adds message classification and draft generation. It needs:

- An Anthropic API key.
- A VIP contact list (3-5 names) imported into `contacts.vip`.
- A monthly budget cap decision.

See the mission JSON `setup_items_deferred` for the full list.
