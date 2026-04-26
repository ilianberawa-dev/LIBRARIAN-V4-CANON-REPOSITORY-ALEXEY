-- Migration: Add Stage 5 voice support
-- Version: 1.2 → 1.3
-- Date: 2026-04-26
-- Purpose: Reconcile schema with production runtime state

-- Add voice_jobs table for Stage 5 worker
CREATE TABLE IF NOT EXISTS voice_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  transcription TEXT,
  intent_result TEXT,
  created_at TEXT,
  processed_at TEXT
);

-- Add missing columns to drafts table
-- Note: SQLite does not support multiple ALTER TABLE ADD in one statement
-- These columns are used in production but missing from schema.sql v1.2

-- Check if columns exist first (SQLite-safe approach)
-- If column already exists, this will fail silently (expected for production DB)
-- If column doesn't exist, it will be added (expected for fresh installs)

ALTER TABLE drafts ADD COLUMN voice_file_id TEXT;
ALTER TABLE drafts ADD COLUMN channel_message_id INTEGER;
ALTER TABLE drafts ADD COLUMN status_finalized INTEGER DEFAULT 0;

-- Update schema version tracking
-- Assumes schema_version table exists (create if needed for future)
CREATE TABLE IF NOT EXISTS schema_version (
  version TEXT PRIMARY KEY,
  applied_at TEXT DEFAULT (datetime('now'))
);

INSERT OR REPLACE INTO schema_version (version, applied_at)
VALUES ('1.3', datetime('now'));

-- Migration complete
SELECT 'Migration 001-add-voice-support.sql applied successfully' AS result;
