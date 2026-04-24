-- Personal Assistant — SQLite schema v1.
-- Scope: Stage 1 fills contacts, messages, messages_fts. Stage 2+ tables
-- are scaffolded here (same version) to avoid a migration later.
-- All statements are idempotent: safe to run on every listener boot.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- =========================================================================
-- Stage 1 — active tables
-- =========================================================================

CREATE TABLE IF NOT EXISTS contacts (
  tg_user_id   TEXT PRIMARY KEY,
  username     TEXT,
  first_name   TEXT,
  last_name    TEXT,
  phone        TEXT,
  vip          INTEGER NOT NULL DEFAULT 0,
  first_seen   INTEGER NOT NULL,
  last_msg_at  INTEGER NOT NULL,
  notes        TEXT
);

CREATE INDEX IF NOT EXISTS idx_contacts_last_msg_at
  ON contacts(last_msg_at DESC);

CREATE INDEX IF NOT EXISTS idx_contacts_vip
  ON contacts(vip) WHERE vip = 1;

CREATE TABLE IF NOT EXISTS messages (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  tg_message_id  INTEGER NOT NULL,
  tg_chat_id     TEXT    NOT NULL,
  tg_user_id     TEXT    NOT NULL,
  direction      TEXT    NOT NULL CHECK (direction IN ('in','out')),
  text           TEXT,
  has_media      INTEGER NOT NULL DEFAULT 0,
  ts             INTEGER NOT NULL,
  category       TEXT,                -- filled in Stage 2
  priority       INTEGER,             -- filled in Stage 2
  FOREIGN KEY (tg_user_id) REFERENCES contacts(tg_user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_unique
  ON messages(tg_chat_id, tg_message_id);

CREATE INDEX IF NOT EXISTS idx_messages_user_ts
  ON messages(tg_user_id, ts DESC);

CREATE INDEX IF NOT EXISTS idx_messages_ts
  ON messages(ts DESC);

CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
  text,
  content       = 'messages',
  content_rowid = 'id',
  tokenize      = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
  INSERT INTO messages_fts(rowid, text) VALUES (new.id, new.text);
END;

CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, text) VALUES ('delete', old.id, old.text);
END;

CREATE TRIGGER IF NOT EXISTS messages_au AFTER UPDATE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, text) VALUES ('delete', old.id, old.text);
  INSERT INTO messages_fts(rowid, text) VALUES (new.id, new.text);
END;

-- =========================================================================
-- Stage 2+ — scaffolds (empty in Stage 1; prevents future migrations)
-- =========================================================================

CREATE TABLE IF NOT EXISTS drafts (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id  INTEGER NOT NULL,
  draft_text  TEXT    NOT NULL,
  status      TEXT    NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','approved','sent','discarded')),
  created_at  INTEGER NOT NULL,
  sent_at     INTEGER,
  FOREIGN KEY (message_id) REFERENCES messages(id)
);

CREATE INDEX IF NOT EXISTS idx_drafts_status ON drafts(status);

CREATE TABLE IF NOT EXISTS rules (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL UNIQUE,
  condition   TEXT    NOT NULL,   -- JSON predicate
  action      TEXT    NOT NULL,   -- JSON action
  enabled     INTEGER NOT NULL DEFAULT 1,
  created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS voice_samples (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  tg_user_id  TEXT,
  audio_path  TEXT    NOT NULL,
  transcript  TEXT,
  duration_s  INTEGER,
  created_at  INTEGER NOT NULL,
  FOREIGN KEY (tg_user_id) REFERENCES contacts(tg_user_id)
);

CREATE TABLE IF NOT EXISTS budget_log (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  ts          INTEGER NOT NULL,
  service     TEXT    NOT NULL,   -- e.g. 'anthropic', 'openai-stt'
  tokens_in   INTEGER DEFAULT 0,
  tokens_out  INTEGER DEFAULT 0,
  cost_usd    REAL    NOT NULL,
  message_id  INTEGER,
  FOREIGN KEY (message_id) REFERENCES messages(id)
);

CREATE INDEX IF NOT EXISTS idx_budget_ts ON budget_log(ts DESC);
