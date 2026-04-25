#!/usr/bin/env node
// Enumerate all P4 (video/audio/unknown) media in Alexey channel.
// Output: /opt/tg-export/p4_catalog.json with {msg_id, filename, ext, size_bytes, mime, caption}
// Uses existing Telegram session config.

import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);
const { TelegramClient, Api } = require('telegram');
const { StringSession } = require('telegram/sessions/index.js');

const CHANNEL = 'Алексей Колесов | Private';
const CFG = '/opt/tg-export/config.json5';
const OUT = '/opt/tg-export/p4_catalog.json';

const P1_EXTS = new Set(['.zip','.md','.json','.js','.mjs','.ts','.py','.sh','.yml','.yaml','.toml','.cfg','.conf','.env','.html','.css','.sql','.dockerfile','.ini']);
const P2_EXTS = new Set(['.pdf','.txt','.csv','.xlsx','.docx','.rtf']);
const P3_EXTS = new Set(['.jpg','.jpeg','.png','.gif','.webp','.svg','.bmp']);

function parseCfg(raw) {
  const pick = (k) => {
    const m = raw.match(new RegExp(`${k}\\s*:\\s*['"]?([^,'"\\n]+)['"]?`));
    return m && m[1].trim();
  };
  return { apiId: parseInt(pick('apiId'), 10), apiHash: pick('apiHash'), sessionString: pick('sessionString') };
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

function getPriority(ext, hasDoc, hasPhoto) {
  if (P1_EXTS.has(ext)) return 1;
  if (P2_EXTS.has(ext)) return 2;
  if (P3_EXTS.has(ext)) return 3;
  if (hasPhoto && !hasDoc) return 3;
  return 4;
}

async function main() {
  const cfg = parseCfg(fs.readFileSync(CFG, 'utf8'));
  const session = new StringSession(cfg.sessionString);
  const client = new TelegramClient(session, cfg.apiId, cfg.apiHash, { connectionRetries: 5 });
  client.setLogLevel('none');
  await client.connect();

  const dialogs = await client.getDialogs({ limit: 200 });
  const dialog = dialogs.find((d) => d.title === CHANNEL);
  if (!dialog) { console.error('channel not found'); await client.disconnect(); process.exit(1); }

  const p4_list = [];
  let totalMsgs = 0, totalMedia = 0;

  for await (const msg of client.iterMessages(dialog.entity, { limit: undefined })) {
    totalMsgs++;
    if (!msg.media) continue;
    totalMedia++;
    const filename = extractFilename(msg);
    const ext = path.extname(filename).toLowerCase();
    const size = extractSize(msg);
    const prio = getPriority(ext, !!msg.document, !!msg.photo);
    if (prio !== 4) continue;

    // Extract MIME if present
    let mime = '';
    if (msg.document?.mimeType) mime = msg.document.mimeType;

    // Get caption text
    const caption = (msg.message || '').slice(0, 2000);

    p4_list.push({
      msg_id: msg.id,
      date: new Date(msg.date * 1000).toISOString(),
      filename,
      ext,
      size_bytes: size,
      size_mb: Math.round(size / 1048576 * 10) / 10,
      mime,
      caption,
    });
  }

  fs.writeFileSync(OUT, JSON.stringify({ channel: CHANNEL, total_msgs: totalMsgs, total_media: totalMedia, p4_count: p4_list.length, items: p4_list }, null, 2));
  console.log(`scanned ${totalMsgs} msgs, ${totalMedia} media, ${p4_list.length} P4 items`);
  console.log(`saved: ${OUT}`);
  await client.disconnect();
}

main().catch((e) => { console.error(e); process.exit(1); });
