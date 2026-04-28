// listener.mjs — Personal AI Assistant Stage 1
// Reads incoming DMs via MTProto, persists to SQLite, forwards to AI Assistant channel.
// Canon: #2 Minimal Integration (gramjs + better-sqlite3 + native fetch),
//        #5 Fail Loud (process.exit on missing env),
//        #6 Single Vault (.env only),
//        #11 Privilege Isolation (no Bot API write capability beyond channel forward).

import 'dotenv/config';
import Database from 'better-sqlite3';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { NewMessage } from 'telegram/events/index.js';

const REQUIRED_ENV = [
  'TG_API_ID', 'TG_API_HASH', 'TG_SESSION_STRING',
  'BOT_TOKEN', 'CHANNEL_CHAT_ID'
];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(JSON.stringify({ level: 'fatal', msg: 'missing_env', key }));
    process.exit(1);
  }
}

const DB_PATH = process.env.DB_PATH || '/opt/personal-assistant/assistant.db';
const BOT_TOKEN = process.env.BOT_TOKEN;
const CHANNEL_CHAT_ID = process.env.CHANNEL_CHAT_ID;

const log = (level, msg, extra = {}) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...extra }));

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const upsertContact = db.prepare(`
  INSERT INTO contacts (tg_id, name, username, last_msg_at, msg_count_30d)
  VALUES (@tg_id, @name, @username, CURRENT_TIMESTAMP, 1)
  ON CONFLICT(tg_id) DO UPDATE SET
    name = COALESCE(excluded.name, contacts.name),
    username = COALESCE(excluded.username, contacts.username),
    last_msg_at = CURRENT_TIMESTAMP,
    msg_count_30d = contacts.msg_count_30d + 1
`);

const insertMessage = db.prepare(`
  INSERT INTO messages (tg_msg_id, chat_id, from_id, text)
  VALUES (@tg_msg_id, @chat_id, @from_id, @text)
`);

const insertFts = db.prepare(`
  INSERT INTO messages_fts(rowid, text, from_name, chat_name)
  VALUES (@rowid, @text, @from_name, @chat_name)
`);

const persistMessage = db.transaction((contact, message, ftsRow) => {
  upsertContact.run(contact);
  const result = insertMessage.run(message);
  insertFts.run({ ...ftsRow, rowid: result.lastInsertRowid });
  return result.lastInsertRowid;
});

async function forwardToChannel(text) {
  const url = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: CHANNEL_CHAT_ID,
      text,
      disable_web_page_preview: true
    })
  });
  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`bot_api_error status=${resp.status} body=${body}`);
  }
}

function formatTime(ts) {
  const d = new Date(ts * 1000);
  return d.toISOString().substring(11, 16);
}

function senderLabel(sender) {
  if (!sender) return 'unknown';
  const first = sender.firstName || '';
  const last = sender.lastName || '';
  const full = `${first} ${last}`.trim();
  if (full) return full;
  if (sender.username) return `@${sender.username}`;
  return String(sender.id || 'unknown');
}

const apiId = parseInt(process.env.TG_API_ID, 10);
const apiHash = process.env.TG_API_HASH;
const session = new StringSession(process.env.TG_SESSION_STRING);
const client = new TelegramClient(session, apiId, apiHash, { connectionRetries: 5 });

async function handleNewMessage(event) {
  const m = event.message;
  if (!m || !m.message) return;
  if (!event.isPrivate) return;
  if (m.out) return;

  try {
    const sender = await m.getSender();
    const name = senderLabel(sender);
    const username = sender?.username || null;
    const tgId = Number(sender?.id || 0);
    const chatId = Number(m.chatId || tgId);
    const text = m.message;

    const rowId = persistMessage(
      { tg_id: tgId, name, username },
      { tg_msg_id: m.id, chat_id: chatId, from_id: tgId, text },
      { text, from_name: name, chat_name: 'private' }
    );

    const forwardText = `📩 ${formatTime(m.date)} from ${name}: ${text}`;
    await forwardToChannel(forwardText);

    log('info', 'message_handled', { row_id: rowId, from: name, len: text.length });
  } catch (err) {
    log('error', 'handle_failed', { error: String(err?.message || err) });
    throw err;
  }
}

async function main() {
  log('info', 'listener_starting', { db: DB_PATH });
  await client.connect();
  log('info', 'mtproto_connected');

  client.addEventHandler(handleNewMessage, new NewMessage({ incoming: true }));
  log('info', 'listener_ready');

  const shutdown = async (signal) => {
    log('info', 'shutdown', { signal });
    try { await client.disconnect(); } catch {}
    try { db.close(); } catch {}
    process.exit(0);
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err) => {
  log('fatal', 'main_crashed', { error: String(err?.message || err), stack: err?.stack });
  process.exit(1);
});
