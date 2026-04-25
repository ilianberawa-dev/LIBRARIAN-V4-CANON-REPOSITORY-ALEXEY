#!/usr/bin/env node
/**
 * Personal AI Assistant — Stage 4: Bot (Inline Keyboards + Voice Receiver)
 *
 * - Polls drafts WHERE verdict='pending' AND channel_message_id IS NULL
 *   → posts to AI Assistant channel WITH inline keyboard, saves channel_message_id
 * - Listens for callback_query (button clicks)
 *   → updates drafts.verdict, edits message in channel
 * - Listens for voice messages from owner (after [🎙 Voice] click)
 *   → saves file_id to drafts.voice_file_id, sets verdict='awaiting_voice_send'
 * - Listens for text messages from owner (after [✏️ Edit] click)
 *   → saves text to drafts.final_text, sets verdict='awaiting_text_send'
 *
 * NO MTProto access (Canon #11 Privilege Isolation).
 * Sender service handles outbound to recipient chats.
 *
 * Canon: #0 Simplicity (no TTS), #3 Simple Nodes (one task: bot UI),
 *        #5 Fail Loud, #6 Single Vault, #11 Privilege Isolation
 */

import 'dotenv/config';
import Database from 'better-sqlite3';
import TelegramBot from 'node-telegram-bot-api';

// ─── ENV VALIDATION ────────────────────────────────────────────────
const REQUIRED_ENV = ['BOT_TOKEN', 'CHANNEL_CHAT_ID', 'OWNER_TG_ID'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(JSON.stringify({
      level: 'fatal', msg: 'missing_env', key,
      ts: new Date().toISOString(),
    }));
    process.exit(1);
  }
}

const DB_PATH = process.env.DB_PATH || '/opt/personal-assistant/assistant.db';
const VOICE_INBOX = process.env.VOICE_INBOX || '/opt/personal-assistant/voice_inbox';
const POLL_INTERVAL_MS = parseInt(process.env.BOT_POLL_INTERVAL_MS || '2000', 10);
const STATE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const OWNER_TG_ID = parseInt(process.env.OWNER_TG_ID, 10);
const CHANNEL_CHAT_ID = process.env.CHANNEL_CHAT_ID;

// Fail loud on invalid OWNER_TG_ID (Bug #1 fix)
if (Number.isNaN(OWNER_TG_ID) || OWNER_TG_ID <= 0) {
  console.error(JSON.stringify({
    level: 'fatal',
    msg: 'OWNER_TG_ID must be valid positive integer in .env',
    got: process.env.OWNER_TG_ID,
    ts: new Date().toISOString(),
  }));
  process.exit(1);
}

// ─── INIT ──────────────────────────────────────────────────────────
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const bot = new TelegramBot(process.env.BOT_TOKEN, { polling: true });

const log = (level, msg, extra = {}) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...extra }));

// ─── IN-MEMORY STATE ───────────────────────────────────────────────
// Map<user_id, { action: 'edit_text'|'await_voice', draft_id, expires_at }>
const userState = new Map();

const setState = (userId, action, draftId) => {
  userState.set(userId, {
    action,
    draft_id: draftId,
    expires_at: Date.now() + STATE_TTL_MS,
  });
};

const getState = (userId) => {
  const s = userState.get(userId);
  if (!s) return null;
  if (Date.now() > s.expires_at) {
    userState.delete(userId);
    return null;
  }
  return s;
};

const clearState = (userId) => userState.delete(userId);

// Cleanup expired states every minute
setInterval(() => {
  const now = Date.now();
  for (const [uid, s] of userState.entries()) {
    if (now > s.expires_at) userState.delete(uid);
  }
}, 60_000);

// ─── DB QUERIES ────────────────────────────────────────────────────
const selectPendingDraftsNoChannelMsg = db.prepare(`
  SELECT d.id, d.msg_id, d.draft_text, m.text AS incoming_text,
         m.received_at, m.urgent, m.category,
         c.name AS sender_name, c.username AS sender_username,
         c.priority AS sender_priority,
         m.chat_id, m.from_id
  FROM drafts d
  JOIN messages m ON d.msg_id = m.id
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE d.verdict = 'pending'
    AND d.channel_message_id IS NULL
  ORDER BY m.urgent DESC, m.received_at ASC
  LIMIT 5
`);

const updateChannelMessageId = db.prepare(`
  UPDATE drafts SET channel_message_id = ? WHERE id = ?
`);

const selectDraftById = db.prepare(`
  SELECT d.*, m.from_id, m.chat_id, c.name AS sender_name, c.username AS sender_username
  FROM drafts d
  JOIN messages m ON d.msg_id = m.id
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE d.id = ?
`);

