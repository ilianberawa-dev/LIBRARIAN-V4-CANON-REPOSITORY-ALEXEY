#!/usr/bin/env node
// Sync Alexey channel → detect new posts since last sync.
// Updates library_index.json, classifies, auto-whitelists HIGH, announces in Telegram.
// Cron: every 6h. Safe to run while download/transcribe in progress (read-only on existing).

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions/index.js');

const CHANNEL = 'Алексей Колесов | Private';
const CFG = '/opt/tg-export/config.json5';
const LIBRARY = '/opt/tg-export/library_index.json';
const WHITELIST = '/opt/tg-export/p4_whitelist.txt';
const LOG = '/opt/tg-export/sync.log';
const ANNOUNCED = '/opt/tg-export/announced.txt';
const CHANNEL_ID = 2653037830;
const URL_BASE = `https://t.me/c/${CHANNEL_ID}`;

const P1 = new Set(['.zip','.md','.json','.js','.mjs','.ts','.py','.sh','.yml','.yaml','.toml','.cfg','.conf','.env','.html','.css','.sql']);
const P2 = new Set(['.pdf','.txt','.csv','.xlsx','.docx','.rtf']);
const P3 = new Set(['.jpg','.jpeg','.png','.gif','.webp','.svg','.bmp']);

const CODE_KW = ['скрипт','api','mcp','docker','n8n','supabase','agent','код','sql','устан','setup','deploy','install','config','cli','github','npm','kilo','claude code','cursor','gemini','openclaw','lightrag','paperclip','baserow','nginx','сервер','команд','workflow','леший','skill','mtproto','telegram api','rag','llm','prompt','скилл','mcp','агент'];
const SALES_KW = ['продаж','монетиз','лид','маркет','воронк','клиент','бизнес','доход','подписк','тариф','crm','контент-завод'];

function parseCfg(raw) {
  const pick = (k) => {
    const m = raw.match(new RegExp(`${k}\\s*:\\s*['"]?([^,'"\\n]+)['"]?`));
    return m && m[1].trim();
  };
  return { apiId: parseInt(pick('apiId'), 10), apiHash: pick('apiHash'), sessionString: pick('sessionString') };
}

function logLine(s) {
  const line = `[${new Date().toISOString()}] ${s}`;
  console.log(line);
  fs.appendFileSync(LOG, line + '\n');
}

function getPriority(ext, hasDoc, hasPhoto) {
  if (P1.has(ext)) return 1;
  if (P2.has(ext)) return 2;
  if (P3.has(ext)) return 3;
  if (hasPhoto && !hasDoc) return 3;
  return 4;
}

function classify(text) {
  const t = (text || '').toLowerCase();
  const c = CODE_KW.reduce((n, k) => n + (t.split(k).length - 1), 0);
  const s = SALES_KW.reduce((n, k) => n + (t.split(k).length - 1), 0);
  if (c >= 3 && c > s * 1.5) return { cat: 'HIGH_CODE', c, s };
  if (s >= 3) return { cat: 'HIGH_SALES', c, s };
  if (c + s >= 3) return { cat: 'HIGH_MIXED', c, s };
  if (c + s >= 1) return { cat: 'MED', c, s };
  return { cat: 'LOW', c, s };
}

function extractTitle(text) {
  if (!text) return '[без текста]';
  const lines = text.split('\n').map((l) => l.trim()).filter(Boolean);
  for (const line of lines) {
    const clean = line.replace(/^[^\wа-яА-ЯёЁ]+/, '').trim();
    if (clean.length > 8) return clean.slice(0, 120);
  }
  return (lines[0] || '[без текста]').slice(0, 120);
}

function extractTopics(text) {
  const t = (text || '').toLowerCase();
  const topics = [];
  const map = {
    'LightRAG': ['lightrag','лайтраг'],
    'Paperclip': ['paperclip'],
    'OpenClaw': ['openclaw'],
    'Леший': ['леший'],
    'Kilo Code': ['kilo code','kilocode'],
    'Claude Code': ['claude code'],
    'Cursor': ['cursor'],
    'Gemini CLI': ['gemini cli'],
    'n8n': ['n8n'],
    'Supabase': ['supabase'],
    'Docker': ['docker'],
    'MCP': ['mcp','model context protocol'],
    'Skills': ['скилл','skill'],
    'Telegram': ['telegram','телеграм'],
    'DevOps': ['devops'],
    'Baserow': ['baserow'],
  };
  for (const [topic, kws] of Object.entries(map)) {
    if (kws.some((kw) => t.includes(kw))) topics.push(topic);
  }
  return topics;
}

async function sendTelegram(msg) {
  const envRaw = fs.readFileSync('/opt/tg-export/.env', 'utf8');
  const botToken = (envRaw.match(/^BOT_TOKEN=(.+)$/m) || [])[1];
  const chatId = (envRaw.match(/^CHAT_ID=(.+)$/m) || [])[1];
  if (!botToken || !chatId) {
    logLine('[announce] no BOT_TOKEN/CHAT_ID — skipping');
    return;
  }
  const body = new URLSearchParams({ chat_id: chatId, text: msg, parse_mode: 'HTML' });
  try {
    const resp = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      body,
    });
    const j = await resp.json();
    if (!j.ok) logLine(`[announce] FAIL: ${JSON.stringify(j)}`);
  } catch (e) { logLine(`[announce] error: ${e.message}`); }
}

