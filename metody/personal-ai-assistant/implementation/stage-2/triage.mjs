#!/usr/bin/env node
/**
 * Personal AI Assistant — Stage 2: Triage Worker
 *
 * Polls SQLite for unhandled messages, classifies via Anthropic Sonnet 4.6
 * with prompt caching, updates messages.category + contacts.priority,
 * forwards tagged version to AI Assistant channel.
 *
 * Canon: #0 (rules first, LLM last), #3 (single task), #5 (fail loud),
 *        #6 (single .env), #11 (no bot api access)
 */

import 'dotenv/config';
import Database from 'better-sqlite3';
import Anthropic from '@anthropic-ai/sdk';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ─── ENV VALIDATION (fail loud) ────────────────────────────────────
const REQUIRED_ENV = [
  'ANTHROPIC_API_KEY',
  'BOT_TOKEN',
  'CHANNEL_CHAT_ID',
];
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

const DB_PATH = process.env.DB_PATH || '/opt/personal-assistant/assistant.db';
const SKILL_PATH = join(__dirname, 'skills', 'triage.md');
const POLL_INTERVAL_MS = 2000;
const MODEL = 'claude-sonnet-4-6';
const MAX_TOKENS = 200;
const BUDGET_CAP_USD = parseFloat(process.env.BUDGET_CAP_USD || '22');

// ─── INIT ──────────────────────────────────────────────────────────
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const skillSystem = readFileSync(SKILL_PATH, 'utf-8');

// ─── LOGGING (structured JSON) ─────────────────────────────────────
const log = (level, msg, extra = {}) => {
  console.log(JSON.stringify({
    level, msg, ts: new Date().toISOString(), ...extra,
  }));
};

// ─── BUDGET GUARD ──────────────────────────────────────────────────
const checkBudget = () => {
  const row = db.prepare(`
    SELECT COALESCE(SUM(cost_usd), 0) AS spent
    FROM budget_log
    WHERE date >= date('now', 'start of month')
  `).get();
  return { spent: row.spent, capReached: row.spent >= BUDGET_CAP_USD };
};

const logBudget = db.prepare(`
  INSERT INTO budget_log (date, input_tokens, output_tokens, cost_usd, operation)
  VALUES (date('now'), ?, ?, ?, ?)
`);

// Sonnet 4.6 pricing: $3/MTok input, $15/MTok output (cached input -90%)
const calcCost = (inputTokens, cachedTokens, outputTokens) => {
  const fresh = inputTokens - cachedTokens;
  return (fresh * 3 / 1e6) + (cachedTokens * 0.3 / 1e6) + (outputTokens * 15 / 1e6);
};

// ─── PRE-FILTER (no LLM) ───────────────────────────────────────────
const preFilter = (msg, contact) => {
  // bot/channel detection — should be filtered upstream but double-check
  if (contact?.priority === 'noise') return { category: 'noise', urgent: 0, skipLLM: true };

  // very short text without question
  if (msg.text && msg.text.length < 5 && !msg.text.includes('?')) {
    return { category: 'social', urgent: 0, skipLLM: true, confidence: 0.6 };
  }

  return null; // proceed to LLM
};

// ─── PRIORITY COMPUTATION ──────────────────────────────────────────
const computePriority = (contact) => {
  if (contact.is_vip) return 'hot';
  if (contact.msg_count_30d > 10) return 'hot';
  if (contact.msg_count_30d > 3) return 'regular';
  return 'new';
};

// ─── URGENT DETECTION ──────────────────────────────────────────────
const URGENT_REGEX = /срочно|urgent|asap|help|важно|сейчас/i;
const detectUrgent = (text, contact) => {
  if (!contact.is_vip) return 0;
  return URGENT_REGEX.test(text) || text.includes('?') ? 1 : 0;
};

// ─── LLM CLASSIFY ──────────────────────────────────────────────────
const classify = async (text, contact, prevMessages) => {
  const userMsg = `Sender: ${contact.name || 'Unknown'} (@${contact.username || 'no_username'})
Priority hint: ${contact.priority || 'unknown'}
Previous 3 messages from this contact:
${prevMessages.map(m => `- ${m.text}`).join('\n') || '(none)'}

Current message:
${text}`;

  const resp = await anthropic.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    temperature: 0.0,
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

  logBudget.run(usage.input_tokens, usage.output_tokens, cost, 'triage');

  const raw = resp.content[0].text.trim();
  // strip markdown fences if model added them despite instructions
  const json = raw.replace(/^```json\n?/i, '').replace(/\n?```$/, '').trim();

  try {
    const parsed = JSON.parse(json);
    return {
      category: parsed.category,
      confidence: parsed.confidence ?? 0.5,
      reasoning: parsed.reasoning || '',
      cost,
      tokens: usage,
    };
  } catch (e) {
    log('error', 'failed to parse LLM JSON', { raw, error: e.message });
    return { category: 'social', confidence: 0.3, reasoning: 'parse_failed', cost, tokens: usage };
  }
};

// ─── DB QUERIES ────────────────────────────────────────────────────
const getUnhandled = db.prepare(`
  SELECT m.id, m.tg_msg_id, m.chat_id, m.from_id, m.text, m.received_at,
         c.name, c.username, c.priority, c.is_vip, c.msg_count_30d
  FROM messages m
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE m.handled = 0
  ORDER BY m.received_at ASC
  LIMIT 1
`);

