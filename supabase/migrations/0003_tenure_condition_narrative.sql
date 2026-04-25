-- ─────────────────────────────────────────────────────────────
-- Realty Portal — Migration 0003
-- Tenure branches + 5-class condition + zoning + social profile +
-- narrative output fields + scenarios + market_snapshots extensions.
-- Канон Алексея (4 таблицы) не нарушается: только ALTER TABLE.
-- ─────────────────────────────────────────────────────────────

-- === PROPERTIES table extensions ===

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS tenure_type TEXT
    CHECK (tenure_type IN ('freehold', 'leasehold', 'hak_pakai', 'hgb', 'unknown'));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS lease_years_remaining INTEGER
    CHECK (lease_years_remaining IS NULL OR (lease_years_remaining >= 0 AND lease_years_remaining <= 99));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS lease_duration_original INTEGER;

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS condition_class TEXT
    CHECK (condition_class IN ('C1', 'C2', 'C3', 'C4', 'C5', 'unknown'));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS condition_confidence NUMERIC(3,2)
    CHECK (condition_confidence IS NULL OR (condition_confidence >= 0 AND condition_confidence <= 1));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS condition_source TEXT
    CHECK (condition_source IN ('text_hints', 'vision_llm', 'manual_override', 'unknown'));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS zoning TEXT
    CHECK (zoning IN ('pink', 'yellow', 'green', 'mixed', 'unknown'));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS zoning_source TEXT
    CHECK (zoning_source IN ('rtrw_map', 'area_default', 'listing_hint', 'unknown'));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS specific_area TEXT;

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS social_bucket TEXT
    CHECK (social_bucket IN ('expat_enclave', 'mixed_international', 'mixed_transitional', 'local_dominant', 'unknown'));

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS red_flags JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS signal_flags JSONB DEFAULT '[]'::jsonb;

-- Scenario applicability
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS scenario_flip_disabled_reason TEXT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS scenario_land_dev_viable BOOLEAN;

-- FAR/KDB for land_for_development
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS far_default NUMERIC(3,2);
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS kdb_default NUMERIC(3,2);
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS max_buildable_m2 INTEGER;

