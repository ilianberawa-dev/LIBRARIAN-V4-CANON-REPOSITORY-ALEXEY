---
name: EVL-STAT-011
description: "Computes robust z-score: z = 0.6745 × (value − median) / MAD (Iglewicz & Hoaglin 1993)."
catalog_id: EVL-STAT-011
revision: v1
grade: pending
phase: Evaluator
mission: Statistics
human_name: compute_z_score
calibration_type: sql_query
applies_to: all with valid comp_range
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 11
---

# compute_z_score (EVL-STAT-011.v1)

## Mission

computes robust z-score: z = 0.6745 × (value − median) / MAD (Iglewicz & Hoaglin 1993).

## Inputs

subject.price_per_m2_freehold_eq_idr, comp_range.median, comp_range.MAD.

## Outputs

narrative_s4_z_score NUMERIC(4,2); narrative_s4_z_calibrated BOOLEAN; calibration_level ∈ {high_confidence (sample≥30), low_confidence (10≤sample<30), uncalibrated (sample<10)}.

## Logic (draft)

CRITICAL: use MAD (Median Absolute Deviation), NOT standard deviation. std is outlier-sensitive — one scam listing @ $100M breaks entire segment's std. MAD robust. Coefficient 0.6745 is standard (Iglewicz & Hoaglin). If market_health_gap stale → z_calibrated=false with narrative flag.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

sample-based (ADR-014)

## Architectural lineage

This skill implements decisions from:

- **ADR-013** — Robust z-score via MAD (not std dev)
- **ADR-014** — Sample size thresholds (10 / 30)

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 11
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
