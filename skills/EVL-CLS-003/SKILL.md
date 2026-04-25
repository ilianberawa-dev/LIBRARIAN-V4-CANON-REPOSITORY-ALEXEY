---
name: EVL-CLS-003
description: "Determines assumed_zone from area_defaults, corrected by listing hints; returns zone + confidence (high/medium/low)."
catalog_id: EVL-CLS-003
revision: v1
grade: pending
phase: Evaluator
mission: Classification
human_name: classify_assumed_zoning
calibration_type: llm_prompt
applies_to: all listings
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 3
---

# classify_assumed_zoning (EVL-CLS-003.v1)

## Mission

determines assumed_zone from area_defaults, corrected by listing hints; returns zone + confidence (high/medium/low).

## Inputs

specific_area, title, description_raw (for hints like 'zona hijau', 'sawah subak').

## Outputs

properties.zoning ∈ {pink, yellow, green, mixed, unknown}; properties.zoning_source TEXT; confidence level (separate field or narrative annotation).

## Logic (draft)

Stage 1: pull area_default zone from `_lookup_area_defaults`. Stage 2: LLM checks if listing description contradicts (e.g. area_default=pink but listing says 'sawah subak' → downgrade confidence to low, suggest green). Stage 3: if area not in gazetteer → confidence=low, narrative mentions via S_ZONE_CONFIRMATION.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

high (RTRW Phase 2) / medium (area_defaults match + listing consistent) / low (unknown area OR listing hints contradict defaults)

## Architectural lineage

This skill implements decisions from:

- **ADR-003** — Zoning as soft-layer (not hard blocker)
- **ADR-009** — 27-area closed enum gazetteer
- **ADR-010** — Zone sensitivity matrix scenario-dependent

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 3
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
