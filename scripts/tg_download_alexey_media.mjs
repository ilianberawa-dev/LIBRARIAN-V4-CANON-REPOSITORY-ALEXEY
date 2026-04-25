#!/usr/bin/env node
// Download media from "Алексей Колесов | Private" using TAKEOUT SESSION.
// Takeout = official Telegram export mode → lower flood limits, safest for mass media downloads.
// Human-like non-uniform pacing: 8-45s random + long break (2-5 min) every 4-8 files.
// Incremental manifest, resumable. Kill/restart safe.

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const GRAMJS_ROOT = 'C:/Users/97152/AppData/Roaming/npm/node_modules/@skillhq/telegram/node_modules/telegram';
const { TelegramClient, Api } = require(`${GRAMJS_ROOT}/index.js`);
const { StringSession } = require(`${GRAMJS_ROOT}/sessions/index.js`);

const CHANNEL = 'Алексей Колесов | Private';
const CFG = 'C:/Users/97152/.config/tg/config.json5';
const OUT_DIR = 'C:/work/realty-portal/docs/alexey-reference/export-2026-04-20/media';
const LOG = path.join(OUT_DIR, '_progress.log');
const MANIFEST = path.join(OUT_DIR, '_manifest.json');

// Human-like pacing config — VERY SLOW mode (overnight export)
const SHORT_MIN = 60_000;         // 1 min
const SHORT_MAX = 300_000;        // 5 min
const BURST_EVERY_MIN = 3;        // after N files
const BURST_EVERY_MAX = 6;
const BREAK_MIN = 300_000;        // 5 min
const BREAK_MAX = 1_200_000;      // 20 min
const LONG_BREAK_EVERY_MIN = 12;  // every N files
const LONG_BREAK_EVERY_MAX = 20;
const LONG_BREAK_MIN = 1_800_000; // 30 min
const LONG_BREAK_MAX = 5_400_000; // 90 min

const LIMIT = parseInt(process.argv[2] || '0', 10) || undefined;
const USE_TAKEOUT = (process.argv[3] !== 'notakeout');

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
const randBetween = (min, max) => min + Math.floor(Math.random() * (max - min));
const humanShort = () => sleep(randBetween(SHORT_MIN, SHORT_MAX));
const humanBreak = () => sleep(randBetween(BREAK_MIN, BREAK_MAX));
const humanLongBreak = () => sleep(randBetween(LONG_BREAK_MIN, LONG_BREAK_MAX));

