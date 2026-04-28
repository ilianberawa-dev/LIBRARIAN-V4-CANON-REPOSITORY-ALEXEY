-- Personal AI Assistant — SQLite schema v1.2
-- All tables created idempotently.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS contacts (
  tg_id          INTEGER PRIMARY KEY,
  name           TEXT,
  username       TEXT,
  first_seen     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_msg_at    TIMESTAMP,
  msg_count_30d  INTEGER DEFAULT 0,
  priority       TEXT,
  is_vip         INTEGER DEFAULT 0,
  notes          TEXT,
  tone           TEXT
);

CREATE TABLE IF NOT EXISTS messages (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  tg_msg_id    INTEGER,
  chat_id      INTEGER,
  from_id      INTEGER REFERENCES contacts(tg_id),
  text         TEXT,
  received_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  category     TEXT,
  urgent       INTEGER DEFAULT 0,
  handled      INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_messages_received_at ON messages(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_from_id     ON messages(from_id);

CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
  text, from_name, chat_name,
  content=messages,
  tokenize='unicode61 remove_diacritics 2'
);

CREATE TABLE IF NOT EXISTS drafts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  msg_id        INTEGER REFERENCES messages(id),
  draft_text    TEXT,
  generated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  verdict       TEXT,
  final_text    TEXT,
  feedback_note TEXT
);

CREATE TABLE IF NOT EXISTS rules (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  scope       TEXT,
  scope_id    TEXT,
  action      TEXT,
  note        TEXT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS voice_samples (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  to_contact_id   INTEGER REFERENCES contacts(tg_id),
  text            TEXT,
  sent_at         TIMESTAMP
);

CREATE TABLE IF NOT EXISTS budget_log (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  date           DATE,
  input_tokens   INTEGER,
  output_tokens  INTEGER,
  cost_usd       REAL,
  operation      TEXT
);

CREATE TABLE IF NOT EXISTS briefs (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  brief_type    TEXT,
  generated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  content       TEXT,
  msg_count     INTEGER
);
