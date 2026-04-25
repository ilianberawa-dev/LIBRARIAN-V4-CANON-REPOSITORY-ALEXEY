---
name: EVL-ORC-016
description: "Invokes skills 1-15 in correct order, manages skip-conditions (listing_subtype routing, validity early-exit, industrial force-uncalibrated); writes evaluation_status."
catalog_id: EVL-ORC-016
revision: v1
grade: pending
phase: Evaluator
mission: Orchestration
human_name: evaluate_sales_comparison
calibration_type: orchestrator
applies_to: meta — single skill per property evaluation
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 16
---

# evaluate_sales_comparison (EVL-ORC-016.v1)

## Mission

invokes skills 1-15 in correct order, manages skip-conditions (listing_subtype routing, validity early-exit, industrial force-uncalibrated); writes evaluation_status.

## Inputs

properties.id.

## Outputs

properties.evaluation_status ∈ {ok, uncalibrated, failed}.

## Logic (draft)

Orchestrator control flow: (1) enrich_area_context + classify_condition + classify_assumed_zoning in parallel. (2) normalize_tenure. (3) detect_validity: if fail → exit status=failed. (4) listing_subtype routing to correct find_comps_* skill (dual for ambiguous). (5) if commercial_industrial → force uncalibrated. (6) compute_price_interval + compute_z_score. (7) assess_liquidity + route_legal in parallel. (8) generate_advisory_narrative. (9) write evaluation_status.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

n/a (meta)

## Architectural lineage

This skill implements decisions from:

- **ADR-001** — 4-tool pipeline with status-field contract
- **ADR-006** — Scraper parametrized (not 4 separate skills)
- **ADR-007** — Status fields in properties (not separate table)
- **ADR-017** — 9-value listing_subtype enum including commercial
- **ADR-018** — Industrial forced uncalibrated

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 16
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