-- Price range support (Patch #4 Q5)
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_idr BIGINT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_min_idr BIGINT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_max_idr BIGINT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS is_price_range BOOLEAN DEFAULT FALSE;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS is_negotiable BOOLEAN DEFAULT FALSE;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_raw_string TEXT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_currency_raw TEXT;

-- Sizes
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS land_size_m2 INTEGER;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS land_size_raw TEXT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS building_size_m2 INTEGER;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS building_size_raw TEXT;

-- Tenure normalization result (Patch #4 Q3) — GENERATED ALWAYS STORED
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS decay_factor NUMERIC(4,3)
    GENERATED ALWAYS AS (
        CASE
            WHEN tenure_type = 'freehold' THEN 1.000
            WHEN tenure_type IN ('leasehold', 'hak_pakai', 'hgb')
                 AND lease_years_remaining IS NOT NULL
                 AND lease_years_remaining >= 30 THEN 1.000
            WHEN tenure_type IN ('leasehold', 'hak_pakai', 'hgb')
                 AND lease_years_remaining IS NOT NULL
                 AND lease_years_remaining > 0 THEN
                 ROUND((lease_years_remaining::numeric / 30.0), 3)
            ELSE NULL
        END
    ) STORED;

-- Inline formula (PG не разрешает ссылку на другую GENERATED колонку)
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_per_m2_freehold_eq_idr BIGINT
    GENERATED ALWAYS AS (
        CASE
            WHEN price_idr IS NULL OR land_size_m2 IS NULL OR land_size_m2 <= 0 THEN NULL
            WHEN tenure_type = 'freehold' THEN
                ROUND(price_idr::numeric / land_size_m2)::bigint
            WHEN tenure_type IN ('leasehold', 'hak_pakai', 'hgb')
                 AND lease_years_remaining IS NOT NULL
                 AND lease_years_remaining >= 30 THEN
                ROUND(price_idr::numeric / land_size_m2)::bigint
            WHEN tenure_type IN ('leasehold', 'hak_pakai', 'hgb')
                 AND lease_years_remaining IS NOT NULL
                 AND lease_years_remaining > 0 THEN
                ROUND(price_idr::numeric / (land_size_m2 * (lease_years_remaining::numeric / 30.0)))::bigint
            ELSE NULL
        END
    ) STORED;

-- Days on market
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS first_seen_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS site_posted_at TIMESTAMPTZ;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS site_updated_at TIMESTAMPTZ;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS days_on_market INTEGER;

-- Contacts (Patch #4 Q5)
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS contact_whatsapp TEXT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS contact_obfuscated BOOLEAN DEFAULT FALSE;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS agent_name TEXT;

-- Narrative output (denormalized for fast retrieval)
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_s1_verdict TEXT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_s4_z_score NUMERIC(4,2);
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_s4_z_calibrated BOOLEAN DEFAULT FALSE;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_s7_recommendation TEXT
    CHECK (narrative_s7_recommendation IN ('pursue_at_asking', 'pursue_with_negotiation', 'watch_for_price_drop', 'skip'));
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_s7_walk_away_price_idr BIGINT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_scenario TEXT
    CHECK (narrative_scenario IN ('foreign_investor_str_via_pma', 'land_for_development', 'flip_to_villa', 'foreign_investor_ltr_via_pma', 'local_primary_residence', 'lifestyle_buyer'));
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_full_text TEXT;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS narrative_generated_at TIMESTAMPTZ;

-- Processing metadata
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS normalization_status TEXT DEFAULT 'raw'
    CHECK (normalization_status IN ('raw', 'partial', 'complete', 'failed'));
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS normalization_attempted_at TIMESTAMPTZ;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS normalization_errors JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS normalization_llm_used TEXT;

-- Price history (Patch #4 — track price changes over time)
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_history JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS price_changed_at TIMESTAMPTZ;

-- Listing type (land / villa / rumah / apartment)
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS listing_type TEXT
    CHECK (listing_type IN ('land', 'villa', 'rumah', 'apartment', 'ruko', 'unknown'));

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prop_tenure_area ON public.properties(tenure_type, specific_area);
CREATE INDEX IF NOT EXISTS idx_prop_lease_remaining ON public.properties(lease_years_remaining)
    WHERE tenure_type = 'leasehold';
CREATE INDEX IF NOT EXISTS idx_prop_condition ON public.properties(condition_class);
CREATE INDEX IF NOT EXISTS idx_prop_z_score ON public.properties(narrative_s4_z_score);
CREATE INDEX IF NOT EXISTS idx_prop_recommendation ON public.properties(narrative_s7_recommendation);
CREATE INDEX IF NOT EXISTS idx_prop_norm_status ON public.properties(normalization_status);
CREATE INDEX IF NOT EXISTS idx_prop_listing_type ON public.properties(listing_type);
CREATE INDEX IF NOT EXISTS idx_prop_freehold_eq ON public.properties(price_per_m2_freehold_eq_idr)
    WHERE price_per_m2_freehold_eq_idr IS NOT NULL;

-- === MARKET_SNAPSHOTS table extensions ===

ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS market_health_gap_pct NUMERIC(5,2);
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS market_health_gap_entered_at TIMESTAMPTZ;
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS market_health_gap_source TEXT
    CHECK (market_health_gap_source IN ('broker_manual', 'computed_from_transactions', 'industry_report', 'unknown'));

ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS median_price_per_m2_freehold_idr BIGINT;
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS median_price_per_m2_leasehold_30yr_equiv_idr BIGINT;
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS median_str_yield_pct NUMERIC(4,2);
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS median_ltr_yield_pct NUMERIC(4,2);
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS median_days_on_market INTEGER;
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS sample_size INTEGER;
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS tenure_segment TEXT
    CHECK (tenure_segment IN ('freehold', 'leasehold_30yr_equiv', 'all'));
ALTER TABLE public.market_snapshots ADD COLUMN IF NOT EXISTS listing_type_segment TEXT;

-- Fail-safe freshness check for market_health_gap
CREATE OR REPLACE FUNCTION public.is_market_gap_fresh(p_snapshot_id UUID)
RETURNS BOOLEAN AS $$
    SELECT (
        market_health_gap_pct IS NOT NULL
        AND market_health_gap_entered_at IS NOT NULL
        AND market_health_gap_entered_at > NOW() - INTERVAL '90 days'
    )
    FROM public.market_snapshots
    WHERE id = p_snapshot_id;
$$ LANGUAGE SQL STABLE;

-- Helper: lookup из sources JSONB (Patch #4 Q1 через sources)
CREATE OR REPLACE FUNCTION public.get_area_default(p_area TEXT, p_field TEXT)
RETURNS JSONB AS $$
    SELECT config -> p_area -> p_field
    FROM public.sources
    WHERE name = '_lookup_area_defaults' AND type = 'lookup';
$$ LANGUAGE SQL STABLE;

-- Helper: gazetteer membership check
CREATE OR REPLACE FUNCTION public.is_known_area(p_area TEXT)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.sources
        WHERE name = '_lookup_bali_gazetteer'
          AND type = 'lookup'
          AND config->'areas' ? p_area
    );
$$ LANGUAGE SQL STABLE;