async function main() {
  const cfg = parseCfg(fs.readFileSync(CFG, 'utf8'));
  const session = new StringSession(cfg.sessionString);
  const client = new TelegramClient(session, cfg.apiId, cfg.apiHash, { connectionRetries: 5 });
  client.setLogLevel('none');
  await client.connect();

  const dialogs = await client.getDialogs({ limit: 200 });
  const dialog = dialogs.find((d) => d.title === CHANNEL);
  if (!dialog) { logLine('[!] channel not found'); await client.disconnect(); process.exit(1); }

  // Load library
  let library = { channel: CHANNEL, channel_id: CHANNEL_ID, posts: [] };
  if (fs.existsSync(LIBRARY)) {
    try { library = JSON.parse(fs.readFileSync(LIBRARY, 'utf8')); } catch {}
  }
  const knownIds = new Set(library.posts.map((p) => p.msg_id));
  const maxKnown = Math.max(0, ...library.posts.map((p) => p.msg_id));

  logLine(`[sync] last known msg_id=${maxKnown}, known posts=${knownIds.size}`);

  // Load announcement history
  const announcedSet = new Set();
  if (fs.existsSync(ANNOUNCED)) {
    fs.readFileSync(ANNOUNCED, 'utf8').split('\n').forEach((l) => {
      const n = parseInt(l.trim(), 10);
      if (!isNaN(n)) announcedSet.add(n);
    });
  }

  // Fetch all (cheap — gramJS will stop once we reach known ids)
  const newPosts = [];
  let scanned = 0;
  for await (const msg of client.iterMessages(dialog.entity, { limit: 500 })) {
    scanned++;
    if (knownIds.has(msg.id)) continue;
    if (msg.id <= maxKnown) break; // older msgs already indexed

    const text = msg.message || '';
    const cls = classify(text);

    let filename = '', ext = '', size_mb = 0, prio = null;
    if (msg.document) {
      const attr = (msg.document.attributes || []).find((a) => a.fileName);
      filename = attr?.fileName || `media_${msg.id}`;
      ext = path.extname(filename).toLowerCase();
      size_mb = Math.round(Number(msg.document.size || 0) / 1048576 * 10) / 10;
      prio = getPriority(ext, !!msg.document, !!msg.photo);
    } else if (msg.photo) {
      filename = `photo_${msg.id}.jpg`;
      ext = '.jpg';
      prio = 3;
    }

    const post = {
      msg_id: msg.id,
      date: new Date(msg.date * 1000).toISOString(),
      title: extractTitle(text),
      type: prio === 4 ? 'video/audio' : prio === 3 ? 'photo' : prio ? 'doc' : 'text',
      url: `${URL_BASE}/${msg.id}`,
      topics: extractTopics(text),
      category: cls.cat,
      code_score: cls.c,
      sales_score: cls.s,
      filename,
      size_mb,
      priority: prio,
      text_full: text,
      text_preview: text.slice(0, 400),
    };
    newPosts.push(post);

    // Auto-whitelist if HIGH + video/audio + size > 50MB
    if (prio === 4 && size_mb > 50 && (cls.cat === 'HIGH_CODE' || cls.cat === 'HIGH_SALES')) {
      fs.appendFileSync(WHITELIST, `${msg.id}\n`);
      logLine(`[whitelist+] ${msg.id} ${filename} (${size_mb} MB, ${cls.cat})`);
    }
  }

  logLine(`[sync] scanned ${scanned} msgs, ${newPosts.length} new`);

  if (newPosts.length > 0) {
    library.posts = [...newPosts, ...library.posts];
    library.generated = new Date().toISOString();
    library.total_posts = library.posts.length;
    fs.writeFileSync(LIBRARY, JSON.stringify(library, null, 2));
    logLine(`[library] updated: now ${library.total_posts} posts`);

    // Announce each new post (that wasn't yet announced)
    for (const p of newPosts.reverse()) {
      if (announcedSet.has(p.msg_id)) continue;
      const tEmoji = { 'video/audio': '🎥', 'photo': '📸', 'doc': '📎', 'text': '📝' }[p.type] || '•';
      const prioBadge = p.category.startsWith('HIGH') ? `🎯 <b>${p.category}</b>` : p.category;
      const topicsLine = p.topics.length ? `\n🏷 ${p.topics.join(', ')}` : '';
      const fileLine = p.filename ? `\n📎 ${p.filename}${p.size_mb ? ` (${p.size_mb} МБ)` : ''}` : '';
      const whitelistLine = (p.priority === 4 && p.size_mb > 50 && p.category.startsWith('HIGH'))
        ? '\n\n⚡️ Автоматически добавлено в очередь скачивания + транскрибации'
        : '';
      const msg = `🆕 <b>Новый пост Алексея</b> #${p.msg_id}
${tEmoji} ${prioBadge}${topicsLine}${fileLine}

<b>${p.title}</b>

${p.text_preview.slice(0, 300)}${p.text_preview.length > 300 ? '...' : ''}

🔗 ${p.url}${whitelistLine}`;
      await sendTelegram(msg);
      fs.appendFileSync(ANNOUNCED, `${p.msg_id}\n`);
      logLine(`[announced] msg ${p.msg_id}: ${p.title.slice(0, 60)}`);
      // small pause between announcements
      await new Promise((r) => setTimeout(r, 1500));
    }
  } else {
    logLine('[sync] no new posts');
  }

  await client.disconnect();
}

main().catch((e) => { logLine(`[fatal] ${e.message}`); process.exit(1); });
