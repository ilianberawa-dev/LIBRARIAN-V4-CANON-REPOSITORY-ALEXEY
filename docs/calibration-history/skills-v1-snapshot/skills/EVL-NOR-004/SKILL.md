---
name: EVL-NOR-004
description: "Applies compound normalization formula (§8) to produce price_per_m2 in freehold-pink-equivalent baseline for cross-comparison between properties with different tenure types, zones, scenarios."
catalog_id: EVL-NOR-004
revision: v2
grade: pending
phase: Evaluator
mission: Normalization
human_name: normalize_tenure_to_freehold_eq
calibration_type: deterministic_formula
applies_to: all listings with validation_status ∈ {ok, warn}
version_created: 2026-04-20
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §8
---

# normalize_tenure_to_freehold_eq (EVL-NOR-004.v2)

## Mission

Apply compound normalization formula from `sales-comparison-logic.md §8` to produce `price_per_m2_freehold_pink_equivalent` — a baseline that allows cross-comparing properties with different tenure durations, zone colors, and scenarios. Strictly multiplicative per ADR-011; leasehold-aware PMA compliance amortization per ADR-016.

## Inputs

From `properties` row (populated by Normalizer + Validator + preceding Evaluator skills):

| Field | Type | Source | Required |
|---|---|---|---|
| `price_idr` | BIGINT | `properties.price_idr` | yes |
| `land_size_m2` | NUMERIC | `properties.land_size_m2` | if listing_subtype=land |
| `building_size_m2` | NUMERIC | `properties.building_size_m2` | if listing_subtype≠land |
| `listing_subtype` | TEXT | `properties.listing_subtype` | yes |
| `tenure_type` | TEXT | `properties.tenure_type` ∈ {freehold, leasehold, hak_pakai, hgb} | yes |
| `lease_years_remaining` | INT | `properties.lease_years_remaining` | if tenure_type≠freehold |
| `scenario` | TEXT | evaluation input ∈ {foreign_investor_str_via_pma, land_for_development} | yes (MVP 2 scenarios) |
| `assumed_zone` | TEXT | EVL-CLS-003 output ∈ {pink, yellow, green, mixed} | yes |
| `zone_confidence` | TEXT | EVL-CLS-003 output ∈ {high, medium, low} | yes |
| `specific_area` | TEXT | `properties.specific_area` | yes (for expat_exit_penalty lookup) |

From `sources` lookups (read-only):

| Lookup | Key | Use |
|---|---|---|
| `_lookup_area_defaults` | `specific_area` | fallback zone_default (passed via CLS-003) |
| `_lookup_evaluation_constants` | `pma_compliance_overhead_pct_default`, `default_target_holding_years` | PMA amortization base |
| `_lookup_expat_exit_penalty` | `specific_area × scenario` | expat_exit_penalty_pct per area (Q-OPEN-13 pending calibration; MVP default 0.07 for foreign scenarios in Berawa/Canggu-tier areas, 0 for local scenarios) |
| `_lookup_zone_sensitivity_matrix` | `(scenario, assumed_zone)` | returns {min, mid, max} per §2.2 |

## Outputs

| Field | Type | Written to | Semantics |
|---|---|---|---|
| `price_per_m2_freehold_eq_idr` | BIGINT | `properties.price_per_m2_freehold_eq_idr` | Subject price_per_m² re-based to freehold-pink-equivalent baseline |
| `normalization_components` | JSONB | `properties.normalization_components` | Debug trace: {tenure_decay, zone_multiplier_applied, zone_multiplier_range, pma_applied, expat_applied, size_used_m2, formula_branch} — consumed by EVL-NAR-015 diagnostic narrative |

## Preconditions (skill fails loud if violated; orchestrator should have gated these)

- `price_idr > 0` — else raise `SkillError("NOR-004: price_idr must be > 0; EVL-VAL-013 should have gated")`
- `size_m2 > 0` where size_m2 = land_size_m2 (land) else building_size_m2
- `tenure_type` ∈ {freehold, leasehold, hak_pakai, hgb} — `unknown` fails validation upstream
- `lease_years_remaining > 0` if tenure_type≠freehold — else fail
- `assumed_zone` not NULL — CLS-003 must have run

## Logic (complete spec)

### Step 1 — select size basis

```
size_m2 = land_size_m2        if listing_subtype = land
          building_size_m2    otherwise
raw_per_m2 = price_idr / size_m2
```

### Step 2 — tenure_decay

```
tenure_decay =
    1.0                                       if tenure_type = freehold
    min(1.0, lease_years_remaining / 30)      if tenure_type ∈ {leasehold, hak_pakai, hgb}
```

### Step 3 — zone_multiplier (with confidence-driven policy per §2.3)