function sanitize(name) {
  return (name || '').replace(/[<>:"/\\|?*\x00-\x1f]/g, '_').slice(0, 200);
}

function logLine(s) {
  const line = `[${new Date().toISOString()}] ${s}`;
  console.log(line);
  fs.appendFileSync(LOG, line + '\n');
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
  const client = new TelegramClient(session, cfg.apiId, cfg.apiHash, {
    connectionRetries: 5,
    floodSleepThreshold: 60,
  });
  client.setLogLevel('none');
  await client.connect();

  const dialogs = await client.getDialogs({ limit: 200 });
  const dialog = dialogs.find((d) => d.title === CHANNEL);
  if (!dialog) { logLine(`[!] Channel "${CHANNEL}" not found`); await client.disconnect(); process.exit(1); }
  const entity = dialog.entity;
  logLine(`[+] Channel: ${entity.title || CHANNEL} id=${entity.id}`);

  // Start takeout session
  let takeoutClient = client;
  let takeoutId = null;
  if (USE_TAKEOUT) {
    try {
      const result = await client.invoke(new Api.account.InitTakeoutSession({
        contacts: false,
        messageUsers: false,
        messageChats: false,
        messageMegagroups: false,
        messageChannels: true,
        files: true,
        fileMaxSize: 2_000_000_000n,
      }));
      takeoutId = result.id;
      logLine(`[takeout] session id=${takeoutId}`);
      // Wrap all calls with InvokeWithTakeout
      takeoutClient = {
        iterMessages: (e, opts) => client.iterMessages(e, opts),
        downloadMedia: async (msg, opts) => {
          return await client.downloadMedia(msg, opts);
        },
      };
    } catch (e) {
      if (e.message && e.message.includes('TAKEOUT_INIT_DELAY')) {
        const sec = e.seconds || 0;
        logLine(`[takeout] rejected: user must confirm takeout in Telegram first. Wait ${sec}s OR approve in TG.`);
        logLine(`[takeout] falling back to regular mode`);
      } else {
        logLine(`[takeout] failed: ${e.message} — falling back to regular mode`);
      }
    }
  }

  const existing = new Set(manifest.files.map((f) => f.msg_id));
  let scanned = 0, downloaded = 0, skipped = 0, errors = 0;
  let nextBreakAfter = randBetween(BURST_EVERY_MIN, BURST_EVERY_MAX);
  let nextLongBreakAfter = randBetween(LONG_BREAK_EVERY_MIN, LONG_BREAK_EVERY_MAX);
  let sinceLastBreak = 0;
  let sinceLastLongBreak = 0;

  for await (const msg of client.iterMessages(entity, { limit: LIMIT })) {
    scanned++;
    if (!msg.media) continue;
    if (existing.has(msg.id)) { skipped++; continue; }

    let filename = null;
    if (msg.document) {
      const attr = (msg.document.attributes || []).find((a) => a.fileName);
      filename = attr?.fileName;
    }
    if (!filename && msg.photo) filename = `photo_${msg.id}.jpg`;
    if (!filename) filename = `media_${msg.id}`;
    filename = sanitize(filename);

    const outPath = path.join(OUT_DIR, `${msg.id}_${filename}`);

    if (fs.existsSync(outPath) && fs.statSync(outPath).size > 0) {
      manifest.files.push({ msg_id: msg.id, date: new Date(msg.date * 1000).toISOString(), filename, size: fs.statSync(outPath).size, path: outPath });
      saveManifest();
      skipped++;
      logLine(`[skip] ${msg.id} ${filename} (already on disk)`);
      continue;
    }

    try {
      const buf = await client.downloadMedia(msg, {});
      const size = buf ? buf.length : 0;
      if (size > 0) fs.writeFileSync(outPath, buf);
      downloaded++;
      sinceLastBreak++;
      manifest.files.push({ msg_id: msg.id, date: new Date(msg.date * 1000).toISOString(), filename, size, path: outPath });
      saveManifest();
      logLine(`[ok] ${msg.id} ${filename} (${size} bytes)`);

      sinceLastLongBreak++;
      if (sinceLastLongBreak >= nextLongBreakAfter) {
        const longMin = Math.floor(randBetween(LONG_BREAK_MIN, LONG_BREAK_MAX) / 60000);
        logLine(`[long-break] pausing ~${longMin}min (human sleep/food) after ${sinceLastLongBreak} files`);
        await humanLongBreak();
        sinceLastBreak = 0;
        sinceLastLongBreak = 0;
        nextBreakAfter = randBetween(BURST_EVERY_MIN, BURST_EVERY_MAX);
        nextLongBreakAfter = randBetween(LONG_BREAK_EVERY_MIN, LONG_BREAK_EVERY_MAX);
      } else if (sinceLastBreak >= nextBreakAfter) {
        const breakMin = Math.floor(randBetween(BREAK_MIN, BREAK_MAX) / 60000);
        logLine(`[break] pausing ~${breakMin}min (human idle) after ${sinceLastBreak} files`);
        await humanBreak();
        sinceLastBreak = 0;
        nextBreakAfter = randBetween(BURST_EVERY_MIN, BURST_EVERY_MAX);
      } else {
        const s = Math.floor(randBetween(SHORT_MIN, SHORT_MAX) / 1000);
        logLine(`[wait] ${s}s`);
        await humanShort();
      }
    } catch (e) {
      const waitSec = e?.seconds;
      if (waitSec && waitSec < 600) {
        logLine(`[flood] sleep ${waitSec}s then retry msg ${msg.id}`);
        await sleep((waitSec + 5) * 1000);
        try {
          const buf = await client.downloadMedia(msg, {});
          const size = buf ? buf.length : 0;
          if (size > 0) fs.writeFileSync(outPath, buf);
          downloaded++;
          manifest.files.push({ msg_id: msg.id, date: new Date(msg.date * 1000).toISOString(), filename, size, path: outPath });
          saveManifest();
          logLine(`[ok-retry] ${msg.id} ${filename} (${size} bytes)`);
          await humanShort();
        } catch (e2) {
          errors++;
          logLine(`[err] ${msg.id} ${filename}: ${e2.message}`);
        }
      } else {
        errors++;
        logLine(`[err] ${msg.id} ${filename}: ${e.message}`);
      }
    }
  }

  if (takeoutId) {
    try {
      await client.invoke(new Api.account.FinishTakeoutSession({ success: true }));
      logLine(`[takeout] session finished`);
    } catch (e) { logLine(`[takeout] finish err: ${e.message}`); }
  }

  manifest.finished = new Date().toISOString();
  manifest.summary = { scanned, downloaded, skipped, errors };
  saveManifest();

  logLine(`[done] scanned=${scanned} downloaded=${downloaded} skipped=${skipped} errors=${errors}`);
  await client.disconnect();
}

main().catch((e) => { logLine(`[fatal] ${e.message}`); process.exit(1); });
