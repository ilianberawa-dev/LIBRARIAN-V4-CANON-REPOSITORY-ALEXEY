-- ─────────────────────────────────────────────────────────────
-- Realty Portal — initial schema
-- Источник: docs/architecture.md (канон Алексея, 2026-04-19).
-- Все таблицы соответствуют канону дословно.
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS raw_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL,
  source_url TEXT,
  raw_text TEXT NOT NULL,
  raw_html TEXT,
  status TEXT DEFAULT 'pending',  -- pending / processed / failed / duplicate
  property_id UUID,
  error_message TEXT,
  parsed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,                    -- villa / apartment / land / house
  district TEXT,                         -- Canggu / Seminyak / Ubud / ...
  address TEXT,
  bedrooms INTEGER,
  bathrooms INTEGER,
  area_m2 NUMERIC,
  land_area_m2 NUMERIC,
  price_usd NUMERIC,
  price_original TEXT,
  rental_period TEXT,                    -- yearly / monthly / freehold / leasehold
  lease_years INTEGER,
  contact_name TEXT,
  contact_phone TEXT,
  contact_whatsapp TEXT,
  source_url TEXT,
  source_name TEXT,
  image_urls TEXT[],
  raw_text TEXT,
  is_active BOOLEAN DEFAULT true,
  first_seen_at TIMESTAMPTZ DEFAULT now(),
  last_seen_at TIMESTAMPTZ DEFAULT now(),
  price_changed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_properties_district ON properties(district);
CREATE INDEX IF NOT EXISTS idx_properties_type ON properties(type);
CREATE INDEX IF NOT EXISTS idx_properties_price ON properties(price_usd);
CREATE INDEX IF NOT EXISTS idx_properties_active ON properties(is_active);

CREATE TABLE IF NOT EXISTS market_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
  district TEXT,
  total_listings INTEGER,
  new_listings_week INTEGER,
  median_price_usd NUMERIC,
  avg_price_usd NUMERIC,
  min_price_usd NUMERIC,
  max_price_usd NUMERIC,
  price_trend TEXT,
  price_change_pct NUMERIC,
  breakdown JSONB,
  summary_text TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,                    -- website / rss
  url TEXT,
  config JSONB DEFAULT '{}',
  parse_interval_minutes INTEGER DEFAULT 180,
  is_active BOOLEAN DEFAULT true,
  last_parsed_at TIMESTAMPTZ,
  total_parsed INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Стартовые записи sources для Бали (MVP)
INSERT INTO sources (name, type, url, parse_interval_minutes, is_active) VALUES
  ('rumah123_bali', 'website', 'https://www.rumah123.com/', 180, true),
  ('olx_bali',       'website', 'https://www.olx.co.id/',    180, false),
  ('balirealty',     'website', 'https://www.balirealty.com/', 180, false)
ON CONFLICT (name) DO NOTHING;
