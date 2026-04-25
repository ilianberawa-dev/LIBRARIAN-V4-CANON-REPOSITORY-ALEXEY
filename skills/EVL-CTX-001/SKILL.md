---
name: EVL-CTX-001
description: "Pulls per-area defaults (zone_default, FAR, KDB, social_bucket, subak_risk, parent_district) + latest market_snapshot for (area × tenure × listing_subtype)."
catalog_id: EVL-CTX-001
revision: v1
grade: pending
phase: Evaluator
mission: Context
human_name: enrich_area_context
calibration_type: lookup
applies_to: all listings
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 1
---

# enrich_area_context (EVL-CTX-001.v1)

## Mission

pulls per-area defaults (zone_default, FAR, KDB, social_bucket, subak_risk, parent_district) + latest market_snapshot for (area × tenure × listing_subtype).

## Inputs

specific_area (from Normalizer).

## Outputs

area context attached to subject (in-memory dict, not written to DB — consumed by downstream skills in same orchestrator run).

## Logic (draft)

SQL: `SELECT get_area_default(:area, 'default_zoning'), get_area_default(:area, 'far_default'), ... FROM sources WHERE name='_lookup_area_defaults'`. If area not in gazetteer → set all defaults to NULL, red_flag 'area_not_in_gazetteer'.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

n/a (deterministic lookup)

## Architectural lineage

This skill implements decisions from:

- **ADR-009** — 27-area closed enum gazetteer

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 1
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
