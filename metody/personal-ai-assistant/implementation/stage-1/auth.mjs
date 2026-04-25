// auth.mjs — One-time interactive MTProto authentication.
// Run as: sudo -iu personal-assistant; cd /opt/personal-assistant; set -a; source .env; set +a; node auth.mjs
// Output: TG_SESSION_STRING — append to /opt/personal-assistant/.env (chmod 600 preserved).

import 'dotenv/config';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import input from 'input';

const apiId = parseInt(process.env.TG_API_ID, 10);
const apiHash = process.env.TG_API_HASH;
const defaultPhone = process.env.PHONE || '';

if (!apiId || !apiHash) {
  console.error('FATAL: TG_API_ID / TG_API_HASH not set in environment. Fill them in .env first.');
  process.exit(1);
}

const session = new StringSession('');
const client = new TelegramClient(session, apiId, apiHash, { connectionRetries: 5 });

await client.start({
  phoneNumber: async () => (await input.text(`Phone number [${defaultPhone}]: `)) || defaultPhone,
  password: async () => await input.password('2FA password (leave empty if none): '),
  phoneCode: async () => await input.text('SMS code: '),
  onError: (err) => console.error('AUTH ERROR:', err)
});

const sessionString = client.session.save();

console.log('\n========================================');
console.log('AUTH SUCCESS. Append the line below to /opt/personal-assistant/.env :');
console.log('========================================');
console.log(`TG_SESSION_STRING=${sessionString}`);
console.log('========================================\n');

await client.disconnect();
process.exit(0);
