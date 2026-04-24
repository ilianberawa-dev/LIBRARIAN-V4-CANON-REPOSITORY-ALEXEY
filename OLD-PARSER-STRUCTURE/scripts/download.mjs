#!/usr/bin/env node
// Priority-based media download from "Алексей Колесов | Private".
// Phase 1: scan all media metadata → sort by priority (scripts > docs > photos > videos).
// Phase 2: download in priority order with human pauses + takeout session.
// argv: [limit] [minPriority] [maxPriority] [notakeout]
//   e.g.  node download.mjs 0 1 3          → all msgs, only P1-P3 (skip video/audio)
//   e.g.  node download.mjs 0 1 4          → all including videos/audio
//   e.g.  node download.mjs 0 1 3 notakeout → without takeout session

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { TelegramClient, Api } = require('telegram');
const { StringSession } = require('telegram/sessions/index.js');

const CHANNEL = 'Алексей Колесов | Private';
const CFG = '/opt/tg-export/config.json5';
const OUT_DIR = '/opt/tg-export/media';
const LOG = path.join(OUT_DIR, '_progress.log');
const MANIFEST = path.join(OUT_DIR, '_manifest.json');

// Human pacing
const SHORT_MIN = 60_000, SHORT_MAX = 300_000;
const BURST_EVERY_MIN = 3, BURST_EVERY_MAX = 6;
const BREAK_MIN = 300_000, BREAK_MAX = 1_200_000;
const LONG_BREAK_EVERY_MIN = 12, LONG_BREAK_EVERY_MAX = 20;
const LONG_BREAK_MIN = 1_800_000, LONG_BREAK_MAX = 5_400_000;

// Priority buckets
const P1_EXTS = new Set(['.zip','.md','.json','.js','.mjs','.ts','.py','.sh','.yml','.yaml','.toml','.cfg','.conf','.env','.html','.css','.sql','.dockerfile','.ini']);
const P2_EXTS = new Set(['.pdf','.txt','.csv','.xlsx','.docx','.rtf']);
const P3_EXTS = new Set(['.jpg','.jpeg','.png','.gif','.webp','.svg','.bmp']);
// P4: video, audio, everything else

const LIMIT = parseInt(process.argv[2] || '0', 10) || undefined;
const MIN_PRIO = parseInt(process.argv[3] || '1', 10);
const MAX_PRIO = parseInt(process.argv[4] || '4', 10);
const USE_TAKEOUT = process.argv[5] !== 'notakeout';

// Optional whitelist: only download msg_ids in this file (one per line).
// Env var: WHITELIST_FILE=/path/to/ids.txt
const WHITELIST_FILE = process.env.WHITELIST_FILE || '';
let WHITELIST = null;
if (WHITELIST_FILE && fs.existsSync(WHITELIST_FILE)) {
  WHITELIST = new Set(
    fs.readFileSync(WHITELIST_FILE, 'utf8').split(/\r?\n/).map((s) => parseInt(s.trim(), 10)).filter((n) => !isNaN(n))
  );
}

function parseCfg(raw) {
  const pick = (k) => {
    const m = raw.match(new RegExp(`${k}\\s*:\\s*['"]?([^,'"\\n]+)['"]?`));
    return m && m[1].trim();
  };
  return { apiId: parseInt(pick('apiId'), 10), apiHash: pick('apiHash'), sessionString: pick('sessionString') };
}

