---
name: EVL-COMP-005
description: "Retrieves ≥10 land-comps from properties WHERE listing_subtype=land AND same area × zone × size-bucket; returns price_per_m2_freehold_eq statistics (median, MAD, p10, p90)."
catalog_id: EVL-COMP-005
revision: v1
grade: pending
phase: Evaluator
mission: Comparables
human_name: find_comps_land
calibration_type: sql_query
applies_to: listing_subtype = land
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 5
---

# find_comps_land (EVL-COMP-005.v1)

## Mission

retrieves ≥10 land-comps from properties WHERE listing_subtype=land AND same area × zone × size-bucket; returns price_per_m2_freehold_eq statistics (median, MAD, p10, p90).

## Inputs

specific_area, assumed_zone, land_size_m2, size_bucket (derived).

## Outputs

land_comp_range = {median, p10, p90, sample_size}; attached to subject for price_interval step.

## Logic (draft)

SQL: `SELECT percentile_cont(ARRAY[0.10,0.50,0.90]) WITHIN GROUP (ORDER BY price_per_m2_freehold_eq_idr), COUNT(*) FROM properties WHERE specific_area=:area AND zoning=:zone AND listing_subtype='land' AND land_size_m2 BETWEEN :low AND :high AND evaluation_status IS NOT NULL AND last_seen_at > NOW()-INTERVAL '365 days'`. Size bucket: ±50% of subject.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

sample-based: ≥30 high, 10-29 low, <10 uncalibrated

## Architectural lineage

This skill implements decisions from:

- **ADR-003** — Zoning as soft-layer (not hard blocker)
- **ADR-017** — 9-value listing_subtype enum including commercial

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 5
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
