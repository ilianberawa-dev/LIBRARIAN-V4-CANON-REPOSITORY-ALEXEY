// auth-qr.mjs — Canonical QR-code MTProto authentication.
// Replaces SMS-based auth.mjs when SMS delivery is blocked (roaming,
// AntiFraud, or simply preferred). Telegram-supported native flow.
//
// Run on server as: sudo -iu personal-assistant; cd /opt/personal-assistant; 
//   set -a; source .env; set +a; node auth-qr.mjs
//
// Owner side:
//   Phone TG → Settings → Devices → Link Desktop Device → scan QR shown in terminal.
//
// Output: TG_SESSION_STRING — append to /opt/personal-assistant/.env (chmod 600).

import 'dotenv/config';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import qrcode from 'qrcode-terminal';

const apiId = parseInt(process.env.TG_API_ID, 10);
const apiHash = process.env.TG_API_HASH;

if (!apiId || !apiHash) {
  console.error('FATAL: TG_API_ID / TG_API_HASH not set in environment. Fill them in .env first.');
  process.exit(1);
}

const client = new TelegramClient(new StringSession(''), apiId, apiHash, {
  connectionRetries: 5
});

await client.connect();

console.log('\n========================================');
console.log('QR LOGIN — Scan with Telegram on your phone:');
console.log('  Phone TG → Settings → Devices → Link Desktop Device → Scan QR');
console.log('  (QR refreshes every ~30 sec. Re-scan if expired.)');
console.log('========================================\n');

let qrShownCount = 0;

try {
  await client.signInUserWithQrCode(
    { apiId, apiHash },
    {
      qrCode: async (code) => {
        qrShownCount++;
        const tokenB64 = code.token.toString('base64url');
        const url = `tg://login?token=${tokenB64}`;
        if (qrShownCount > 1) {
          console.log(`\n[QR refresh #${qrShownCount}]`);
        }
        qrcode.generate(url, { small: true });
        console.log('\nWaiting for scan...\n');
      },
      password: async () => process.env.TG_2FA_PASSWORD || '',
      onError: (err) => {
        console.error('QR LOGIN ERROR:', err?.message || err);
        return false;
      }
    }
  );
} catch (err) {
  console.error('FATAL: QR auth failed:', err?.message || err);
  process.exit(1);
}

const sessionString = client.session.save();

console.log('\n========================================');
console.log('AUTH SUCCESS. Append the line below to /opt/personal-assistant/.env :');
console.log('========================================');
console.log(`TG_SESSION_STRING=${sessionString}`);
console.log('========================================\n');

await client.disconnect();
process.exit(0);
