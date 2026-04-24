#!/usr/bin/env node
// One-time helper: produces a TG_SESSION_STRING via SMS/2FA login.
// Run once as the personal-assistant user with TG_API_ID and TG_API_HASH in env.
// Paste the printed string into .env as TG_SESSION_STRING=...

import readline from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions/index.js');

const apiId = parseInt(process.env.TG_API_ID || '', 10);
const apiHash = process.env.TG_API_HASH || '';
if (!apiId || !apiHash) {
  console.error('Set TG_API_ID and TG_API_HASH in the environment before running.');
  process.exit(1);
}

const rl = readline.createInterface({ input, output });
const ask = (q) => rl.question(q);

const session = new StringSession('');
const client = new TelegramClient(session, apiId, apiHash, { connectionRetries: 5 });

await client.start({
  phoneNumber: () => ask('Phone (with country code, e.g. +972…): '),
  phoneCode:   () => ask('Code from Telegram/SMS: '),
  password:    () => ask('2FA password (blank if none): '),
  onError:     (err) => console.error('[auth]', err),
});

console.log('\nSUCCESS. Add the following line to /opt/personal-assistant/.env:\n');
console.log(`TG_SESSION_STRING=${session.save()}\n`);

await client.disconnect();
rl.close();
process.exit(0);
