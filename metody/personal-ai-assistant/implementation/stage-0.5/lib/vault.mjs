// vault.mjs — systemd-creds reader for Personal AI Assistant Stage 0.5+.
// Canon #6 Single Vault, #11 Privilege Isolation.
//
// Usage: import { getSecret, redact } from './lib/vault.mjs';
//        const apiKey = getSecret('anthropic-api-key');
//
// Each service systemd unit must declare LoadCredentialEncrypted= for the
// keys it needs. systemd places decrypted plaintext at
// $CREDENTIALS_DIRECTORY/<name>, tmpfs-only, readable by service user
// during process lifetime, never persisted to disk in plain.

import fs from 'node:fs';
import path from 'node:path';

const credDir = process.env.CREDENTIALS_DIRECTORY;
if (!credDir) {
  console.error(JSON.stringify({
    ts: new Date().toISOString(),
    level: 'fatal',
    msg: 'vault_not_initialized',
    hint: 'systemd unit must set LoadCredentialEncrypted= for this service. CREDENTIALS_DIRECTORY env var missing.'
  }));
  process.exit(1);
}

/**
 * Read a credential by name. Fail-loud + exit(1) if missing or empty.
 * @param {string} name
 * @returns {string} secret value (trimmed)
 */
export function getSecret(name) {
  const filePath = path.join(credDir, name);
  if (!fs.existsSync(filePath)) {
    console.error(JSON.stringify({
      ts: new Date().toISOString(),
      level: 'fatal',
      msg: 'vault_secret_missing',
      name,
      hint: `Add LoadCredentialEncrypted=${name}:/etc/credstore.encrypted/${name}.cred to systemd unit`
    }));
    process.exit(1);
  }
  const value = fs.readFileSync(filePath, 'utf8').trim();
  if (!value) {
    console.error(JSON.stringify({
      ts: new Date().toISOString(),
      level: 'fatal',
      msg: 'vault_secret_empty',
      name
    }));
    process.exit(1);
  }
  return value;
}

const REDACT_PATTERNS = [
  /sk-ant-[A-Za-z0-9_-]{20,}/g,
  /xai-[A-Za-z0-9_-]{20,}/g,
  /\b\d+:[a-zA-Z0-9_-]{30,}\b/g
];

/**
 * Mask known secret patterns in a string. Use before logging or
 * persisting any user-provided / model-generated text that may
 * contain credentials.
 * @param {string} text
 * @returns {string}
 */
export function redact(text) {
  if (!text || typeof text !== 'string') return text;
  let out = text;
  for (const re of REDACT_PATTERNS) {
    out = out.replace(re, '[REDACTED]');
  }
  return out;
}
