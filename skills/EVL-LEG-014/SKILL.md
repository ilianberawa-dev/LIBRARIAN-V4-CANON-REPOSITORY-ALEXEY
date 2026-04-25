---
name: EVL-LEG-014
description: "Filters high-severity legal markers (from `_lookup_red_flags_vocabulary` categories tenure_risks, permit_risks, zoning_foreign_restricted); builds routing recommendation block for narrative S6."
catalog_id: EVL-LEG-014
revision: v1
grade: pending
phase: Evaluator
mission: Legal routing
human_name: route_legal_to_external
calibration_type: rule_based
applies_to: all listings with any red_flags
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row 14
---

# route_legal_to_external (EVL-LEG-014.v1)

## Mission

filters high-severity legal markers (from `_lookup_red_flags_vocabulary` categories tenure_risks, permit_risks, zoning_foreign_restricted); builds routing recommendation block for narrative S6.

## Inputs

red_flags JSONB.

## Outputs

legal_routing_block (structured text for narrative).

## Logic (draft)

Rule: IF any red_flag has severity='high' AND category IN ('tenure_risks', 'permit_risks', 'zoning_foreign_restricted') → add routing line 'документы передать в Индологос bot / PNB Law Firm до задатков'. Medium severity → 'отметить для юриста при due diligence'. Low/positive → no routing.

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

n/a

## Architectural lineage

This skill implements decisions from:

- **ADR-004** — Legal as external contour (Indologos + PNB)

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row 14
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
