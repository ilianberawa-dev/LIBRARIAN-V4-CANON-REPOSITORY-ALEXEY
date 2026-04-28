#!/usr/bin/env node
/**
 * Personal AI Assistant — Stage 4: MTProto Sender
 *
 * Polls drafts WHERE verdict IN ('awaiting_text_send', 'awaiting_voice_send').
 * Sends final_text or voice via MTProto (gramjs) using owner's session
 * to the original chat (drafts.msg_id → messages.chat_id).
 *
 * NO Bot API access (Canon #11 Privilege Isolation).
 * Bot service handles UI; this service only sends outbound.
 *
 * Voice flow:
 *   1. Bot saved voice_file_id (Telegram Bot API file_id)
 *   2. Sender downloads .ogg via Bot API getFile (read-only)
 *   3. Sender uploads to recipient chat via MTProto sendFile (voice mode)
 *
 * Canon: #3 Simple Nodes (one task: send), #5 Fail Loud,
 *        #6 Single Vault, #11 Privilege Isolation
 */

import Database from 'better-sqlite3';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { Api } from 'telegram';
import { writeFile, mkdir, unlink } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { getSecret } from './lib/vault.mjs';

// ─── ENV VALIDATION ────────────────────────────────────────────────
const REQUIRED_ENV = ['TG_API_ID'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(JSON.stringify({
      level: 'fatal', msg: 'missing_env', key,
      ts: new Date().toISOString(),
    }));
    process.exit(1);
  }
}

const TG_API_HASH = getSecret('tg-api-hash');
const TG_SESSION = getSecret('tg-session-string');
const BOT_TOKEN = getSecret('bot-token');

const DB_PATH = process.env.DB_PATH || '/opt/personal-assistant/assistant.db';
const VOICE_INBOX = process.env.VOICE_INBOX || '/opt/personal-assistant/voice_inbox';
const POLL_INTERVAL_MS = parseInt(process.env.SENDER_POLL_MS || '3000', 10);
const TG_API_ID = parseInt(process.env.TG_API_ID, 10);

// ─── INIT ──────────────────────────────────────────────────────────
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const log = (level, msg, extra = {}) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...extra }));

let mtprotoClient = null;

const initMTProto = async () => {
  const session = new StringSession(TG_SESSION);
  mtprotoClient = new TelegramClient(session, TG_API_ID, TG_API_HASH, {
    connectionRetries: 5,
  });
  await mtprotoClient.connect();
  log('info', 'mtproto connected');
};

// ─── DB QUERIES ────────────────────────────────────────────────────
const selectAwaitingSend = db.prepare(`
  SELECT d.id, d.msg_id, d.draft_text, d.final_text, d.voice_file_id, d.verdict,
         m.chat_id, m.tg_msg_id, m.from_id,
         c.name AS sender_name, c.username AS sender_username
  FROM drafts d
  JOIN messages m ON d.msg_id = m.id
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE d.verdict IN ('awaiting_text_send', 'awaiting_voice_send')
  ORDER BY d.id ASC
  LIMIT 1
`);

const updateVerdict = db.prepare(`
  UPDATE drafts SET verdict = ?, feedback_note = ? WHERE id = ?
`);

const insertVoiceSample = db.prepare(`
  INSERT INTO voice_samples (to_contact_id, text, sent_at)
  VALUES (?, ?, CURRENT_TIMESTAMP)
`);

// ─── DOWNLOAD VOICE FROM BOT API ───────────────────────────────────
const downloadVoiceFromBotAPI = async (fileId, draftId) => {
  // Bot API getFile → returns file_path
  const getFileUrl = `https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${encodeURIComponent(fileId)}`;
  const fileResp = await fetch(getFileUrl);
  if (!fileResp.ok) throw new Error(`getFile failed: ${fileResp.status}`);
  const fileJson = await fileResp.json();
  if (!fileJson.ok) throw new Error(`getFile not ok: ${JSON.stringify(fileJson)}`);

  const filePath = fileJson.result.file_path;
  const downloadUrl = `https://api.telegram.org/file/bot${BOT_TOKEN}/${filePath}`;
  const dlResp = await fetch(downloadUrl);
  if (!dlResp.ok) throw new Error(`download failed: ${dlResp.status}`);
  const buffer = Buffer.from(await dlResp.arrayBuffer());

  if (!existsSync(VOICE_INBOX)) {
    await mkdir(VOICE_INBOX, { recursive: true });
  }
  const localPath = join(VOICE_INBOX, `draft_${draftId}.ogg`);
  await writeFile(localPath, buffer);
  return localPath;
};

