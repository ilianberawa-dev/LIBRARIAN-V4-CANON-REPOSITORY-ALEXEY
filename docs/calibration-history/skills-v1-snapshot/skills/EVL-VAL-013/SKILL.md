---
name: EVL-VAL-013
description: "Applies fail/warn rules per §11; surfaces violations to narrative S6."
catalog_id: EVL-VAL-013
revision: v1
grade: pending
phase: Evaluator
mission: Validity
human_name: detect_validity_violations
calibration_type: rule_based
applies_to: all listings entering Evaluator
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 13
---

# detect_validity_violations (EVL-VAL-013.v1)

## Mission

applies fail/warn rules per §11; surfaces violations to narrative S6.

## Inputs

all properties fields relevant to validity (price, size, tenure, listing_subtype, zoning, scenario).

## Outputs

validity_surfacing (structured list); additions to red_flags JSONB.

## Logic (draft)

Deterministic rule evaluator. Fail rules: price=0/NULL, size=0/NULL, tenure=unknown AND listing=land, leasehold AND lease_years NULL, SHM+leasehold conflict. Warn rules: leasehold<25y, price outside p10-p90, bata unconfirmed, gap stale, sample<10, zone confidence low. See §11.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

n/a

## Architectural lineage

This skill implements decisions from:

- **ADR-002** — Validator as separate tool

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 13
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