const updateDraftVerdict = db.prepare(`
  UPDATE drafts SET verdict = ?, feedback_note = ? WHERE id = ?
`);

const updateDraftFinalText = db.prepare(`
  UPDATE drafts SET final_text = ?, verdict = ? WHERE id = ?
`);

const updateDraftVoiceFileId = db.prepare(`
  UPDATE drafts SET voice_file_id = ?, verdict = ? WHERE id = ?
`);

const insertRule = db.prepare(`
  INSERT INTO rules (scope, scope_id, action, note)
  VALUES (?, ?, ?, ?)
`);

// Bug #2 fix: poll for sent drafts to finalize channel status
const selectFinalizableSent = db.prepare(`
  SELECT d.id, d.draft_text, d.final_text, d.verdict, d.channel_message_id,
         d.feedback_note,
         m.received_at, m.from_id,
         c.name AS sender_name, c.username AS sender_username
  FROM drafts d
  JOIN messages m ON d.msg_id = m.id
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE d.verdict IN ('sent_text', 'sent_voice', 'send_failed')
    AND d.channel_message_id IS NOT NULL
    AND COALESCE(d.status_finalized, 0) = 0
  ORDER BY d.id ASC
  LIMIT 5
`);

const markStatusFinalized = db.prepare(`
  UPDATE drafts SET status_finalized = 1 WHERE id = ?
`);

// ─── INLINE KEYBOARD ───────────────────────────────────────────────
const buildKeyboard = (draftId) => ({
  inline_keyboard: [
    [
      { text: '✅ Отправить', callback_data: `send:${draftId}` },
      { text: '✏️ Правка',    callback_data: `edit:${draftId}` },
    ],
    [
      { text: '🎙 Голосом',   callback_data: `voice:${draftId}` },
      { text: '🚫 Игнор',     callback_data: `ignore:${draftId}` },
      { text: '🔇 Mute',      callback_data: `mute:${draftId}` },
    ],
  ],
});

const PRIORITY_EMOJI = { hot: '🔥', regular: '👥', new: '🆕', noise: '🗑️' };
const CATEGORY_EMOJI = {
  question: '❓', fyi: 'ℹ️', promo: '📣', social: '💬', spam: '🚫',
};

const formatDraftPost = (row) => {
  const pEmoji = PRIORITY_EMOJI[row.sender_priority] || '❔';
  const cEmoji = CATEGORY_EMOJI[row.category] || '❔';
  const urgent = row.urgent ? '🚨 URGENT ' : '';
  const time = new Date(row.received_at).toISOString().slice(11, 16);
  const sender = row.sender_username
    ? `${row.sender_name} (@${row.sender_username})`
    : row.sender_name || `id:${row.from_id}`;

  const draftBlock = row.draft_text === '[NEED_CONTEXT]'
    ? `💡 Draft: _нужен контекст, ответь сам_`
    : `💡 Draft:\n${row.draft_text}`;

  return `${urgent}${pEmoji} ${cEmoji} ${time} от ${sender}\n\n${row.incoming_text}\n\n${draftBlock}\n\n_draft_id=${row.id}_`;
};

// ─── POLL: finalize status after sender completes (Bug #2 fix) ─────
const VERDICT_FINAL_LABEL = {
  sent_text: { emoji: '✅', label: 'SENT (text)' },
  sent_voice: { emoji: '🎙', label: 'SENT (voice)' },
  send_failed: { emoji: '❌', label: 'SEND FAILED' },
};

const pollAndFinalizeStatus = async () => {
  const rows = selectFinalizableSent.all();
  for (const r of rows) {
    try {
      const final = VERDICT_FINAL_LABEL[r.verdict] || { emoji: '❔', label: r.verdict };
      const time = new Date(r.received_at || Date.now()).toISOString().slice(11, 16);
      const sender = r.sender_username
        ? `${r.sender_name} (@${r.sender_username})`
        : r.sender_name || `id:${r.from_id}`;
      const finalBlock = r.final_text
        ? `\n\nFinal: ${r.final_text}`
        : '';
      const errBlock = r.verdict === 'send_failed' && r.feedback_note
        ? `\n\nError: ${r.feedback_note.slice(0, 200)}`
        : '';
      const text = `${final.emoji} ${final.label} | ${time} от ${sender}\n\n${r.draft_text || ''}${finalBlock}${errBlock}\n\n_draft_id=${r.id}_`;

      await bot.editMessageText(text, {
        chat_id: CHANNEL_CHAT_ID,
        message_id: r.channel_message_id,
        reply_markup: { inline_keyboard: [] },
      });
      markStatusFinalized.run(r.id);
      log('info', 'status finalized', { draft_id: r.id, verdict: r.verdict });
    } catch (e) {
      // если editMessageText failed (e.g. message не изменился) — все равно mark finalized
      // чтобы не полить бесконечно
      log('warn', 'finalize edit failed, marking anyway', {
        draft_id: r.id, error: e.message,
      });
      markStatusFinalized.run(r.id);
    }
  }
};

