#!/usr/bin/env node
/**
 * Personal AI Assistant — Stage 3: Draft Generator Worker
 *
 * Polls SQLite for messages with category set + draft not yet generated,
 * generates draft via Sonnet 4.6 with prompt caching using draft.md skill,
 * stores draft in drafts table with verdict='pending',
 * forwards to AI Assistant channel for owner review.
 *
 * Canon: #0 (rules first, LLM last), #4 (skill not agent), #5 (fail loud),
 *        #6 (single .env), #8 (drafts not auto-reply)
 */

import Database from 'better-sqlite3';
import Anthropic from '@anthropic-ai/sdk';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { getSecret } from './lib/vault.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── ENV VALIDATION (fail loud) ────────────────────────────────────
const REQUIRED_ENV = ['CHANNEL_CHAT_ID'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(JSON.stringify({
      level: 'fatal',
      msg: `missing env: ${key}`,
      ts: new Date().toISOString(),
    }));
    process.exit(1);
  }
}

const ANTHROPIC_API_KEY = getSecret('anthropic-api-key');
const BOT_TOKEN = getSecret('bot-token');

const DB_PATH = process.env.DB_PATH || '/opt/personal-assistant/assistant.db';
const SKILL_PATH = join(__dirname, 'skills', 'draft.md');
const POLL_INTERVAL_MS = 3000;
const MODEL = 'claude-sonnet-4-6';
const MAX_TOKENS = 400;
const BUDGET_CAP_USD = parseFloat(process.env.BUDGET_CAP_USD || '22');

// ─── INIT ──────────────────────────────────────────────────────────
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });
const skillSystem = readFileSync(SKILL_PATH, 'utf-8');

// ─── LOGGING ───────────────────────────────────────────────────────
const log = (level, msg, extra = {}) => {
  console.log(JSON.stringify({ level, msg, ts: new Date().toISOString(), ...extra }));
};

// ─── BUDGET ────────────────────────────────────────────────────────
const checkBudget = () => {
  const row = db.prepare(`
    SELECT COALESCE(SUM(cost_usd), 0) AS spent FROM budget_log
    WHERE date >= date('now', 'start of month')
  `).get();
  return { spent: row.spent, capReached: row.spent >= BUDGET_CAP_USD };
};

const logBudget = db.prepare(`
  INSERT INTO budget_log (date, input_tokens, output_tokens, cost_usd, operation)
  VALUES (date('now'), ?, ?, ?, ?)
`);

const calcCost = (inputTokens, cachedTokens, outputTokens) => {
  const fresh = Math.max(0, inputTokens - cachedTokens);
  return (fresh * 3 / 1e6) + (cachedTokens * 0.3 / 1e6) + (outputTokens * 15 / 1e6);
};

// ─── ELIGIBILITY (rules first, no LLM) ─────────────────────────────
const shouldDraft = (msg, contact) => {
  if (msg.category === 'noise' || msg.category === 'spam') return { skip: true, reason: 'noise/spam' };
  if (msg.category === 'promo' && contact.priority === 'new') return { skip: true, reason: 'promo from new' };

  // check existing rules
  const rules = db.prepare(`
    SELECT action FROM rules
    WHERE (scope='contact' AND scope_id=?)
       OR (scope='chat' AND scope_id=?)
  `).all(String(contact.tg_id), String(msg.chat_id));

  for (const r of rules) {
    if (r.action === 'never_draft' || r.action === 'mute') {
      return { skip: true, reason: `rule: ${r.action}` };
    }
  }

  // priority gating
  if (contact.priority === 'noise') return { skip: true, reason: 'contact noise' };
  if (contact.priority === 'new' && msg.category !== 'question') {
    return { skip: true, reason: 'new contact non-question' };
  }

  return { skip: false };
};

// ─── INPUT ASSEMBLY ────────────────────────────────────────────────
const getLastMessagesFromSender = db.prepare(`
  SELECT text FROM messages
  WHERE from_id = ? AND id != ?
  ORDER BY received_at DESC LIMIT 5
`);

const getOwnerRepliesToSender = db.prepare(`
  SELECT final_text FROM drafts d
  JOIN messages m ON d.msg_id = m.id
  WHERE m.from_id = ? AND d.verdict IN ('sent_as_is', 'edited')
    AND d.final_text IS NOT NULL
  ORDER BY d.generated_at DESC LIMIT 3
`);

