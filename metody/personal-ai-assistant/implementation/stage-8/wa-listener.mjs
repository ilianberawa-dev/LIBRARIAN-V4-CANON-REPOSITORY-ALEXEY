import express from 'express';
import Database from 'better-sqlite3';
import { getSecret, redact } from './lib/vault.mjs';

// --- Fail-loud env check ---
const REQUIRED_ENV = ['OWNER_TG_ID', 'DB_PATH'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.log(JSON.stringify({ ts: new Date().toISOString(), level: 'fatal', msg: `Missing env: ${key}` }));
    process.exit(1);
  }
}

const BOT_TOKEN    = getSecret('bot-token');
const OWNER_TG_ID  = process.env.OWNER_TG_ID;
const DB_PATH      = process.env.DB_PATH;
const PORT         = 3005;
const TG_TIMEOUT   = 10_000;

const db  = new Database(DB_PATH);
const app = express();
app.use(express.json({ limit: '1mb' }));

const insertWa = db.prepare(`
  INSERT INTO wa_messages (phone, name, kind, text, raw_json)
  VALUES (@phone, @name, @kind, @text, @raw)
`);

async function notifyTelegram(text) {
  const ctrl = new AbortController();
  const tid  = setTimeout(() => ctrl.abort(), TG_TIMEOUT);
  try {
    const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: OWNER_TG_ID, text, parse_mode: 'Markdown' }),
      signal: ctrl.signal,
    });
    if (!res.ok) {
      const body = await res.text();
      console.log(JSON.stringify({ ts: new Date().toISOString(), level: 'error', msg: 'tg_send_failed', status: res.status, body: body.slice(0, 200) }));
    }
  } catch (err) {
    console.log(JSON.stringify({ ts: new Date().toISOString(), level: 'error', msg: 'tg_fetch_error', error: err.message }));
  } finally {
    clearTimeout(tid);
  }
}

// GOWA webhook payload schema (incoming):
// { code: "message.updated", result: {
//     sender: { phone, name, is_me },
//     text, type, timestamp, message_id } }
app.post('/webhook', async (req, res) => {
  res.sendStatus(200);

  try {
    const payload = req.body;
    const result  = payload?.result;
    if (!result) return;

    const sender = result.sender || {};
    if (sender.is_me) return; // skip outgoing

    const phone = sender.phone || '';
    const name  = sender.name  || phone || 'Unknown';
    const kind  = result.type  || 'text';
    const text  = result.text  || `[${kind}]`;

    const row = insertWa.run({ phone, name, kind, text, raw: JSON.stringify(payload) });

    const preview   = text.length > 200 ? text.slice(0, 200) + '…' : text;
    const kindLabel = kind !== 'text' ? ` _(${kind})_` : '';
    const tgMsg     = `📱 *WA от ${name}:*${kindLabel}\n${preview}`;

    await notifyTelegram(tgMsg);

    console.log(JSON.stringify({
      ts: new Date().toISOString(), event: 'wa_message',
      sender: redact(name), kind, wa_id: row.lastInsertRowid,
    }));
  } catch (err) {
    console.log(JSON.stringify({ ts: new Date().toISOString(), level: 'error', msg: 'webhook_handler', error: err.message }));
  }
});

// Health check
app.get('/health', (_req, res) => res.json({ ok: true, ts: new Date().toISOString() }));

const shutdown = () => { db.close(); process.exit(0); };
process.on('SIGTERM', shutdown);
process.on('SIGINT',  shutdown);

app.listen(PORT, '127.0.0.1', () => {
  console.log(JSON.stringify({ ts: new Date().toISOString(), event: 'startup', port: PORT, db: DB_PATH }));
});
