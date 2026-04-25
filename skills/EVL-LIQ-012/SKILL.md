---
name: EVL-LIQ-012
description: "Classifies liquidity signal: strong (<90 days, no price drops) / medium (90-365 days OR 1 drop) / weak (>365 days OR 2+ drops) / dead (>1000 days, excluded from comp medians)."
catalog_id: EVL-LIQ-012
revision: v1
grade: pending
phase: Evaluator
mission: Liquidity
human_name: assess_liquidity_proxy
calibration_type: rule_based
applies_to: all listings
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 12
---

# assess_liquidity_proxy (EVL-LIQ-012.v1)

## Mission

classifies liquidity signal: strong (<90 days, no price drops) / medium (90-365 days OR 1 drop) / weak (>365 days OR 2+ drops) / dead (>1000 days, excluded from comp medians).

## Inputs

days_on_market, first_seen_at, last_seen_at, price_history (JSONB).

## Outputs

liquidity_signal TEXT; attached to narrative S7 reasoning.

## Logic (draft)

Rule table: <90d+no_drops=strong, 90-365d=medium, >365d=weak, >1000d=dead. Price drops detection: len(price_history) > 1. Dead listings excluded from comp medians (ADR-014 related).

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

n/a (deterministic rule table)

## Architectural lineage

This skill implements decisions from:

- (no skill-specific ADR; falls under general pipeline ADR-001, ADR-007)

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 12
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
