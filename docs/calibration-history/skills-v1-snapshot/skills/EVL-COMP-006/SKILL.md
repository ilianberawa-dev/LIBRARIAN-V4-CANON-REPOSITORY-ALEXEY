---
name: EVL-COMP-006
description: "Retrieves villa-comps segmented by (area × zone × BR/BA × building-size bucket × condition ±1 class); returns stats."
catalog_id: EVL-COMP-006
revision: v1
grade: pending
phase: Evaluator
mission: Comparables
human_name: find_comps_villa
calibration_type: sql_query
applies_to: listing_subtype = villa (also one branch of ambiguous)
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 6
---

# find_comps_villa (EVL-COMP-006.v1)

## Mission

retrieves villa-comps segmented by (area × zone × BR/BA × building-size bucket × condition ±1 class); returns stats.

## Inputs

specific_area, assumed_zone, bedrooms, bathrooms, building_size_m2, condition_class.

## Outputs

villa_comp_range = {median, p10, p90, sample_size}.

## Logic (draft)

Villa-specific segmentation (do NOT merge with rumah — ADR-017 nonegotiable). Canggu villa median ~$350K, Canggu rumah median ~$150K — объединённая медиана $250K искажает z-score. Phase 2 может добавить pool_present, design_style filters.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

sample-based same as COMP-005

## Architectural lineage

This skill implements decisions from:

- **ADR-017** — 9-value listing_subtype enum including commercial
- **ADR-003** — Zoning as soft-layer (not hard blocker)

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 6
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
