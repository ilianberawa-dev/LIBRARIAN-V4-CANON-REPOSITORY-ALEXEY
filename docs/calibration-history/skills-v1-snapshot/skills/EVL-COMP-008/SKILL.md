---
name: EVL-COMP-008
description: "Retrieves apartment-comps segmented by (area × zone × BR × size × management-presence × amenity bucket)."
catalog_id: EVL-COMP-008
revision: v1
grade: pending
phase: Evaluator
mission: Comparables
human_name: find_comps_apartment
calibration_type: sql_query
applies_to: listing_subtype = apartment
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 8
---

# find_comps_apartment (EVL-COMP-008.v1)

## Mission

retrieves apartment-comps segmented by (area × zone × BR × size × management-presence × amenity bucket).

## Inputs

specific_area, assumed_zone, bedrooms, building_size_m2, amenity_count_bucket, with_management (bool).

## Outputs

apt_comp_range = {median, p10, p90, sample_size}.

## Logic (draft)

MVP: minimal apartment fields (with_management boolean + amenity_count threshold). Phase 2: full management_company name + service_charge + M1-M5 brand classification.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

sample-based

## Architectural lineage

This skill implements decisions from:

- **ADR-017** — 9-value listing_subtype enum including commercial

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 8
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
