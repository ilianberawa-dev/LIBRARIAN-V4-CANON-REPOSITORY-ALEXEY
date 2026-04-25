---
name: EVL-STAT-010
description: "Computes [low=p10, mid=p50, high=p90] asking-side interval, adjusted by compound formula back from freehold-pink-eq to subject-tenure-zone equivalent; applies market_health_gap if fresh."
catalog_id: EVL-STAT-010
revision: v1
grade: pending
phase: Evaluator
mission: Statistics
human_name: compute_price_interval
calibration_type: sql_query
applies_to: all listings with valid comp_range from one of COMP-005..009
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 10
---

# compute_price_interval (EVL-STAT-010.v1)

## Mission

computes [low=p10, mid=p50, high=p90] asking-side interval, adjusted by compound formula back from freehold-pink-eq to subject-tenure-zone equivalent; applies market_health_gap if fresh.

## Inputs

comp_range (from relevant COMP skill), tenure_decay, zone_multiplier, pma_overhead, expat_exit_penalty, subject size.

## Outputs

price_interval = {low_idr, mid_idr, high_idr}.

## Logic (draft)

Step 1: multiply comp freehold-pink-eq medians BACK by subject's tenure_decay × zone_multiplier to get subject-tenure-zone asking-equivalent. Step 2: if market_health_gap fresh → multiply all by (1 - gap%). Step 3: scale by subject size.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

inherits from comp_range sample + market_health_gap freshness

## Architectural lineage

This skill implements decisions from:

- **ADR-010** — Zone sensitivity matrix scenario-dependent
- **ADR-014** — Sample size thresholds (10 / 30)

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 10
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
