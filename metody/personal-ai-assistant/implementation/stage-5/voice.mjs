// voice.mjs — Stage 5: voice command worker.
// Polls voice_jobs table (populated by bot.mjs when owner sends voice msg),
// transcribes via Grok STT, parses intent via Sonnet, dispatches action.
// Canon: #0 (rules-first dispatch), #3 (single-purpose), #5 (deterministic
//        skill, fail loud), #11 (no MTProto write here — only DB + channel).

import fs from 'node:fs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import Database from 'better-sqlite3';
import Anthropic from '@anthropic-ai/sdk';
import { getSecret } from '../stage-0.5/lib/vault.mjs';

const execFileP = promisify(execFile);

// Check non-secret env vars (secrets loaded via vault.mjs)
const REQUIRED_ENV = ['BOT_TOKEN', 'CHANNEL_CHAT_ID'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(JSON.stringify({ level: 'fatal', msg: 'missing_env', key }));
    process.exit(1);
  }
}

const APP_DIR = '/opt/personal-assistant';
const DB_PATH = process.env.DB_PATH || `${APP_DIR}/assistant.db`;
const SKILL_PATH = process.env.VOICE_SKILL_PATH || `${APP_DIR}/skills/voice_intent.md`;
const POLL_INTERVAL_MS = parseInt(process.env.VOICE_POLL_MS || '3000', 10);
const MODEL = process.env.VOICE_MODEL || 'claude-sonnet-4-6';
const MAX_TOKENS = 400;
const BUDGET_CAP_USD = parseFloat(process.env.MONTHLY_BUDGET_USD || '22');
const TRANSCRIBE_SCRIPT = process.env.TRANSCRIBE_SCRIPT || `${APP_DIR}/transcribe.sh`;
const VOICE_TMP_DIR = process.env.VOICE_TMP_DIR || '/tmp/pa-voice';

const log = (level, msg, extra = {}) =>
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...extra }));

if (!fs.existsSync(SKILL_PATH)) {
  console.error(JSON.stringify({ level: 'fatal', msg: 'voice_skill_missing', path: SKILL_PATH }));
  process.exit(1);
}
if (!fs.existsSync(TRANSCRIBE_SCRIPT)) {
  console.error(JSON.stringify({ level: 'fatal', msg: 'transcribe_missing', path: TRANSCRIBE_SCRIPT }));
  process.exit(1);
}
fs.mkdirSync(VOICE_TMP_DIR, { recursive: true });

// Load secrets from systemd credentials (Canon #6)
const ANTHROPIC_API_KEY = await getSecret('anthropic-api-key');
const GROK_API_KEY = await getSecret('xai-api-key');

const skillSystemPrompt = fs.readFileSync(SKILL_PATH, 'utf8');
const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS voice_jobs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id         TEXT NOT NULL,
    file_path       TEXT,
    received_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transcript      TEXT,
    intent          TEXT,
    args_json       TEXT,
    action_result   TEXT,
    status          TEXT DEFAULT 'pending',
    error           TEXT
  );
`);

const selectPending = db.prepare(`
  SELECT id, file_id, file_path FROM voice_jobs
  WHERE status = 'pending' ORDER BY received_at ASC LIMIT 1
`);
const updateJobTranscript = db.prepare(`
  UPDATE voice_jobs SET transcript = ?, status = 'transcribed' WHERE id = ?
`);
const updateJobIntent = db.prepare(`
  UPDATE voice_jobs SET intent = ?, args_json = ?, status = 'parsed' WHERE id = ?
`);
const updateJobDone = db.prepare(`
  UPDATE voice_jobs SET action_result = ?, status = 'done' WHERE id = ?
`);
const updateJobFailed = db.prepare(`
  UPDATE voice_jobs SET error = ?, status = 'failed' WHERE id = ?
`);
const insertBudget = db.prepare(`
  INSERT INTO budget_log (date, input_tokens, output_tokens, cost_usd, operation)
  VALUES (date('now'), ?, ?, ?, 'voice_intent')
`);
const monthlySpend = db.prepare(`
  SELECT COALESCE(SUM(cost_usd), 0) AS total FROM budget_log
  WHERE date >= date('now', 'start of month')
`);

const insertDraft = db.prepare(`
  INSERT INTO drafts (msg_id, draft_text, verdict, final_text, feedback_note)
  VALUES (NULL, ?, 'pending', NULL, ?)
`);
const insertRule = db.prepare(`
  INSERT INTO rules (scope, scope_id, action, note)
  VALUES ('contact', ?, ?, 'voice_command')
`);
const findContactByName = db.prepare(`
  SELECT tg_id, name, username FROM contacts
  WHERE name LIKE ? OR username LIKE ?
  ORDER BY last_msg_at DESC LIMIT 5
`);
const ftsSearch = db.prepare(`
  SELECT m.id, m.text, m.received_at, c.name AS contact_name
  FROM messages_fts f
  JOIN messages m ON m.id = f.rowid
  LEFT JOIN contacts c ON c.tg_id = m.from_id
  WHERE messages_fts MATCH ?
  ORDER BY m.received_at DESC LIMIT 5