const getVoiceSamples = db.prepare(`
  SELECT text FROM voice_samples
  ORDER BY RANDOM() LIMIT 10
`);

const detectLanguage = (text) => {
  if (!text) return 'auto';
  const cyrillic = (text.match(/[а-яёА-ЯЁ]/g) || []).length;
  const latin = (text.match(/[a-zA-Z]/g) || []).length;
  if (cyrillic > latin) return 'ru';
  if (latin > cyrillic * 2) return 'en';
  return 'auto';
};

const buildUserMessage = (msg, contact) => {
  const last5 = getLastMessagesFromSender.all(contact.tg_id, msg.id)
    .map(r => r.text).filter(Boolean).reverse();
  const lastReplies = getOwnerRepliesToSender.all(contact.tg_id)
    .map(r => r.final_text).filter(Boolean).reverse();
  const voiceSamples = getVoiceSamples.all().map(r => r.text).filter(Boolean);

  return `INCOMING_MESSAGE: ${msg.text}
SENDER_NAME: ${contact.name || 'Unknown'}
SENDER_USERNAME: ${contact.username ? '@' + contact.username : 'no_username'}
SENDER_PRIORITY: ${contact.priority || 'unknown'}
SENDER_VIP: ${contact.is_vip ? 'yes' : 'no'}
SENDER_NOTES: ${contact.notes || 'none'}
SENDER_TONE: ${contact.tone || 'unknown'}
INCOMING_CATEGORY: ${msg.category}
INCOMING_URGENT: ${msg.urgent ? 'yes' : 'no'}
INCOMING_LANGUAGE: ${detectLanguage(msg.text)}
LAST_5_MESSAGES_FROM_SENDER:
${last5.length ? last5.map((t,i) => `${i+1}. ${t}`).join('\n') : '(none)'}
LAST_3_OWNER_REPLIES_TO_SENDER:
${lastReplies.length ? lastReplies.map((t,i) => `${i+1}. ${t}`).join('\n') : '(none)'}
OWNER_VOICE_SAMPLES:
${voiceSamples.length ? voiceSamples.map((t,i) => `${i+1}. ${t}`).join('\n') : '(none, cold start)'}
CURRENT_TIME: ${new Date().toISOString()}`;
};

// ─── LLM DRAFT GEN ─────────────────────────────────────────────────
const generateDraft = async (msg, contact) => {
  const userMsg = buildUserMessage(msg, contact);

  const resp = await anthropic.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    temperature: 0.4,
    system: [{
      type: 'text',
      text: skillSystem,
      cache_control: { type: 'ephemeral' },
    }],
    messages: [{ role: 'user', content: userMsg }],
  });

  const usage = resp.usage;
  const cost = calcCost(
    usage.input_tokens,
    usage.cache_read_input_tokens || 0,
    usage.output_tokens,
  );
  logBudget.run(usage.input_tokens, usage.output_tokens, cost, 'draft');

  const text = resp.content[0].text.trim();
  return { text, cost, tokens: usage };
};

// ─── DB QUERIES ────────────────────────────────────────────────────
const getReadyForDraft = db.prepare(`
  SELECT m.id, m.tg_msg_id, m.chat_id, m.from_id, m.text, m.category,
         m.urgent, m.received_at,
         c.name, c.username, c.priority, c.is_vip, c.notes, c.tone,
         c.msg_count_30d
  FROM messages m
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE m.handled = 1 AND m.category IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM drafts d WHERE d.msg_id = m.id)
  ORDER BY m.urgent DESC, m.received_at ASC
  LIMIT 1
`);

const insertDraft = db.prepare(`
  INSERT INTO drafts (msg_id, draft_text, verdict)
  VALUES (?, ?, 'pending')
`);

const insertDraftSkip = db.prepare(`
  INSERT INTO drafts (msg_id, draft_text, verdict, feedback_note)
  VALUES (?, NULL, 'skipped', ?)
`);

