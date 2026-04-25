---
name: EVL-COMP-007
description: "Retrieves rumah-comps segmented similarly; returns stats."
catalog_id: EVL-COMP-007
revision: v1
grade: pending
phase: Evaluator
mission: Comparables
human_name: find_comps_rumah
calibration_type: sql_query
applies_to: listing_subtype = rumah (also one branch of ambiguous)
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 7
---

# find_comps_rumah (EVL-COMP-007.v1)

## Mission

retrieves rumah-comps segmented similarly; returns stats.

## Inputs

specific_area, assumed_zone, bedrooms, bathrooms, building_size_m2, condition_class.

## Outputs

rumah_comp_range = {median, p10, p90, sample_size}.

## Logic (draft)

Mirror of COMP-006 but for rumah segment. Separate comp-pool is critical because rumah targets local family buyer, price-per-m² systematically different from villa (tourist/expat segment).

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

sample-based

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

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 7
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