// ─── POLL: post pending drafts with buttons ────────────────────────
const pollAndPostDrafts = async () => {
  const drafts = selectPendingDraftsNoChannelMsg.all();
  for (const d of drafts) {
    try {
      const text = formatDraftPost(d);
      const sent = await bot.sendMessage(CHANNEL_CHAT_ID, text, {
        reply_markup: buildKeyboard(d.id),
        disable_notification: !d.urgent,
      });
      updateChannelMessageId.run(sent.message_id, d.id);
      log('info', 'draft posted with keyboard', {
        draft_id: d.id, channel_msg_id: sent.message_id,
      });
    } catch (e) {
      log('error', 'failed to post draft', {
        draft_id: d.id, error: e.message,
      });
    }
  }
};

// ─── EDIT MESSAGE: replace keyboard with status ────────────────────
const updateChannelMessageStatus = async (draft, statusEmoji, statusText) => {
  if (!draft.channel_message_id) return;
  try {
    const time = new Date(draft.received_at || Date.now()).toISOString().slice(11, 16);
    const sender = draft.sender_username
      ? `${draft.sender_name} (@${draft.sender_username})`
      : draft.sender_name || `id:${draft.from_id}`;
    const finalBlock = draft.final_text
      ? `\n\n${statusEmoji} Final: ${draft.final_text}`
      : '';
    const text = `${statusEmoji} ${statusText} | ${time} от ${sender}\n\n${draft.draft_text || ''}${finalBlock}\n\n_draft_id=${draft.id}_`;
    await bot.editMessageText(text, {
      chat_id: CHANNEL_CHAT_ID,
      message_id: draft.channel_message_id,
      reply_markup: { inline_keyboard: [] },
    });
  } catch (e) {
    log('warn', 'failed to edit message', {
      draft_id: draft.id, error: e.message,
    });
  }
};

// ─── CALLBACK_QUERY HANDLER ────────────────────────────────────────
bot.on('callback_query', async (cb) => {
  const userId = cb.from.id;
  if (userId !== OWNER_TG_ID) {
    await bot.answerCallbackQuery(cb.id, { text: '⛔ Не для тебя.' });
    return;
  }

  const [action, draftIdStr] = (cb.data || '').split(':');
  const draftId = parseInt(draftIdStr, 10);
  if (!draftId) {
    await bot.answerCallbackQuery(cb.id, { text: 'Bad callback' });
    return;
  }

  const draft = selectDraftById.get(draftId);
  if (!draft) {
    await bot.answerCallbackQuery(cb.id, { text: 'Draft не найден' });
    return;
  }

  log('info', 'callback', { action, draft_id: draftId, user: userId });

  switch (action) {
    case 'send': {
      // Set verdict for sender to pick up
      updateDraftFinalText.run(draft.draft_text, 'awaiting_text_send', draftId);
      await bot.answerCallbackQuery(cb.id, { text: '✅ Отправляю...' });
      await updateChannelMessageStatus({ ...draft, final_text: draft.draft_text }, '✅', 'SENDING');
      break;
    }

    case 'edit': {
      setState(userId, 'edit_text', draftId);
      await bot.answerCallbackQuery(cb.id, { text: '✏️ Жду текст' });
      await bot.sendMessage(userId, `✏️ Правка draft #${draftId}\n\nОтправь новый текст ответа. Старый: "${draft.draft_text}"\n\n5 минут timeout.`);
      break;
    }

    case 'voice': {
      setState(userId, 'await_voice', draftId);
      await bot.answerCallbackQuery(cb.id, { text: '🎙 Жду голос' });
      await bot.sendMessage(userId, `🎙 Запиши voice для @${draft.sender_username || draft.sender_name}\n\nDraft подсказка:\n"${draft.draft_text}"\n\n5 минут timeout.`);
      break;
    }

    case 'ignore': {
      updateDraftVerdict.run('rejected', 'ignored by owner', draftId);
      await bot.answerCallbackQuery(cb.id, { text: '🚫 Пропущено' });
      await updateChannelMessageStatus(draft, '🚫', 'IGNORED');
      break;
    }

    case 'mute': {
      try {
        insertRule.run('contact', String(draft.from_id), 'mute',
          `muted via draft #${draftId}`);
        updateDraftVerdict.run('rejected', 'muted contact', draftId);
        await bot.answerCallbackQuery(cb.id, { text: '🔇 Контакт замьючен' });
        await updateChannelMessageStatus(draft, '🔇', `MUTED ${draft.sender_name}`);
      } catch (e) {
        log('error', 'mute failed', { draft_id: draftId, error: e.message });
        await bot.answerCallbackQuery(cb.id, { text: 'Ошибка mute' });
      }
      break;
    }

    default:
      await bot.answerCallbackQuery(cb.id, { text: 'Unknown action' });
  }
});

