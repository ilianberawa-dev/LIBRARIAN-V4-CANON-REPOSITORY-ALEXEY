---
name: EVL-CLS-002
description: "Classifies condition into C1..C5 using visual + text hints; returns class + confidence (0..0.8 max) + source (text_hints / vision_llm / manual_override / unknown)."
catalog_id: EVL-CLS-002
revision: v1
grade: pending
phase: Evaluator
mission: Classification
human_name: classify_condition
calibration_type: llm_prompt
applies_to: all except listing_subtype=land
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 2
---

# classify_condition (EVL-CLS-002.v1)

## Mission

classifies condition into C1..C5 using visual + text hints; returns class + confidence (0..0.8 max) + source (text_hints / vision_llm / manual_override / unknown).

## Inputs

title, description_raw, photo_urls (array), amenities (if extracted).

## Outputs

properties.condition_class ∈ {C1, C2, C3, C4, C5, unknown}; properties.condition_confidence NUMERIC(3,2); properties.condition_source TEXT.

## Logic (draft)

LLM prompt with C1-C5 matrix table from §9 (visual + text signs). Returns JSON {class, confidence, source, reasoning}. Pydantic validates. Retry ×2 → Claude Haiku fallback. Phase 2 adds vision on photos.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

0-0.8 (never > 0.8; LLMs overconfident on aesthetic judgment)

## Architectural lineage

This skill implements decisions from:

- **ADR-008** — Diagnostic narrative principle
- **ADR-012** — Condition C1-C5 with renovation premium absorption

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 2
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
