---
name: EVL-COMP-009
description: "Retrieves commercial-comps by (area × zone × commercial_subtype × size bucket); **for commercial_industrial → forced uncalibrated regardless of sample (ADR-018)**."
catalog_id: EVL-COMP-009
revision: v1
grade: pending
phase: Evaluator
mission: Comparables
human_name: find_comps_commercial
calibration_type: sql_query
applies_to: listing_subtype ∈ {commercial_office, commercial_warehouse, commercial_industrial, commercial_shop}
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 9
---

# find_comps_commercial (EVL-COMP-009.v1)

## Mission

retrieves commercial-comps by (area × zone × commercial_subtype × size bucket); **for commercial_industrial → forced uncalibrated regardless of sample (ADR-018)**.

## Inputs

specific_area, assumed_zone, commercial_subtype, building_size_m2, land_size_m2 (where applicable).

## Outputs

commercial_comp_range = {median, p10, p90, sample_size, forced_uncalibrated (bool)}.

## Logic (draft)

Parametrized by commercial_subtype. Primary metric: price_per_m2_building (not land) for office/warehouse/shop. For industrial: ALWAYS returns forced_uncalibrated=true, regardless of sample size. Narrative then triggers S_COMMERCIAL_DISCLAIMER industrial variant.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

sample-based; commercial_industrial always uncalibrated

## Architectural lineage

This skill implements decisions from:

- **ADR-017** — 9-value listing_subtype enum including commercial
- **ADR-018** — Industrial forced uncalibrated

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 9
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