// ─── VOICE MESSAGE HANDLER ─────────────────────────────────────────
bot.on('voice', async (msg) => {
  const userId = msg.from.id;
  if (userId !== OWNER_TG_ID) return;

  // Skip voice in channel — only DM with bot
  if (msg.chat.id !== userId) return;

  const state = getState(userId);
  if (!state || state.action !== 'await_voice') {
    await bot.sendMessage(userId, '🎙 Voice получен, но нет активного draft в режиме voice. Нажми [🎙 Голосом] под draft в канале сначала.');
    return;
  }

  const fileId = msg.voice.file_id;
  const draft = selectDraftById.get(state.draft_id);
  if (!draft) {
    await bot.sendMessage(userId, `Draft #${state.draft_id} не найден.`);
    clearState(userId);
    return;
  }

  updateDraftVoiceFileId.run(fileId, 'awaiting_voice_send', state.draft_id);
  clearState(userId);

  log('info', 'voice received', {
    draft_id: state.draft_id, file_id: fileId,
    duration: msg.voice.duration,
  });

  await bot.sendMessage(userId,
    `✅ Voice сохранён для draft #${state.draft_id}.\n` +
    `Длительность: ${msg.voice.duration}с\n` +
    `Sender отправит через MTProto в течение 5 сек.`);

  await updateChannelMessageStatus(draft, '🎙', 'VOICE QUEUED');
});

// ─── TEXT MESSAGE HANDLER (for edit) ───────────────────────────────
bot.on('text', async (msg) => {
  const userId = msg.from.id;
  if (userId !== OWNER_TG_ID) return;
  if (msg.chat.id !== userId) return; // only DM
  if (msg.text?.startsWith('/')) return; // commands ignored here

  const state = getState(userId);
  if (!state || state.action !== 'edit_text') return; // not in edit mode

  const draft = selectDraftById.get(state.draft_id);
  if (!draft) {
    await bot.sendMessage(userId, `Draft #${state.draft_id} не найден.`);
    clearState(userId);
    return;
  }

  const newText = msg.text.trim();
  if (!newText) {
    await bot.sendMessage(userId, 'Пустой текст. Попробуй ещё раз.');
    return;
  }

  updateDraftFinalText.run(newText, 'awaiting_text_send', state.draft_id);
  clearState(userId);

  log('info', 'edit received', {
    draft_id: state.draft_id, length: newText.length,
  });

  await bot.sendMessage(userId,
    `✅ Правка сохранена для draft #${state.draft_id}.\n` +
    `Новый текст: "${newText}"\n` +
    `Sender отправит через MTProto в течение 5 сек.`);

  await updateChannelMessageStatus(
    { ...draft, final_text: newText },
    '✏️', 'EDITED, SENDING'
  );
});

// ─── ERROR HANDLERS ────────────────────────────────────────────────
bot.on('polling_error', (e) => {
  log('error', 'polling_error', { error: e.message });
});

bot.on('error', (e) => {
  log('error', 'bot_error', { error: e.message });
});

// ─── MAIN POLL LOOP ────────────────────────────────────────────────
let running = true;

const mainLoop = async () => {
  while (running) {
    try {
      await pollAndPostDrafts();
      await pollAndFinalizeStatus(); // Bug #2 fix
    } catch (e) {
      log('error', 'poll loop error', { error: e.message });
    }
    await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
  }
};

// ─── GRACEFUL SHUTDOWN ─────────────────────────────────────────────
const shutdown = (signal) => {
  log('info', `shutdown ${signal}`);
  running = false;
  bot.stopPolling().then(() => {
    db.close();
    process.exit(0);
  }).catch(() => process.exit(1));
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// ─── START ─────────────────────────────────────────────────────────
log('info', 'bot started', {
  db: DB_PATH, owner: OWNER_TG_ID, channel: CHANNEL_CHAT_ID,
});

mainLoop().catch(e => {
  log('fatal', 'main loop crashed', { error: e.message });
  process.exit(1);
});
