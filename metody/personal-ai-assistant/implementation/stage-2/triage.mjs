// triage.mjs — Stage 2: classifier worker for Personal AI Assistant.
// Polls SQLite for unhandled messages, applies deterministic rules + Sonnet 4.6
// classification, updates messages.category/urgent/handled, forwards a tagged
// summary into the AI Assistant channel via Bot API.
//
// Canon: #0 (rules first, LLM last), #3 (single-purpose node),
//        #5 (deterministic skill, fail loud), #11 (no bot write privilege
//        beyond channel forward).

import 'dotenv/config';
import fs from 'node:fs';
import Database from 'better-sqlite3';
import Anthropic from '@anthropic-ai/sdk';

const REQUIRED_ENV = ['ANTHROPIC_API_KEY', 'BOT_TOKEN', 'CHANNEL_CHAT_ID'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(JSON.stringify({ level: 'fatal', msg: 'missing_env', key }));
    process.exit(1);
  }
}

const APP_DIR = '/opt/personal-assistant';
const DB_PATH = process.env.DB_PATH || `${APP_DIR}/assistant.db`;
const SKILL_PATH = process.env.SKILL_PATH || `${APP_DIR}/skills/triage.md`;
const POLL_INTERVAL_MS = parseInt(process.env.TRIAGE_POLL_MS || '2000', 10);
const MODEL = process.env.TRIAGE_MODEL || 'claude-sonnet-4-6';
const MAX_TOKENS = 200;
const BUDGET_CAP_USD = parseFloat(process.env.MONTHLY_BUDGET_USD || '22');

const log = (level, msg, extra = {}) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...extra }));

if (!fs.existsSync(SKILL_PATH)) {
  console.error(JSON.stringify({ level: 'fatal', msg: 'skill_missing', path: SKILL_PATH }));
  process.exit(1);
}
const skillSystemPrompt = fs.readFileSync(SKILL_PATH, 'utf8');

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const selectPending = db.prepare(`
  SELECT id, tg_msg_id, chat_id, from_id, text, received_at
  FROM messages
  WHERE handled = 0
  ORDER BY received_at ASC
  LIMIT 1
`);

const selectContact = db.prepare(`
  SELECT tg_id, name, username, msg_count_30d, is_vip
  FROM contacts
  WHERE tg_id = ?
`);

const selectRecentForContact = db.prepare(`
  SELECT text
  FROM messages
  WHERE from_id = ? AND id < ? AND handled = 1
  ORDER BY id DESC
  LIMIT 3
`);

const updateMessage = db.prepare(`
  UPDATE messages
  SET category = ?, urgent = ?, handled = 1
  WHERE id = ?
`);

const updateContactPriority = db.prepare(`
  UPDATE contacts
  SET priority = ?
  WHERE tg_id = ?
`);

const insertBudget = db.prepare(`
  INSERT INTO budget_log (date, input_tokens, output_tokens, cost_usd, operation)
  VALUES (date('now'), ?, ?, ?, 'triage')
`);

const monthlySpend = db.prepare(`
  SELECT COALESCE(SUM(cost_usd), 0) AS total
  FROM budget_log
  WHERE date >= date('now', 'start of month')
`);

const URGENT_RX = /срочно|help|asap|urgent|\?/i;
const VALID_CATEGORIES = new Set(['question', 'fyi', 'promo', 'social', 'spam']);

const PRIORITY_TAGS = {
  hot: '🔥 HOT',
  regular: '👥 REGULAR',
  new: '🆕 NEW',
  noise: '🗑 NOISE'
};

function computePriority(msgCount30d) {
  if (msgCount30d > 10) return 'hot';
  if (msgCount30d > 3) return 'regular';
  return 'new';
}

function isLikelyBotOrChannel(contact) {
  if (!contact) return false;
  return /bot$/i.test(contact.username || '');
}

function priceUsd(inputTokens, cacheReadTokens, cacheCreationTokens, outputTokens) {
  // Anthropic Sonnet 4.6 approximate pricing per 1M tokens:
  //   uncached input  $3.00, cache create $3.75 (1.25x), cache read $0.30 (0.1x),
  //   output         $15.00.
  const inCost = (inputTokens / 1e6) * 3.0;
  const cacheCreateCost = (cacheCreationTokens / 1e6) * 3.75;
  const cacheReadCost = (cacheReadTokens / 1e6) * 0.3;
  const outCost = (outputTokens / 1e6) * 15.0;
  return inCost + cacheCreateCost + cacheReadCost + outCost;
}

function formatTimeIso(rawTs) {
  // received_at stored as 'YYYY-MM-DD HH:MM:SS' in UTC by SQLite default.
  const isoLike = String(rawTs).replace(' ', 'T') + 'Z';
  const d = new Date(isoLike);
  if (Number.isNaN(d.getTime())) return '--:--';
  return d.toISOString().substring(11, 16);
}

