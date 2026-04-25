#!/usr/bin/env node
/**
 * Personal AI Assistant — Stage 2: Triage Worker
 *
 * Classifies incoming messages by category and urgency.
 * Rules-first approach (Canon #0 Simplicity First), LLM only when needed.
 * Prompt caching on system skill (Anthropic SDK native, Canon #2 Minimal Integration).
 *
 * Runs continuously, polls messages table for unprocessed entries.
 */

import Database from 'better-sqlite3';
import Anthropic from '@anthropic-ai/sdk';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import 'dotenv/config';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration from .env (Canon #6 Single Vault)
const DB_PATH = process.env.DB_PATH || '/opt/personal-assistant/assistant.db';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const POLL_INTERVAL_MS = parseInt(process.env.TRIAGE_POLL_INTERVAL_MS || '5000', 10);
const MODEL = 'claude-sonnet-4-6';

if (!ANTHROPIC_API_KEY) {
  console.error('[FATAL] ANTHROPIC_API_KEY not set in .env');
  process.exit(1);
}

const db = new Database(DB_PATH);
const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

// Load skill (cached system prompt)
const skillPath = join(__dirname, 'skills', 'triage.md');
let SKILL_CONTENT;
try {
  SKILL_CONTENT = readFileSync(skillPath, 'utf-8');
} catch (err) {
  console.error(`[FATAL] Cannot read skill: ${skillPath}`, err);
  process.exit(1);
}

/**
 * Rule-based classification (no LLM call)
 * Canon #0 Simplicity First: deterministic rules before expensive API
 */
function applyRules(message, contact) {
  // Rule 1: Bot or channel messages → noise
  if (contact.is_bot || message.is_channel) {
    return { category: 'noise', urgent: false, reason: 'bot/channel message', skip_llm: true };
  }

  // Rule 2: VIP urgent keywords
  const urgentKeywords = ['срочно', 'urgent', 'asap', 'help', 'sos', 'важно'];
  const hasUrgentKeyword = urgentKeywords.some(kw =>
    message.text.toLowerCase().includes(kw)
  );

  if (contact.is_vip && hasUrgentKeyword) {
    return { category: 'question', urgent: true, reason: 'VIP + urgent keyword', skip_llm: false };
  }

  // No rules matched → need LLM
  return { skip_llm: false };
}

/**
 * Call Anthropic API with skill (prompt caching enabled)
 * Canon #2 Minimal Integration: direct SDK, no LiteLLM
 */
async function classifyWithLLM(message, contact) {
  const input = {
    from_name: contact.name || 'Unknown',
    text: message.text,
    context: {
      msg_count_30d: contact.msg_count_30d || 0,
      is_vip: Boolean(contact.is_vip),
      priority: contact.priority || 'new',
      notes: contact.notes || null
    }
  };

  try {
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 100,
      system: [
        {
          type: 'text',
          text: SKILL_CONTENT,
          cache_control: { type: 'ephemeral' } // Prompt caching (reduces cost ~90%)
        }
      ],
      messages: [
        {
          role: 'user',
          content: JSON.stringify(input)
        }
      ]
    });

    const rawOutput = response.content[0].text.trim();

    // Parse JSON output
    let result;
    try {
      result = JSON.parse(rawOutput);
    } catch (parseErr) {
      console.error('[WARN] LLM output not valid JSON:', rawOutput);
      return { category: 'fyi', urgent: false, reason: 'parse error' };
    }

    // Log budget (Canon #5 Fail Loud on budget overrun)
    const inputTokens = response.usage.input_tokens;
    const outputTokens = response.usage.output_tokens;
    const cachedTokens = response.usage.cache_read_input_tokens || 0;

    // Sonnet 4.6 pricing (as of 2026-04)
    // Input: $3/MTok, Output: $15/MTok, Cached: $0.30/MTok
    const cost = (
      (inputTokens - cachedTokens) * 3 / 1_000_000 +
      cachedTokens * 0.30 / 1_000_000 +
      outputTokens * 15 / 1_000_000
    );

    db.prepare(`
      INSERT INTO budget_log (date, input_tokens, output_tokens, cost_usd, operation)
      VALUES (DATE('now'), ?, ?, ?, 'triage')
    `).run(inputTokens, outputTokens, cost);

    console.log(`[LLM] msg_id=${message.id} tokens=${inputTokens}/${outputTokens} cached=${cachedTokens} cost=$${cost.toFixed(4)}`);

    return result;

  } catch (apiErr) {
    console.error('[ERROR] Anthropic API call failed:', apiErr.message);
    // Fallback: classify as fyi, not urgent (Canon #5 Fail Loud)
    return { category: 'fyi', urgent: false, reason: 'API error' };
  }
}