Read matrix from `_lookup_zone_sensitivity_matrix` by `(scenario, assumed_zone)`:

```
matrix_row = { min: X, mid: Y, max: Z }

zone_multiplier =
    matrix_row.mid      if zone_confidence = high
    matrix_row.mid      if zone_confidence = medium
    matrix_row.min      if zone_confidence = low       # conservative
```

### Step 4 — pma_compliance_overhead_pct_applied (leasehold-aware, per ADR-016)

```
if scenario = land_for_development:              # local buyer, no PT PMA
    pma_applied = 0

elif scenario = foreign_investor_str_via_pma:
    effective_amortization_years =
        default_target_holding_years             if tenure_type = freehold
        min(default_target_holding_years,        if tenure_type ∈ {leasehold, hak_pakai, hgb}
            lease_years_remaining)

    pma_applied = pma_compliance_overhead_pct_default
                × (effective_amortization_years / default_target_holding_years)

# defaults from _lookup_evaluation_constants:
#   pma_compliance_overhead_pct_default = 0.05   (ADR-016)
#   default_target_holding_years        = 10
```

**Critical**: `pma_compliance_overhead_pct` is COMPLIANCE cost of PT PMA existence (notary, accountant, LKPM, BPJS, virtual office). It is **NOT taxes**. Taxes (BPHTB/PPh/PPN/PBB) are a separate transaction-economics block — Q-OPEN-14, Phase 2. Do not conflate.

### Step 5 — expat_exit_penalty_pct

```
if scenario = land_for_development:
    expat_applied = 0

elif scenario = foreign_investor_str_via_pma:
    expat_applied = lookup _lookup_expat_exit_penalty by (specific_area, scenario)
                    default 0.07  if area not in lookup (Q-OPEN-13 pending)
```

### Step 6 — compound (strictly multiplicative, ADR-011)

```
price_per_m2_freehold_eq_idr =
    round(
        raw_per_m2
        / tenure_decay
        / zone_multiplier
        × (1 - pma_applied)
        × (1 - expat_applied)
    )
```

### Step 7 — write outputs

- Write `price_per_m2_freehold_eq_idr` to `properties` row.
- Write `normalization_components` JSONB with all intermediates for diagnostic trace.

## Numerical examples (verbatim from §8 — binding for unit tests)

### Example 1 — leasehold 20y, Berawa yellow, foreign_str, raw $1000/m²

- `tenure_decay = 20/30 = 0.667`
- `zone_multiplier = 0.80` (yellow mid, medium confidence)
- `effective_amortization_years = min(10, 20) = 10` → `pma_applied = 0.05 × (10/10) = 0.05`
- `expat_applied = 0.07` (Berawa MVP)
- Result: `1000 / 0.667 / 0.80 × 0.95 × 0.93 = $1,649/m²`

### Example 2 — leasehold 5y, Berawa yellow, foreign_str, raw $1000/m²

- `tenure_decay = 5/30 = 0.167`
- `zone_multiplier = 0.80`
- `effective_amortization_years = min(10, 5) = 5` → `pma_applied = 0.05 × (5/10) = 0.025`
- `expat_applied = 0.07`
- Result: `1000 / 0.167 / 0.80 × 0.975 × 0.93 = $6,774/m²`

Huge freehold-eq value indicates: **theoretical as-freehold worth ≈ $6,774/m², but liquidity near zero** (<25y triggers VAL-013 warn per §11). NAR-015 surfaces heavy warning.

### Example 3 — freehold Canggu pink, foreign_str, raw $1000/m²

- `tenure_decay = 1.0`, `zone_multiplier = 1.0`
- `pma_applied = 0.05 × (10/10) = 0.05`
- `expat_applied = 0.07`
- Result: `1000 × 0.95 × 0.93 = $883/m²`

### Example 4 — freehold Canggu pink, land_for_development, raw $1000/m²

- All multipliers = 1.0, both penalties = 0
- Result: `$1000/m²` (identity — baseline case)

### Example 5 — land_for_development yellow, freehold, raw $1000/m²

- `tenure_decay = 1.0`, `zone_multiplier = 0.75` (yellow mid for land_for_dev)
- pma = 0, expat = 0
- Result: `1000 / 0.75 = $1,333/m²`

## Failure modes (fail-loud per Alexey discipline)