// ─── FORWARD TO CHANNEL ────────────────────────────────────────────
const PRIORITY_EMOJI = { hot: '🔥', regular: '👥', new: '🆕', noise: '🗑️' };
const CATEGORY_EMOJI = { question: '❓', fyi: 'ℹ️', promo: '📣', social: '💬', spam: '🚫', noise: '🗑️' };

const forwardDraft = async (msg, contact, draftText, draftId) => {
  const pEmoji = PRIORITY_EMOJI[contact.priority] || '❔';
  const cEmoji = CATEGORY_EMOJI[msg.category] || '❔';
  const urgent = msg.urgent ? '🚨 URGENT ' : '';
  const time = new Date(msg.received_at).toISOString().slice(11, 16);
  const sender = contact.username
    ? `${contact.name} (@${contact.username})`
    : (contact.name || 'Unknown');

  const text = draftText === '[NEED_CONTEXT]'
    ? `${urgent}${pEmoji} ${cEmoji} ${time} от ${sender}\n\n${msg.text}\n\n💡 Draft: _нужен контекст, ответь сам_\n\n_draft_id=${draftId}_`
    : `${urgent}${pEmoji} ${cEmoji} ${time} от ${sender}\n\n${msg.text}\n\n💡 Draft:\n${draftText}\n\n_draft_id=${draftId} (Stage 4 даст кнопки)_`;

  const url = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: process.env.CHANNEL_CHAT_ID,
      text,
      // parse_mode: 'Markdown',  // DISABLED: unescaped _ in msg.text breaks parsing
      disable_notification: !msg.urgent,
    }),
  });

  if (!resp.ok) {
    const err = await resp.text();
    log('error', 'draft forward failed', { status: resp.status, err });
    return false;
  }
  return true;
};

// ─── PROCESS ONE ───────────────────────────────────────────────────
const processOne = async () => {
  const row = getReadyForDraft.get();
  if (!row) return false;

  const contact = {
    tg_id: row.from_id, name: row.name, username: row.username,
    priority: row.priority, is_vip: row.is_vip || 0,
    notes: row.notes, tone: row.tone, msg_count_30d: row.msg_count_30d || 0,
  };
  const msg = {
    id: row.id, tg_msg_id: row.tg_msg_id, chat_id: row.chat_id,
    text: row.text || '', category: row.category, urgent: row.urgent,
    received_at: row.received_at,
  };

  // budget check
  const budget = checkBudget();
  if (budget.capReached) {
    log('warn', 'budget cap reached, skip draft', { spent: budget.spent });
    insertDraftSkip.run(msg.id, 'budget_cap');
    return true;
  }

  // eligibility
  const elig = shouldDraft(msg, contact);
  if (elig.skip) {
    insertDraftSkip.run(msg.id, elig.reason);
    log('info', 'draft skipped', { msg_id: msg.id, reason: elig.reason });
    return true;
  }

  // generate
  let draft;
  try {
    draft = await generateDraft(msg, contact);
  } catch (e) {
    log('error', 'draft gen failed', { msg_id: msg.id, error: e.message });
    insertDraftSkip.run(msg.id, `error: ${e.message.slice(0, 80)}`);
    return true;
  }

  // store + forward
  const result = insertDraft.run(msg.id, draft.text);
  const draftId = result.lastInsertRowid;

  log('info', 'draft generated', {
    msg_id: msg.id, draft_id: draftId,
    length: draft.text.length, cost: draft.cost.toFixed(5),
    cached: draft.tokens.cache_read_input_tokens || 0,
  });

  await forwardDraft(msg, contact, draft.text, draftId);
  return true;
};

// ─── MAIN LOOP ─────────────────────────────────────────────────────
let running = true;
let processed = 0;

const loop = async () => {
  while (running) {
    try {
      const did = await processOne();
      if (!did) await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
      else processed++;
    } catch (e) {
      log('error', 'loop error', { error: e.message, stack: e.stack });
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS * 5));
    }
  }
};

const shutdown = (signal) => {
  log('info', `shutdown ${signal}`, { processed });
  running = false;
  setTimeout(() => { db.close(); process.exit(0); }, 3000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

log('info', 'draft worker started', {
  db: DB_PATH, model: MODEL, budget_cap: BUDGET_CAP_USD,
});
loop().catch(e => { log('fatal', 'loop crashed', { error: e.message }); process.exit(1); });