/**
 * Process one unhandled message
 */
async function processMessage(message) {
  // Get contact info
  const contact = db.prepare(`
    SELECT tg_id, name, username, msg_count_30d, priority, is_vip, notes, tone
    FROM contacts
    WHERE tg_id = ?
  `).get(message.from_id);

  if (!contact) {
    console.warn(`[WARN] Contact not found for from_id=${message.from_id}, skipping message ${message.id}`);
    return;
  }

  // Apply rules first
  const ruleResult = applyRules(message, contact);

  let classification;
  if (ruleResult.skip_llm) {
    classification = ruleResult;
  } else if (ruleResult.category) {
    // Rule provided category but didn't skip LLM (partial match)
    classification = ruleResult;
  } else {
    // Need LLM classification
    classification = await classifyWithLLM(message, contact);
  }

  // Update message with classification
  db.prepare(`
    UPDATE messages
    SET category = ?, urgent = ?, handled = 1
    WHERE id = ?
  `).run(classification.category, classification.urgent ? 1 : 0, message.id);

  const urgentFlag = classification.urgent ? '🚨' : '  ';
  const categoryEmoji = {
    question: '❓',
    fyi: 'ℹ️',
    promo: '📢',
    social: '💬',
    spam: '🗑',
    noise: '🔇'
  }[classification.category] || '  ';

  console.log(`[TRIAGE] ${urgentFlag} ${categoryEmoji} msg_id=${message.id} from="${contact.name}" category=${classification.category} reason="${classification.reason}"`);
}

/**
 * Main polling loop
 * Canon #3 Simple Nodes: one task = poll and classify
 */
async function main() {
  console.log(`[START] Triage worker started`);
  console.log(`[CONFIG] DB=${DB_PATH} model=${MODEL} poll_interval=${POLL_INTERVAL_MS}ms`);
  console.log(`[SKILL] Loaded from ${skillPath} (${SKILL_CONTENT.length} chars)`);

  while (true) {
    try {
      // Find unprocessed messages (category IS NULL means not triaged yet)
      const messages = db.prepare(`
        SELECT id, tg_msg_id, chat_id, from_id, text, received_at, 0 as is_channel
        FROM messages
        WHERE category IS NULL
        ORDER BY received_at ASC
        LIMIT 10
      `).all();

      if (messages.length > 0) {
        console.log(`[POLL] Found ${messages.length} unprocessed message(s)`);

        for (const msg of messages) {
          await processMessage(msg);
        }
      }

      // Sleep before next poll
      await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL_MS));

    } catch (err) {
      console.error('[ERROR] Main loop error:', err);
      // Sleep longer on error to avoid tight error loop
      await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL_MS * 3));
    }
  }
}

// Graceful shutdown (Canon #5 Fail Loud)
process.on('SIGTERM', () => {
  console.log('[SHUTDOWN] SIGTERM received, closing DB');
  db.close();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('[SHUTDOWN] SIGINT received, closing DB');
  db.close();
  process.exit(0);
});

main().catch(err => {
  console.error('[FATAL] Unhandled error in main:', err);
  process.exit(1);
});