`);

function priceUsd(inTok, cacheRead, cacheCreate, outTok) {
  return (inTok / 1e6) * 3.0 + (cacheCreate / 1e6) * 3.75 + (cacheRead / 1e6) * 0.3 + (outTok / 1e6) * 15.0;
}

async function transcribe(filePath) {
  const { stdout } = await execFileP('bash', [TRANSCRIBE_SCRIPT, filePath, 'ru'], {
    timeout: 60000,
    env: { ...process.env, GROK_API_KEY }
  });
  return stdout.trim();
}

async function parseIntent(transcript) {
  const resp = await anthropic.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    temperature: 0.0,
    system: [{ type: 'text', text: skillSystemPrompt, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: transcript }]
  });
  const u = resp.usage || {};
  const cost = priceUsd(
    u.input_tokens || 0,
    u.cache_read_input_tokens || 0,
    u.cache_creation_input_tokens || 0,
    u.output_tokens || 0
  );
  insertBudget.run(
    (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0),
    u.output_tokens || 0,
    cost
  );
  const text = resp.content?.find((c) => c.type === 'text')?.text || '{}';
  let parsed = { intent: 'unknown', args: {} };
  try {
    const m = text.match(/\{[\s\S]*\}/);
    parsed = JSON.parse(m ? m[0] : text);
  } catch {
    log('warn', 'voice_intent_parse_failed', { raw: text.slice(0, 200) });
  }
  return parsed;
}

async function postToChannel(text) {
  const url = `https://api.telegram.org/bot${process.env.BOT_TOKEN}/sendMessage`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: process.env.CHANNEL_CHAT_ID,
      text,
      disable_web_page_preview: true
    })
  });
  if (!resp.ok) throw new Error(`bot_api_error ${resp.status}`);
}

async function actAnswer(args) {
  if (!args.contact || !args.text) return 'missing_args';
  const candidates = findContactByName.all(`%${args.contact}%`, `%${args.contact}%`);
  if (!candidates.length) {
    await postToChannel(`🎙 «Ответь»: контакт "${args.contact}" не найден`);
    return 'contact_not_found';
  }
  insertDraft.run(args.text, `voice_command:answer:${candidates[0].tg_id}`);
  await postToChannel(`🎙 Draft для ${candidates[0].name}:\n${args.text}`);
  return 'draft_created';
}

async function actRule(args) {
  if (!args.contact || !args.action) return 'missing_args';
  const candidates = findContactByName.all(`%${args.contact}%`, `%${args.contact}%`);
  const scopeId = candidates.length ? String(candidates[0].tg_id) : args.contact;
  insertRule.run(scopeId, args.action);
  await postToChannel(`🎙 Правило: ${args.contact} → ${args.action}`);
  return 'rule_inserted';
}

async function actSearch(args) {
  if (!args.query) return 'missing_args';
  const rows = ftsSearch.all(args.query);
  if (!rows.length) {
    await postToChannel(`🎙 Поиск «${args.query}»: ничего не найдено`);
    return 'no_results';
  }
  const lines = rows.map((r) =>
    `• [${r.received_at}] ${r.contact_name || 'unknown'}: ${(r.text || '').slice(0, 100)}`
  );
  await postToChannel(`🎙 Поиск «${args.query}» — top ${rows.length}:\n${lines.join('\n')}`);
  return `found_${rows.length}`;
}

async function actBackfill(args) {
  if (!args.contact) return 'missing_args';
  await postToChannel(`🎙 Backfill «${args.contact}»: запрос принят, MTProto-fetch в фоне (Stage 5.1 follow-up)`);
  return 'backfill_queued';
}

async function dispatch(intent, args) {
  switch (intent) {
    case 'answer':   return await actAnswer(args);
    case 'rule':     return await actRule(args);
    case 'search':   return await actSearch(args);
    case 'backfill': return await actBackfill(args);
    default:         return 'unknown_intent';
  }
}

async function processOne() {
  const job = selectPending.get();
  if (!job) return false;

  const spent = monthlySpend.get().total;
  if (spent >= BUDGET_CAP_USD) {
    log('error', 'budget_cap_exceeded', { spent, cap: BUDGET_CAP_USD });
    return false;
  }

  try {
    const transcript = await transcribe(job.file_path);
    updateJobTranscript.run(transcript, job.id);
    log('info', 'voice_transcribed', { job_id: job.id, len: transcript.length });

    const parsed = await parseIntent(transcript);
    updateJobIntent.run(parsed.intent || 'unknown', JSON.stringify(parsed.args || {}), job.id);
    log('info', 'voice_intent_parsed', { job_id: job.id, intent: parsed.intent });

    const result = await dispatch(parsed.intent, parsed.args || {});
    updateJobDone.run(result, job.id);
    log('info', 'voice_handled', { job_id: job.id, result });
  } catch (err) {
    updateJobFailed.run(String(err?.message || err), job.id);
    log('error', 'voice_failed', { job_id: job.id, error: String(err?.message || err) });
    try {
      await postToChannel(`🎙 Voice processing failed: ${String(err?.message || err).slice(0, 200)}`);
    } catch {}
  }
  return true;
}

let stopping = false;
async function loop() {
  while (!stopping) {
    try {
      const did = await processOne();
      if (!did) await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
    } catch (err) {
      log('error', 'loop_error', { error: String(err?.message || err) });
      await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
    }
  }
}

process.on('SIGTERM', () => { stopping = true; log('info', 'shutdown', { signal: 'SIGTERM' }); });
process.on('SIGINT', () => { stopping = true; log('info', 'shutdown', { signal: 'SIGINT' }); });

log('info', 'voice_starting', { db: DB_PATH, poll_ms: POLL_INTERVAL_MS });
loop().catch((err) => {
  log('fatal', 'main_crashed', { error: String(err?.message || err) });
  process.exit(1);
});
