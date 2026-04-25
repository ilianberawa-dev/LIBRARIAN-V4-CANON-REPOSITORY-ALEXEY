---
name: EVL-NAR-015
description: "Slot-fills S1 + S4 + S6 + S7 templates (+ conditional S_ZONE_CONFIRMATION, S_SUBTYPE_CONFIRMATION, S_COMMERCIAL_DISCLAIMER) per §12 and §12.1 diagnostic principle."
catalog_id: EVL-NAR-015
revision: v1
grade: pending
phase: Evaluator
mission: Narrative
human_name: generate_advisory_narrative
calibration_type: llm_prompt
applies_to: all listings with evaluation_status != failed
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 15
---

# generate_advisory_narrative (EVL-NAR-015.v1)

## Mission

slot-fills S1 + S4 + S6 + S7 templates (+ conditional S_ZONE_CONFIRMATION, S_SUBTYPE_CONFIRMATION, S_COMMERCIAL_DISCLAIMER) per §12 and §12.1 diagnostic principle.

## Inputs

all intermediate results from skills 1-14.

## Outputs

narrative_full_text + denormalized fields (narrative_s1_verdict, narrative_s4_z_score, narrative_s7_recommendation, narrative_s7_walk_away_price_idr).

## Logic (draft)

CRITICAL (ADR-008): diagnostic principle — narrative is NOT marketing text. Every adjective backed by number/ID traceable to specific skill/lookup. Template-driven slot-filling, no free-form generation. Post-gen regex check for banned phrases → regenerate if found.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

LLM-generated; post-generation check bans forbidden phrases ('is worth', 'guaranteed', etc.)

## Architectural lineage

This skill implements decisions from:

- **ADR-008** — Diagnostic narrative principle
- **ADR-003** — Zoning as soft-layer (not hard blocker)
- **ADR-017** — 9-value listing_subtype enum including commercial
- **ADR-018** — Industrial forced uncalibrated

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 15
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
