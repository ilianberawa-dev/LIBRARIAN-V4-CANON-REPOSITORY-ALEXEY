# HOTFIX 2026-04-26 — listener.mjs secondary-session updates fix

**Status:** PRIORITY 1 — fixes "messages don't arrive until phone reads" issue.
**Target:** `/opt/personal-assistant/listener.mjs`

---

## Problem

QR-auth created secondary-device session. Telegram does not push real-time
updates to secondary sessions until primary device (phone) acknowledges
each message.

## Fix — 2 changes in listener.mjs

### Edit 1 — Add `useWSS: true` to TelegramClient options

**Find:**
```javascript
const client = new TelegramClient(session, apiId, apiHash, { connectionRetries: 5 });
```

**Replace with:**
```javascript
const client = new TelegramClient(session, apiId, apiHash, {
  connectionRetries: 5,
  useWSS: true
});
```

### Edit 2 — Add periodic catchUp() after listener_ready

**Find:**
```javascript
  client.addEventHandler(handleNewMessage, new NewMessage({ incoming: true }));
  log('info', 'listener_ready');
```

**Replace with:**
```javascript
  client.addEventHandler(handleNewMessage, new NewMessage({ incoming: true }));
  log('info', 'listener_ready');

  // HOTFIX 2026-04-26: secondary-session catch-up.
  // QR-auth sessions don't receive real-time updates until phone acknowledges.
  // Polling catchUp() every 30s force-syncs missed updates.
  setInterval(async () => {
    try {
      await client.catchUp();
    } catch (err) {
      log('warn', 'catchup_failed', { error: String(err?.message || err) });
    }
  }, 30_000);
  log('info', 'catchup_scheduler_started', { interval_sec: 30 });
```

---

## Apply on server

```bash
sudo cp /opt/personal-assistant/listener.mjs /opt/personal-assistant/listener.mjs.bak.2026-04-26-secondary
sudo nano /opt/personal-assistant/listener.mjs   # apply Edit 1 + Edit 2 manually
sudo systemctl restart personal-assistant-listener
sudo journalctl -u personal-assistant-listener --since "1 min ago" -f
```

Expected log lines after restart:
```
mtproto_connected
listener_ready
catchup_scheduler_started
```

## Acceptance test

1. Sender отправляет DM на +971524725200.
2. Owner phone OFF / locked / not opening Telegram.
3. Wait ≤45 sec.
4. Check DB: `sudo -u personal-assistant sqlite3 /opt/personal-assistant/assistant.db "SELECT id, text, received_at FROM messages ORDER BY id DESC LIMIT 5"`
5. New message present without phone interaction → Stage 1 autonomous PASS.

## If still fails after 45 sec

Apply Try #2.5 — low-level GetDifference polling. Patch will be issued as
separate handoff if Try #1 insufficient.

## Acceptable tech debt path

If both Try #1 and Try #2.5 fail → architect approved accepting limitation.
Document as "open important DMs on phone for system to catch up", continue
MVP closure. Stage 6 heartbeat + Stage 5 voice + skill hotfix proceed
independently.