async function forwardTagged(message, contact, priority, urgent, category) {
  const tag = PRIORITY_TAGS[priority] || '';
  const urgentTag = urgent ? '🚨 URGENT ' : '';
  const catTag = category ? `[${category}] ` : '';
  const time = formatTimeIso(message.received_at);
  const name = contact?.name || `id:${message.from_id}`;
  const text = (message.text || '').replace(/\n/g, ' ').slice(0, 400);
  const body = `📩 ${time} ${urgentTag}${tag} ${catTag}from ${name}: ${text}`;
  const url = `https://api.telegram.org/bot${process.env.BOT_TOKEN}/sendMessage`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: process.env.CHANNEL_CHAT_ID,
      text: body,
      disable_web_page_preview: true
    })
  });
  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`bot_api_error status=${resp.status} body=${t}`);
  }
}

async function classifyWithSonnet(message, contact) {
  const recent = selectRecentForContact.all(message.from_id, message.id);
  const userText = JSON.stringify({
    text: message.text || '',
    sender: contact?.name || `id:${message.from_id}`,
    is_vip: !!contact?.is_vip,
    msg_count_30d: contact?.msg_count_30d || 0,
    recent_history: recent.map((r) => r.text).slice(0, 3)
  });

  const resp = await anthropic.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    temperature: 0.0,
    system: [
      {
        type: 'text',
        text: skillSystemPrompt,
        cache_control: { type: 'ephemeral' }
      }
    ],
    messages: [{ role: 'user', content: userText }]
  });

  const inputTokens = resp.usage?.input_tokens || 0;
  const outputTokens = resp.usage?.output_tokens || 0;
  const cacheReadTokens = resp.usage?.cache_read_input_tokens || 0;
  const cacheCreationTokens = resp.usage?.cache_creation_input_tokens || 0;
  const cost = priceUsd(inputTokens, cacheReadTokens, cacheCreationTokens, outputTokens);

  const textBlock = resp.content?.find((c) => c.type === 'text')?.text || '{}';
  let parsed = { category: 'fyi', confidence: 0.0 };
  try {
    const jsonMatch = textBlock.match(/\{[\s\S]*\}/);
    parsed = JSON.parse(jsonMatch ? jsonMatch[0] : textBlock);
  } catch {
    log('warn', 'json_parse_failed', { raw: textBlock.slice(0, 200) });
  }
  if (!VALID_CATEGORIES.has(parsed.category)) {
    log('warn', 'invalid_category', { got: parsed.category });
    parsed.category = 'fyi';
  }
  return {
    category: parsed.category,
    cost,
    inputTokens: inputTokens + cacheReadTokens + cacheCreationTokens,
    outputTokens
  };
}

async function processOne() {
  const msg = selectPending.get();
  if (!msg) return false;

  const spent = monthlySpend.get().total;
  if (spent >= BUDGET_CAP_USD) {
    log('error', 'budget_cap_exceeded', { spent, cap: BUDGET_CAP_USD });
    return false;
  }

  const contact = selectContact.get(msg.from_id);
  const priority = computePriority(contact?.msg_count_30d || 0);
  const isVipUrgent = !!contact?.is_vip && URGENT_RX.test(msg.text || '');

  let category = 'fyi';
  let urgent = isVipUrgent ? 1 : 0;
  let llmCost = 0;

  if (isLikelyBotOrChannel(contact)) {
    category = 'spam';
  } else {
    const result = await classifyWithSonnet(msg, contact);
    category = result.category;
    llmCost = result.cost;
    insertBudget.run(result.inputTokens, result.outputTokens, result.cost);
  }

  const finalPriority = category === 'spam' ? 'noise' : priority;

  updateMessage.run(category, urgent, msg.id);
  updateContactPriority.run(finalPriority, msg.from_id);

  await forwardTagged(msg, contact, finalPriority, urgent, category);

  log('info', 'message_classified', {
    msg_id: msg.id,
    category,
    priority: finalPriority,
    urgent,
    cost_usd: Number(llmCost.toFixed(6))
  });
  return true;
}

let stopping = false;
async function loop() {
  while (!stopping) {
    try {
      const did = await processOne();
      if (!did) {
        await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
      }
    } catch (err) {
      log('error', 'process_failed', {
        error: String(err?.message || err),
        stack: err?.stack
      });
      await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
    }
  }
}

process.on('SIGTERM', () => {
  stopping = true;
  log('info', 'shutdown', { signal: 'SIGTERM' });
});
process.on('SIGINT', () => {
  stopping = true;
  log('info', 'shutdown', { signal: 'SIGINT' });
});

log('info', 'triage_starting', { db: DB_PATH, model: MODEL, poll_ms: POLL_INTERVAL_MS });
loop().catch((err) => {
  log('fatal', 'loop_crashed', { error: String(err?.message || err) });
  process.exit(1);
});
