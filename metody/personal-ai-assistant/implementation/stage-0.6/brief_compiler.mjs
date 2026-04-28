// brief_compiler.mjs — Stage 3.5: oneshot brief compiler.
// Triggered by systemd timer 3×/day. Reads classified messages from the
// last LOOKBACK_HOURS, groups by priority/category, generates one digest
// via Sonnet 4.6, posts to AI Assistant channel.
//
// Canon: #0 (rules-first grouping, LLM only for prose),
//        #3 (single-purpose oneshot),
//        #5 (deterministic skill, fail loud).

import fs from 'node:fs';
import Database from 'better-sqlite3';
import Anthropic from '@anthropic-ai/sdk';
import { getSecret } from './lib/vault.mjs';

const REQUIRED_ENV = ['CHANNEL_CHAT_ID'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(JSON.stringify({ level: 'fatal', msg: 'missing_env', key }));
    process.exit(1);
  }
}

const ANTHROPIC_API_KEY = getSecret('anthropic-api-key');
const BOT_TOKEN = getSecret('bot-token');

const APP_DIR = '/opt/personal-assistant';
const DB_PATH = process.env.DB_PATH || `${APP_DIR}/assistant.db`;
const SKILL_PATH = process.env.BRIEF_SKILL_PATH || `${APP_DIR}/skills/brief.md`;
const MODEL = process.env.BRIEF_MODEL || 'claude-sonnet-4-6';
const MAX_TOKENS = 1500;
const BRIEF_TYPE = process.env.BRIEF_TYPE || 'auto';
const LOOKBACK_HOURS = parseFloat(process.env.BRIEF_LOOKBACK_HOURS || '5');
const BUDGET_CAP_USD = parseFloat(process.env.MONTHLY_BUDGET_USD || '22');

const log = (level, msg, extra = {}) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...extra }));

if (!fs.existsSync(SKILL_PATH)) {
  console.error(JSON.stringify({ level: 'fatal', msg: 'brief_skill_missing', path: SKILL_PATH }));
  process.exit(1);
}
const skillSystemPrompt = fs.readFileSync(SKILL_PATH, 'utf8');

const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const selectMessagesInWindow = db.prepare(`
  SELECT m.id, m.text, m.category, m.urgent, m.received_at,
         c.name AS contact_name, c.priority
  FROM messages m
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE m.received_at >= datetime('now', ?)
    AND m.handled = 1
  ORDER BY m.received_at ASC
`);

const insertBrief = db.prepare(`
  INSERT INTO briefs (brief_type, content, msg_count)
  VALUES (?, ?, ?)
`);

const insertBudget = db.prepare(`
  INSERT INTO budget_log (date, input_tokens, output_tokens, cost_usd, operation)
  VALUES (date('now'), ?, ?, ?, 'brief')
`);

const monthlySpend = db.prepare(`
  SELECT COALESCE(SUM(cost_usd), 0) AS total
  FROM budget_log
  WHERE date >= date('now', 'start of month')
`);

function priceUsd(inputTokens, cacheReadTokens, cacheCreationTokens, outputTokens) {
  const inCost = (inputTokens / 1e6) * 3.0;
  const cacheCreateCost = (cacheCreationTokens / 1e6) * 3.75;
  const cacheReadCost = (cacheReadTokens / 1e6) * 0.3;
  const outCost = (outputTokens / 1e6) * 15.0;
  return inCost + cacheCreateCost + cacheReadCost + outCost;
}

function determineBriefType() {
  if (BRIEF_TYPE !== 'auto') return BRIEF_TYPE;
  const hour = new Date().getHours();
  if (hour >= 6 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  return 'evening';
}

function groupMessages(messages) {
  const groups = {
    hot_urgent: [],
    hot: [],
    regular: [],
    new: [],
    noise_count: 0
  };
  for (const m of messages) {
    if (m.priority === 'noise' || m.category === 'spam' || m.category === 'promo') {
      groups.noise_count++;
      continue;
    }
    if (m.urgent && m.priority === 'hot') {
      groups.hot_urgent.push(m);
    } else if (m.priority === 'hot') {
      groups.hot.push(m);
    } else if (m.priority === 'regular') {
      groups.regular.push(m);
    } else {
      groups.new.push(m);
    }
  }
  return groups;
}

async function generateBrief(briefType, groups, totalCount) {
  const userText = JSON.stringify({
    brief_type: briefType,
    window_hours: LOOKBACK_HOURS,
    total_messages: totalCount,
    hot_urgent: groups.hot_urgent.map((m) => ({
      from: m.contact_name,
      text: (m.text || '').slice(0, 200),
      time: m.received_at
    })),
    hot: groups.hot.map((m) => ({
      from: m.contact_name,
      text: (m.text || '').slice(0, 150)
    })),
    regular_count: groups.regular.length,
    regular_senders: [...new Set(groups.regular.map((m) => m.contact_name).filter(Boolean))].slice(0, 10),
    new_count: groups.new.length,
    new_senders: [...new Set(groups.new.map((m) => m.contact_name).filter(Boolean))].slice(0, 5),
    noise_count: groups.noise_count
  });

  const resp = await anthropic.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    temperature: 0.3,
    system: [
      {
        type: 'text',
        text: skillSystemPrompt,
        cache_control: { type: 'ephemeral' }
      }
    ],
    messages: [{ role: 'user', content: userText }]
  });

  const u = resp.usage || {};
  const inputTokens = u.input_tokens || 0;
  const outputTokens = u.output_tokens || 0;
  const cacheReadTokens = u.cache_read_input_tokens || 0;
  const cacheCreationTokens = u.cache_creation_input_tokens || 0;
  const cost = priceUsd(inputTokens, cacheReadTokens, cacheCreationTokens, outputTokens);

  const text = resp.content?.find((c) => c.type === 'text')?.text || '';
  return {
    text,
    cost,
    inputTokens: inputTokens + cacheReadTokens + cacheCreationTokens,
    outputTokens
  };
}

async function postToChannel(text) {
  const url = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: process.env.CHANNEL_CHAT_ID,
      text,
      disable_web_page_preview: true
    })
  });
  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`bot_api_error status=${resp.status} body=${t}`);
  }
}

async function main() {
  const briefType = determineBriefType();
  log('info', 'brief_starting', { brief_type: briefType, lookback_h: LOOKBACK_HOURS });

  const spent = monthlySpend.get().total;
  if (spent >= BUDGET_CAP_USD) {
    log('error', 'budget_cap_exceeded', { spent, cap: BUDGET_CAP_USD });
    process.exit(1);
  }

  const sinceArg = `-${LOOKBACK_HOURS} hours`;
  const messages = selectMessagesInWindow.all(sinceArg);

  if (messages.length === 0) {
    log('info', 'no_messages_in_window', { brief_type: briefType });
    process.exit(0);
  }

  const groups = groupMessages(messages);
  const result = await generateBrief(briefType, groups, messages.length);

  await postToChannel(result.text);

  insertBrief.run(briefType, result.text, messages.length);
  insertBudget.run(result.inputTokens, result.outputTokens, result.cost);

  log('info', 'brief_posted', {
    brief_type: briefType,
    msg_count: messages.length,
    cost_usd: Number(result.cost.toFixed(6))
  });
}

main().catch((err) => {
  log('fatal', 'brief_failed', { error: String(err?.message || err), stack: err?.stack });
  process.exit(1);
});