// ─── SEND TEXT via MTProto ─────────────────────────────────────────
const sendTextViaMTProto = async (chatId, text) => {
  // chat_id from gramjs listener was BigInt-able number; reuse same encoding
  const peer = await mtprotoClient.getInputEntity(chatId);
  await mtprotoClient.sendMessage(peer, { message: text });
};

// ─── SEND VOICE via MTProto ────────────────────────────────────────
const sendVoiceViaMTProto = async (chatId, oggPath) => {
  const peer = await mtprotoClient.getInputEntity(chatId);
  // voice flag = true → Telegram отображает как голосовое
  await mtprotoClient.sendFile(peer, {
    file: oggPath,
    voiceNote: true,
    attributes: [
      new Api.DocumentAttributeAudio({
        voice: true,
        duration: 0, // Telegram detects from file
      }),
    ],
  });
};

// ─── PROCESS ONE ───────────────────────────────────────────────────
const processOne = async () => {
  const row = selectAwaitingSend.get();
  if (!row) return false;

  log('info', 'sending', {
    draft_id: row.id, verdict: row.verdict,
    chat_id: row.chat_id, to: row.sender_username || row.sender_name,
  });

  try {
    if (row.verdict === 'awaiting_text_send') {
      const text = row.final_text || row.draft_text;
      if (!text || text === '[NEED_CONTEXT]') {
        updateVerdict.run('rejected', 'no text to send', row.id);
        log('warn', 'skip empty text', { draft_id: row.id });
        return true;
      }
      await sendTextViaMTProto(row.chat_id, text);
      updateVerdict.run('sent_text', null, row.id);
      // Save as voice sample for draft style learning
      insertVoiceSample.run(row.from_id, text);
      log('info', 'text sent', { draft_id: row.id });
    }

    else if (row.verdict === 'awaiting_voice_send') {
      if (!row.voice_file_id) {
        updateVerdict.run('rejected', 'no voice_file_id', row.id);
        log('warn', 'skip no voice', { draft_id: row.id });
        return true;
      }
      const oggPath = await downloadVoiceFromBotAPI(row.voice_file_id, row.id);
      await sendVoiceViaMTProto(row.chat_id, oggPath);
      updateVerdict.run('sent_voice', null, row.id);
      // Cleanup local file
      try { await unlink(oggPath); } catch {}
      log('info', 'voice sent', { draft_id: row.id });
    }

  } catch (e) {
    log('error', 'send failed', {
      draft_id: row.id, verdict: row.verdict, error: e.message,
    });
    updateVerdict.run('send_failed', e.message.slice(0, 200), row.id);
  }

  return true;
};

// ─── MAIN LOOP ─────────────────────────────────────────────────────
let running = true;

const loop = async () => {
  while (running) {
    try {
      const did = await processOne();
      if (!did) await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
    } catch (e) {
      log('error', 'loop error', { error: e.message });
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS * 5));
    }
  }
};

// ─── GRACEFUL SHUTDOWN ─────────────────────────────────────────────
const shutdown = async (signal) => {
  log('info', `shutdown ${signal}`);
  running = false;
  if (mtprotoClient) {
    try { await mtprotoClient.disconnect(); } catch {}
  }
  setTimeout(() => { db.close(); process.exit(0); }, 2000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// ─── START ─────────────────────────────────────────────────────────
(async () => {
  try {
    await initMTProto();
    log('info', 'sender started', { db: DB_PATH });
    await loop();
  } catch (e) {
    log('fatal', 'startup failed', { error: e.message });
    process.exit(1);
  }
})();