const cfg = parseCfg(fs.readFileSync(CFG, 'utf8'));
fs.mkdirSync(OUT_DIR, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rnd = (min, max) => min + Math.floor(Math.random() * (max - min));
const humanShort = () => sleep(rnd(SHORT_MIN, SHORT_MAX));
const humanBreak = () => sleep(rnd(BREAK_MIN, BREAK_MAX));
const humanLong = () => sleep(rnd(LONG_BREAK_MIN, LONG_BREAK_MAX));

function sanitize(s) { return (s || '').replace(/[<>:"/\\|?*\x00-\x1f]/g, '_').slice(0, 200); }

function logLine(s) {
  const line = `[${new Date().toISOString()}] ${s}`;
  console.log(line);
  fs.appendFileSync(LOG, line + '\n');
}

function getPriority(ext, hasDocument, hasPhoto) {
  if (P1_EXTS.has(ext)) return 1;
  if (P2_EXTS.has(ext)) return 2;
  if (P3_EXTS.has(ext)) return 3;
  if (hasPhoto && !hasDocument) return 3; // raw photo without filename
  return 4; // video/audio/unknown
}

function extractFilename(msg) {
  if (msg.document) {
    const attr = (msg.document.attributes || []).find((a) => a.fileName);
    if (attr?.fileName) return attr.fileName;
  }
  if (msg.photo) return `photo_${msg.id}.jpg`;
  return `media_${msg.id}`;
}

function extractSize(msg) {
  if (msg.document?.size) return Number(msg.document.size);
  if (msg.photo?.sizes?.length) {
    const biggest = msg.photo.sizes.reduce((a, b) => (Number(b.size || 0) > Number(a.size || 0) ? b : a), msg.photo.sizes[0]);
    return Number(biggest.size || 0);
  }
  return 0;
}

let manifest = { channel: CHANNEL, started: new Date().toISOString(), files: [] };
if (fs.existsSync(MANIFEST)) {
  try { manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8')); } catch {}
}
function saveManifest() {
  manifest.updated = new Date().toISOString();
  fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2));
}

async function main() {
  const session = new StringSession(cfg.sessionString);
  const client = new TelegramClient(session, cfg.apiId, cfg.apiHash, { connectionRetries: 5, floodSleepThreshold: 60 });
  client.setLogLevel('none');
  await client.connect();

  const dialogs = await client.getDialogs({ limit: 200 });
  const dialog = dialogs.find((d) => d.title === CHANNEL);
  if (!dialog) { logLine(`[!] Channel not found`); await client.disconnect(); process.exit(1); }
  const entity = dialog.entity;
  logLine(`[+] Channel: ${entity.title} id=${entity.id} [HOST: aeza] [PRIO ${MIN_PRIO}..${MAX_PRIO}]`);

  let takeoutId = null;
  if (USE_TAKEOUT) {
    try {
      const r = await client.invoke(new Api.account.InitTakeoutSession({
        contacts: false, messageUsers: false, messageChats: false,
        messageMegagroups: false, messageChannels: true, files: true, fileMaxSize: 2_000_000_000n,
      }));
      takeoutId = r.id;
      logLine(`[takeout] session id=${takeoutId}`);
    } catch (e) { logLine(`[takeout] ${e.message} — regular mode`); }
  }

  // Phase 1: scan all media
  logLine(`[scan] enumerating media...`);
  const queue = [];
  let scanned = 0;
  for await (const msg of client.iterMessages(entity, { limit: LIMIT })) {
    scanned++;
    if (!msg.media) continue;
    const filename = extractFilename(msg);
    const ext = path.extname(filename).toLowerCase();
    const size = extractSize(msg);
    const prio = getPriority(ext, !!msg.document, !!msg.photo);
    queue.push({ msg_id: msg.id, filename: sanitize(filename), ext, size, prio, msg });
  }
  logLine(`[scan] found ${queue.length} media in ${scanned} msgs`);

  // Phase 2: filter + sort by priority → size within priority
  let filtered = queue.filter((q) => q.prio >= MIN_PRIO && q.prio <= MAX_PRIO);
  if (WHITELIST) {
    const before = filtered.length;
    filtered = filtered.filter((q) => WHITELIST.has(q.msg_id));
    logLine(`[whitelist] filter ${before} -> ${filtered.length} (from ${WHITELIST.size} whitelisted ids)`);
  }
  filtered.sort((a, b) => a.prio - b.prio || a.size - b.size);
  const byPrio = [1,2,3,4].map((p) => filtered.filter((q) => q.prio === p).length);
  logLine(`[queue] filtered ${filtered.length} files: P1=${byPrio[0]} P2=${byPrio[1]} P3=${byPrio[2]} P4=${byPrio[3]}`);

  // Phase 3: download
  const existingIds = new Set(manifest.files.map((f) => f.msg_id));
  let downloaded = 0, skipped = 0, errors = 0;
  let sinceLastBreak = 0, sinceLastLongBreak = 0;
  let nextBreak = rnd(BURST_EVERY_MIN, BURST_EVERY_MAX);
  let nextLong = rnd(LONG_BREAK_EVERY_MIN, LONG_BREAK_EVERY_MAX);

  for (const item of filtered) {
    const { msg, msg_id, filename, prio, size } = item;
    const outPath = path.join(OUT_DIR, `${msg_id}_${filename}`);

    if (existingIds.has(msg_id) || (fs.existsSync(outPath) && fs.statSync(outPath).size > 0)) {
      if (!existingIds.has(msg_id)) {
        manifest.files.push({ msg_id, date: new Date(msg.date * 1000).toISOString(), filename, size: fs.statSync(outPath).size, path: outPath, priority: prio });
        saveManifest();
      }
      skipped++;
      logLine(`[skip P${prio}] ${msg_id} ${filename}`);
      continue;
    }

    try {
      const buf = await client.downloadMedia(msg, {});
      const bsz = buf ? buf.length : 0;
      if (bsz > 0) fs.writeFileSync(outPath, buf);
      downloaded++;
      sinceLastBreak++; sinceLastLongBreak++;
      manifest.files.push({ msg_id, date: new Date(msg.date * 1000).toISOString(), filename, size: bsz, path: outPath, priority: prio });
      saveManifest();
      logLine(`[ok P${prio}] ${msg_id} ${filename} (${bsz} bytes)`);

      if (sinceLastLongBreak >= nextLong) {
        const m = Math.floor(rnd(LONG_BREAK_MIN, LONG_BREAK_MAX) / 60000);
        logLine(`[long-break] ~${m}min`);
        await humanLong();
        sinceLastBreak = 0; sinceLastLongBreak = 0;
        nextBreak = rnd(BURST_EVERY_MIN, BURST_EVERY_MAX);
        nextLong = rnd(LONG_BREAK_EVERY_MIN, LONG_BREAK_EVERY_MAX);
      } else if (sinceLastBreak >= nextBreak) {
        const m = Math.floor(rnd(BREAK_MIN, BREAK_MAX) / 60000);
        logLine(`[break] ~${m}min`);
        await humanBreak();
        sinceLastBreak = 0;
        nextBreak = rnd(BURST_EVERY_MIN, BURST_EVERY_MAX);
      } else {
        await humanShort();
      }
    } catch (e) {
      const waitSec = e?.seconds;
      if (waitSec && waitSec < 600) {
        logLine(`[flood] ${waitSec}s retry ${msg_id}`);
        await sleep((waitSec + 5) * 1000);
        try {
          const buf = await client.downloadMedia(msg, {});
          const bsz = buf ? buf.length : 0;
          if (bsz > 0) fs.writeFileSync(outPath, buf);
          downloaded++;
          manifest.files.push({ msg_id, date: new Date(msg.date * 1000).toISOString(), filename, size: bsz, path: outPath, priority: prio });
          saveManifest();
          logLine(`[ok-retry P${prio}] ${msg_id} ${filename} (${bsz})`);
          await humanShort();
        } catch (e2) { errors++; logLine(`[err] ${msg_id} ${filename}: ${e2.message}`); }
      } else { errors++; logLine(`[err] ${msg_id} ${filename}: ${e.message}`); }
    }
  }

  if (takeoutId) {
    try { await client.invoke(new Api.account.FinishTakeoutSession({ success: true })); logLine(`[takeout] finished`); } catch {}
  }

  manifest.finished = new Date().toISOString();
  manifest.summary = { scanned, queued: filtered.length, downloaded, skipped, errors };
  saveManifest();
  logLine(`[done] scanned=${scanned} queued=${filtered.length} downloaded=${downloaded} skipped=${skipped} errors=${errors}`);
  await client.disconnect();
}

main().catch((e) => { logLine(`[fatal] ${e.message}`); process.exit(1); });
