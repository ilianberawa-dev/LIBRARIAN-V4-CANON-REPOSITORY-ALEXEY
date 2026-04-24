#!/usr/bin/env node
// Personal Assistant — Stage 1 MTProto listener.
// Reads incoming private DMs via gramjs NewMessage, persists to SQLite,
// and forwards a short summary to the AI Assistant channel via Bot API.
//
// All config via .env (Canon #6). Logs to stdout (captured by systemd journal).
// Out of scope for this stage: classification, drafts, voice, buttons, heartbeat.

import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import Database from 'better-sqlite3';

const require = createRequire(import.meta.url);
const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions/index.js');
const { NewMessage } = require('telegram/events/index.js');

const HERE = path.dirname(fileURLToPath(import.meta.url));

const {
  TG_API_ID,
  TG_API_HASH,
  TG_SESSION_STRING,
  BOT_TOKEN,
  CHANNEL_CHAT_ID,
  DB_PATH = path.join(HERE, 'assistant.db'),
  SCHEMA_PATH = path.join(HERE, 'schema.sql'),
} = process.env;

// Fail loud on missing secrets (Canon #5, #6).
const required = { TG_API_ID, TG_API_HASH, TG_SESSION_STRING, BOT_TOKEN, CHANNEL_CHAT_ID };
const missing = Object.entries(required).filter(([, v]) => !v).map(([k]) => k);
if (missing.length) {
  console.error(`[fatal] missing env: ${missing.join(', ')}`);
  process.exit(2);
}

const log = (level, msg, extra) => {
  const line = { t: new Date().toISOString(), level, msg, ...(extra || {}) };
  process.stdout.write(JSON.stringify(line) + '\n');
};

// ---------- DB ----------

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('synchronous = NORMAL');
db.pragma('foreign_keys = ON');

const schema = fs.readFileSync(SCHEMA_PATH, 'utf8');
db.exec(schema);
log('info', 'schema applied', { db: DB_PATH });

const upsertContact = db.prepare(`
  INSERT INTO contacts (tg_user_id, username, first_name, last_name, first_seen, last_msg_at)
  VALUES (@tg_user_id, @username, @first_name, @last_name, @now, @now)
  ON CONFLICT(tg_user_id) DO UPDATE SET
    username    = excluded.username,
    first_name  = excluded.first_name,
    last_name   = excluded.last_name,
    last_msg_at = excluded.last_msg_at
`);

const insertMessage = db.prepare(`
  INSERT OR IGNORE INTO messages
    (tg_message_id, tg_chat_id, tg_user_id, direction, text, has_media, ts)
  VALUES
    (@tg_message_id, @tg_chat_id, @tg_user_id, @direction, @text, @has_media, @ts)
`);

// ---------- Bot API forward ----------

async function forwardToChannel(text) {
  const body = new URLSearchParams({
    chat_id: CHANNEL_CHAT_ID,
    text,
    disable_web_page_preview: 'true',
  });
  try {
    const resp = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      body,
    });
    const j = await resp.json();
    if (!j.ok) log('warn', 'forward failed', { response: j });
    return j.ok === true;
  } catch (e) {
    log('warn', 'forward error', { error: e.message });
    return false;
  }
}

// ---------- Helpers ----------

function formatHHMM(date) {
  // UTC HH:MM. If operator wants local time they set TZ in the unit file.
  return date.toISOString().slice(11, 16);
}

function displayName(sender) {
  if (!sender) return 'unknown';
  const full = [sender.firstName, sender.lastName].filter(Boolean).join(' ').trim();
  if (full) return full;
  if (sender.username) return `@${sender.username}`;
  return `id:${sender.id}`;
}

function truncate(s, n) {
  if (!s) return '';
  return s.length > n ? s.slice(0, n - 1) + '…' : s;
}

// ---------- NewMessage handler ----------

async function onNewMessage(event) {
  try {
    const msg = event.message;
    if (!msg) return;
    if (msg.out) return;              // skip our own outgoing
    if (!event.isPrivate) return;     // Stage 1 = DMs only

    const sender = await msg.getSender();
    if (!sender) return;

    const now = Math.floor(Date.now() / 1000);
    const text = msg.message || '';
    const hasMedia = !!(msg.media || msg.document || msg.photo);

    upsertContact.run({
      tg_user_id: String(sender.id),
      username:   sender.username  || null,
      first_name: sender.firstName || null,
      last_name:  sender.lastName  || null,
      now,
    });

    insertMessage.run({
      tg_message_id: msg.id,
      tg_chat_id:    String(msg.chatId || sender.id),
      tg_user_id:    String(sender.id),
      direction:     'in',
      text,
      has_media:     hasMedia ? 1 : 0,
      ts:            now,
    });

    const preview = text ? truncate(text, 300) : (hasMedia ? '[media]' : '[empty]');
    const fwd = `📩 ${formatHHMM(new Date())} от ${displayName(sender)}: ${preview}`;
    await forwardToChannel(fwd);

    log('info', 'msg in', {
      msg_id: msg.id,
      from:   displayName(sender),
      chars:  text.length,
      media:  hasMedia,
    });
  } catch (e) {
    // Handler errors must NEVER bring down the process.
    log('error', 'handler failed', { error: e.message, stack: e.stack });
  }
}

// ---------- Main ----------

async function main() {
  const session = new StringSession(TG_SESSION_STRING);
  const client = new TelegramClient(
    session,
    parseInt(TG_API_ID, 10),
    TG_API_HASH,
    {
      connectionRetries: 5,
      autoReconnect: true,
      retryDelay: 2000,
      // gramjs handles FLOOD_WAIT internally and reconnects on drop.
    },
  );
  client.setLogLevel('warn');

  log('info', 'connecting');
  await client.connect();

  const me = await client.getMe();
  log('info', 'connected', {
    id:        String(me.id),
    username:  me.username || null,
    firstName: me.firstName || null,
  });

  client.addEventHandler(onNewMessage, new NewMessage({ incoming: true }));
  log('info', 'listener attached');

  const shutdown = async (sig) => {
    log('info', 'shutting down', { signal: sig });
    try { await client.disconnect(); } catch {}
    try { db.close(); } catch {}
    process.exit(0);
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT',  () => shutdown('SIGINT'));
}

main().catch((e) => {
  log('fatal', 'startup failed', { error: e.message, stack: e.stack });
  // systemd Restart=always + StartLimit* will throttle restart loops.
  process.exit(1);
});