| Condition | Behaviour |
|---|---|
| size_m2 = 0 or NULL (despite preconditions) | raise `SkillError("NOR-004: size_m2 invalid")` → orchestrator sets `evaluation_status=failed` |
| `_lookup_zone_sensitivity_matrix` miss for (scenario, zone) | raise — matrix must be complete per §2.2; treat as schema invariant violation |
| `_lookup_evaluation_constants` row missing | raise — migration 000X guarantees it; treat as ops failure |
| `_lookup_expat_exit_penalty` miss | use default 0.07 for foreign scenarios, log warning; **do not raise** (Q-OPEN-13 still calibrating) |
| Arithmetic overflow (price > 10^12 IDR) | raise — unrealistic for Bali MVP |

## Idempotency

Pure function of inputs + lookup snapshot. Same (price_idr, size, tenure, scenario, zone, area) + same lookup revision → identical output. Safe for re-run after lookup updates; orchestrator invalidates `evaluation_status=NULL` on lookup change per self-healing contract (`tool-architecture.md v1.1 §Trigger model`).

## Contracts

### Upstream (must be true before this skill runs)

- VAL-013 ran; `validation_status ∈ {ok, warn}`
- CTX-001 ran; area context available
- CLS-003 ran; `assumed_zone` + `zone_confidence` populated
- Normalizer: `listing_subtype`, `tenure_type`, `lease_years_remaining` (if applicable), `price_idr`, `{land,building}_size_m2` populated

### Downstream (what this skill guarantees to later skills)

- EVL-COMP-005..009: subject's `price_per_m2_freehold_eq_idr` is on same baseline as comp-pool medians (all comps pre-computed via same skill on prior runs)
- EVL-STAT-010: can reverse normalization by multiplying back `tenure_decay × zone_multiplier` to get subject-tenure-zone asking-equivalent interval
- EVL-STAT-011: z-score uses this normalized value vs `comp_range.median`
- EVL-NAR-015 (S4 section): receives `normalization_components` JSONB for diagnostic trace

## Calibration target (Day 3-5 battery)

**Calibration type = deterministic_formula → unit tests, no LLM triangulation** (ADR-019).

Test fixtures (binding):

| Fixture | Scenario | Tenure | Zone | Area | raw_per_m2 | Expected | Tolerance |
|---|---|---|---|---|---|---|---|
| ex1 | foreign_str | leasehold 20y | yellow (medium) | Berawa | $1000 | $1,649 | ±0.5% |
| ex2 | foreign_str | leasehold 5y | yellow (medium) | Berawa | $1000 | $6,774 | ±0.5% |
| ex3 | foreign_str | freehold | pink | Canggu | $1000 | $883 | ±0.5% |
| ex4 | land_for_dev | freehold | pink | Canggu | $1000 | $1,000 | ±0.5% |
| ex5 | land_for_dev | freehold | yellow | Kerobokan | $1000 | $1,333 | ±0.5% |

**Grade**: pass if all 5 fixtures produce expected value within ±0.5% rounding tolerance. Any failure → **do not promote** to production; investigate formula or lookup drift.

Failure mode coverage (separate test suite):

- size_m2=0 → expect `SkillError`
- matrix miss (synthetic bad data) → expect `SkillError`
- lookup constants missing (synthetic drop) → expect `SkillError`
- expat lookup miss → expect default 0.07 applied + warning log

## Architectural lineage

This skill implements decisions from:

- **ADR-011** — Tenure × Zone strictly multiplicative compound. **Do NOT refactor to additive without new superseding ADR — systematic under-valuation in multi-penalty cases.**
- **ADR-016** — `pma_compliance_overhead_pct` = compliance (NOT taxes), leasehold-aware amortization.

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Lookup dependencies (ops / migrations)

Three lookups beyond canon-4 must exist (migration 000X before production):

1. `sources._lookup_evaluation_constants` — key/value rows:
   - `pma_compliance_overhead_pct_default = 0.05`
   - `default_target_holding_years = 10`
2. `sources._lookup_zone_sensitivity_matrix` — per `(scenario, zone) → {min, mid, max}` per §2.2 table
3. `sources._lookup_expat_exit_penalty` — per `(specific_area, scenario) → pct`. MVP seed: Berawa/Canggu/Umalas/Seminyak = 0.07 for foreign_str; all 0 for land_for_dev. Q-OPEN-13 calibrates post-data.

All stored in `sources.config` JSONB per canon (ADR-007 — no new tables).

## Calibration history

*Empty at v2 creation. Populated Day 3-5.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source formula: `docs/sales-comparison-logic.md` v1.1 §8
- Zone matrix: `docs/sales-comparison-logic.md` v1.1 §2.2, §2.3
- ADR-011, ADR-016: `docs/decisions-log.md`
- Q-OPEN-13 (expat_exit_penalty calibration): `docs/open-questions.md`
- Q-OPEN-14 (transaction economics separate block): `docs/open-questions.md`
- Pipeline position: `docs/tool-architecture.md` v1.1 §4 (Evaluator)