const getPrevMessages = db.prepare(`
  SELECT text FROM messages
  WHERE from_id = ? AND id != ?
  ORDER BY received_at DESC
  LIMIT 3
`);

const updateMessage = db.prepare(`
  UPDATE messages SET category = ?, urgent = ?, handled = 1
  WHERE id = ?
`);

const updateContact = db.prepare(`
  UPDATE contacts SET priority = ?, last_msg_at = CURRENT_TIMESTAMP
  WHERE tg_id = ?
`);

// ─── FORWARD TO CHANNEL ────────────────────────────────────────────
const PRIORITY_EMOJI = {
  hot: '🔥', regular: '👥', new: '🆕', noise: '🗑️',
};

const CATEGORY_EMOJI = {
  question: '❓', fyi: 'ℹ️', promo: '📣', social: '💬', spam: '🚫', noise: '🗑️',
};

const forwardTagged = async (msg, contact, classification) => {
  const priorityEmoji = PRIORITY_EMOJI[contact.priority] || '❔';
  const categoryEmoji = CATEGORY_EMOJI[classification.category] || '❔';
  const urgentEmoji = msg.urgent ? '🚨 URGENT ' : '';
  const time = new Date(msg.received_at).toISOString().slice(11, 16);
  const sender = contact.username
    ? `${contact.name} (@${contact.username})`
    : contact.name || 'Unknown';

  const text = `${urgentEmoji}${priorityEmoji} ${categoryEmoji} ${time} от ${sender}\n\n${msg.text}\n\n_${contact.priority || '?'}/${classification.category} (${(classification.confidence * 100).toFixed(0)}%)_`;

  const url = `https://api.telegram.org/bot${process.env.BOT_TOKEN}/sendMessage`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: process.env.CHANNEL_CHAT_ID,
      text,
      parse_mode: 'Markdown',
      disable_notification: !msg.urgent,
    }),
  });

  if (!resp.ok) {
    const err = await resp.text();
    log('error', 'forward failed', { status: resp.status, err });
    return false;
  }
  return true;
};

// ─── PROCESS ONE MESSAGE ───────────────────────────────────────────
const processOne = async () => {
  const row = getUnhandled.get();
  if (!row) return false;

  const contact = {
    tg_id: row.from_id,
    name: row.name,
    username: row.username,
    priority: row.priority,
    is_vip: row.is_vip || 0,
    msg_count_30d: row.msg_count_30d || 0,
  };

  const msg = {
    id: row.id,
    tg_msg_id: row.tg_msg_id,
    chat_id: row.chat_id,
    text: row.text || '',
    received_at: row.received_at,
  };

  // budget check
  const budget = checkBudget();
  if (budget.capReached) {
    log('warn', 'budget cap reached, skip LLM', { spent: budget.spent });
    db.transaction(() => {
      updateMessage.run('social', 0, msg.id);
      updateContact.run(computePriority(contact), contact.tg_id);
    })();
    return true;
  }

  // pre-filter
  const filtered = preFilter(msg, contact);
  let classification;
  if (filtered) {
    classification = filtered;
    log('info', 'pre-filter hit', { msg_id: msg.id, category: filtered.category });
  } else {
    const prev = getPrevMessages.all(contact.tg_id, msg.id);
    try {
      classification = await classify(msg.text, contact, prev);
    } catch (e) {
      log('error', 'classify failed', { msg_id: msg.id, error: e.message });
      classification = { category: 'social', confidence: 0.3, reasoning: 'llm_error' };
    }
  }

  // priority + urgent
  const newPriority = contact.priority === 'noise' ? 'noise' : computePriority(contact);
  const urgent = detectUrgent(msg.text, { ...contact, priority: newPriority });
  msg.urgent = urgent;

  // transactional update
  db.transaction(() => {
    updateMessage.run(classification.category, urgent, msg.id);
    updateContact.run(newPriority, contact.tg_id);
  })();

  log('info', 'classified', {
    msg_id: msg.id,
    category: classification.category,
    confidence: classification.confidence,
    priority: newPriority,
    urgent,
    cost: classification.cost?.toFixed(5),
  });

  // forward to channel
  contact.priority = newPriority;
  await forwardTagged(msg, contact, classification);

  return true;
};

// ─── MAIN LOOP ─────────────────────────────────────────────────────
let running = true;
let processed = 0;

const loop = async () => {
  while (running) {
    try {
      const did = await processOne();
      if (!did) {
        await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
      } else {
        processed++;
      }
    } catch (e) {
      log('error', 'loop error', { error: e.message, stack: e.stack });
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS * 5));
    }
  }
};

// ─── GRACEFUL SHUTDOWN ─────────────────────────────────────────────
const shutdown = (signal) => {
  log('info', `shutdown signal: ${signal}`, { processed });
  running = false;
  setTimeout(() => {
    db.close();
    process.exit(0);
  }, 3000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// ─── START ─────────────────────────────────────────────────────────
log('info', 'triage worker started', {
  db: DB_PATH,
  model: MODEL,
  budget_cap: BUDGET_CAP_USD,
});

loop().catch(e => {
  log('fatal', 'loop crashed', { error: e.message });
  process.exit(1);
});
