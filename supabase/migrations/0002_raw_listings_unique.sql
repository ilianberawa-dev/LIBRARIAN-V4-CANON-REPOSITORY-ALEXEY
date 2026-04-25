-- ─────────────────────────────────────────────────────────────
-- Realty Portal — raw_listings dedup
-- Полный UNIQUE индекс на source_url для идемпотентного re-run
-- скилла parse_listings_web (ON CONFLICT DO NOTHING).
-- Полный (не partial), так как ON CONFLICT inference требует
-- non-partial index. Несколько NULL-значений допускаются по
-- default NULLS DISTINCT.
-- ─────────────────────────────────────────────────────────────

DROP INDEX IF EXISTS public.raw_listings_source_url_uidx;
CREATE UNIQUE INDEX raw_listings_source_url_uidx
  ON public.raw_listings (source_url);
