-- Stage 8: WhatsApp incoming messages
CREATE TABLE IF NOT EXISTS wa_messages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  phone       TEXT,
  name        TEXT,
  kind        TEXT DEFAULT 'text',
  text        TEXT,
  raw_json    TEXT,
  received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  forwarded   INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_wa_messages_received_at ON wa_messages(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_wa_messages_phone       ON wa_messages(phone);

INSERT OR REPLACE INTO schema_version (version, applied_at)
VALUES ('1.4', datetime('now'));
