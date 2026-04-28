// router-cascade.mjs — Stage 2.5 (RESERVE, NOT DEPLOYED)
//
// Cascade router for triage classification:
//   1. Try Haiku 4.5 (fast, cheap)
//   2. If parse fails OR confidence < threshold → fallback to Sonnet 4.6
//
// Drop-in helper for triage.mjs. Activate via CASCADE_ENABLED=1 in .env.
// See README-RESERVE.md in this directory for activation procedure.
//
// Canon: #0 (rules first stays in triage.mjs, this only handles LLM step),
//        #3 (single-purpose: route + classify),
//        #4 (one skill per model),
//        #5 (deterministic, fail-loud parse → auto-fallback to Sonnet).

import fs from 'node:fs';
import Anthropic from '@anthropic-ai/sdk';

const HAIKU_MODEL = process.env.HAIKU_MODEL || 'claude-haiku-4-5-20251001';
const SONNET_MODEL = process.env.TRIAGE_MODEL || 'claude-sonnet-4-6';
const MAX_TOKENS = 200;
const FALLBACK_THRESHOLD = parseFloat(process.env.CASCADE_FALLBACK_THRESHOLD || '0.7');
const HAIKU_SKILL_PATH = process.env.HAIKU_SKILL_PATH || '/opt/personal-assistant/skills/triage-haiku.md';
const SONNET_SKILL_PATH = process.env.SKILL_PATH || '/opt/personal-assistant/skills/triage.md';
const VALID_CATEGORIES = new Set(['question', 'fyi', 'promo', 'social', 'spam']);

for (const p of [HAIKU_SKILL_PATH, SONNET_SKILL_PATH]) {
  if (!fs.existsSync(p)) {
    console.error(JSON.stringify({ level: 'fatal', msg: 'cascade_skill_missing', path: p }));
    process.exit(1);
  }
}

const haikuPrompt = fs.readFileSync(HAIKU_SKILL_PATH, 'utf8');
const sonnetPrompt = fs.readFileSync(SONNET_SKILL_PATH, 'utf8');

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

function priceUsd(model, inputTokens, cacheReadTokens, cacheCreationTokens, outputTokens) {
  // Haiku 4.5  : input $1.00 / cache-create $1.25 / cache-read $0.10 / output $5.00 per MTok
  // Sonnet 4.6 : input $3.00 / cache-create $3.75 / cache-read $0.30 / output $15.00 per MTok
  const rates = model.startsWith('claude-haiku')
    ? { in: 1.0, cacheCreate: 1.25, cacheRead: 0.1, out: 5.0 }
    : { in: 3.0, cacheCreate: 3.75, cacheRead: 0.3, out: 15.0 };
  return (
    (inputTokens / 1e6) * rates.in +
    (cacheCreationTokens / 1e6) * rates.cacheCreate +
    (cacheReadTokens / 1e6) * rates.cacheRead +
    (outputTokens / 1e6) * rates.out
  );
}

function parseClassification(textBlock) {
  try {
    const jsonMatch = textBlock.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : textBlock);
    if (!VALID_CATEGORIES.has(parsed.category)) {
      return { category: null, confidence: 0.0, parseError: true };
    }
    const confidence = typeof parsed.confidence === 'number' ? parsed.confidence : 0.0;
    return { category: parsed.category, confidence, parseError: false };
  } catch {
    return { category: null, confidence: 0.0, parseError: true };
  }
}

async function callModel(model, systemPrompt, userText) {
  const resp = await anthropic.messages.create({
    model,
    max_tokens: MAX_TOKENS,
    temperature: 0.0,
    system: [{ type: 'text', text: systemPrompt, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: userText }]
  });
  const u = resp.usage || {};
  const inputTokens = u.input_tokens || 0;
  const outputTokens = u.output_tokens || 0;
  const cacheReadTokens = u.cache_read_input_tokens || 0;
  const cacheCreationTokens = u.cache_creation_input_tokens || 0;
  const cost = priceUsd(model, inputTokens, cacheReadTokens, cacheCreationTokens, outputTokens);
  const textBlock = resp.content?.find((c) => c.type === 'text')?.text || '{}';
  return {
    parsed: parseClassification(textBlock),
    cost,
    inputTokens: inputTokens + cacheReadTokens + cacheCreationTokens,
    outputTokens
  };
}

/**
 * Cascade-classify a Telegram message.
 *
 * @param {string} userText  Pre-built JSON string with text/sender/is_vip/
 *                           msg_count_30d/recent_history (same shape as in
 *                           triage.mjs `classifyWithSonnet`).
 * @returns {Promise<{
 *   category: string,
 *   confidence: number,
 *   cost: number,
 *   inputTokens: number,
 *   outputTokens: number,
 *   operation: 'triage_haiku' | 'triage_sonnet_fallback',
 *   route: 'haiku' | 'sonnet_fallback',
 *   fallbackReason?: string
 * }>}
 */
export async function classifyWithCascade(userText) {
  // Stage 1 — Haiku attempt
  const haiku = await callModel(HAIKU_MODEL, haikuPrompt, userText);
  const haikuOk = !haiku.parsed.parseError && haiku.parsed.confidence >= FALLBACK_THRESHOLD;

  if (haikuOk) {
    return {
      category: haiku.parsed.category,
      confidence: haiku.parsed.confidence,
      cost: haiku.cost,
      inputTokens: haiku.inputTokens,
      outputTokens: haiku.outputTokens,
      operation: 'triage_haiku',
      route: 'haiku'
    };
  }

  // Stage 2 — Sonnet fallback
  const sonnet = await callModel(SONNET_MODEL, sonnetPrompt, userText);
  return {
    category: sonnet.parsed.category || 'fyi',
    confidence: sonnet.parsed.confidence,
    cost: haiku.cost + sonnet.cost,
    inputTokens: haiku.inputTokens + sonnet.inputTokens,
    outputTokens: haiku.outputTokens + sonnet.outputTokens,
    operation: 'triage_sonnet_fallback',
    route: 'sonnet_fallback',
    fallbackReason: haiku.parsed.parseError ? 'parse_error' : 'low_confidence'
  };
}
