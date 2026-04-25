#!/usr/bin/env python3
"""Generate 16 SKILL.md drafts v1 from sales-comparison-logic.md v1.1.

Deterministic generator — no LLM. Reads skill metadata from hardcoded
catalog table (derived from §5 of sales-comparison-logic.md v1.1 +
ADR→Skill mapping from decisions-log.md).

Output: realty-portal/skills/<catalog_id>/SKILL.md
Each file has YAML frontmatter + Mission + Inputs/Outputs + Logic
placeholder + Architectural lineage (ADR links) + Calibration history.

Usage (from realty-portal root):
    python3 scripts/gen_skills_v1_from_logic.py
"""
from __future__ import annotations

import os
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
GENERATED_DATE = date.today().isoformat()

# ─────────────────────────────────────────────────────────────
# Skill catalog — ground truth from sales-comparison-logic.md §5
# + ADR→Skill mapping from decisions-log.md
# ─────────────────────────────────────────────────────────────

SKILLS: list[dict] = [
    {
        "catalog_id": "EVL-CTX-001",
        "human_name": "enrich_area_context",
        "mission": "Context",
        "calibration_type": "lookup",
        "applies_to": "all listings",
        "inputs": "specific_area (from Normalizer)",
        "does": "pulls per-area defaults (zone_default, FAR, KDB, social_bucket, subak_risk, parent_district) + latest market_snapshot for (area × tenure × listing_subtype)",
        "outputs": "area context attached to subject (in-memory dict, not written to DB — consumed by downstream skills in same orchestrator run)",
        "confidence": "n/a (deterministic lookup)",
        "adrs": ["ADR-009"],
        "source_row": 1,
        "logic_hint": "SQL: `SELECT get_area_default(:area, 'default_zoning'), get_area_default(:area, 'far_default'), ... FROM sources WHERE name='_lookup_area_defaults'`. If area not in gazetteer → set all defaults to NULL, red_flag 'area_not_in_gazetteer'.",
    },
    {
        "catalog_id": "EVL-CLS-002",
        "human_name": "classify_condition",
        "mission": "Classification",
        "calibration_type": "llm_prompt",
        "applies_to": "all except listing_subtype=land",
        "inputs": "title, description_raw, photo_urls (array), amenities (if extracted)",
        "does": "classifies condition into C1..C5 using visual + text hints; returns class + confidence (0..0.8 max) + source (text_hints / vision_llm / manual_override / unknown)",
        "outputs": "properties.condition_class ∈ {C1, C2, C3, C4, C5, unknown}; properties.condition_confidence NUMERIC(3,2); properties.condition_source TEXT",
        "confidence": "0-0.8 (never > 0.8; LLMs overconfident on aesthetic judgment)",
        "adrs": ["ADR-008", "ADR-012"],
        "source_row": 2,
        "logic_hint": "LLM prompt with C1-C5 matrix table from §9 (visual + text signs). Returns JSON {class, confidence, source, reasoning}. Pydantic validates. Retry ×2 → Claude Haiku fallback. Phase 2 adds vision on photos.",
    },
    {
        "catalog_id": "EVL-CLS-003",
        "human_name": "classify_assumed_zoning",
        "mission": "Classification",
        "calibration_type": "llm_prompt",
        "applies_to": "all listings",
        "inputs": "specific_area, title, description_raw (for hints like 'zona hijau', 'sawah subak')",
        "does": "determines assumed_zone from area_defaults, corrected by listing hints; returns zone + confidence (high/medium/low)",
        "outputs": "properties.zoning ∈ {pink, yellow, green, mixed, unknown}; properties.zoning_source TEXT; confidence level (separate field or narrative annotation)",
        "confidence": "high (RTRW Phase 2) / medium (area_defaults match + listing consistent) / low (unknown area OR listing hints contradict defaults)",
        "adrs": ["ADR-003", "ADR-009", "ADR-010"],
        "source_row": 3,
        "logic_hint": "Stage 1: pull area_default zone from `_lookup_area_defaults`. Stage 2: LLM checks if listing description contradicts (e.g. area_default=pink but listing says 'sawah subak' → downgrade confidence to low, suggest green). Stage 3: if area not in gazetteer → confidence=low, narrative mentions via S_ZONE_CONFIRMATION.",
    },
    {
        "catalog_id": "EVL-NOR-004",
        "human_name": "normalize_tenure_to_freehold_eq",
        "mission": "Normalization",
        "calibration_type": "deterministic_formula",
        "applies_to": "all listings with price + size + tenure",
        "inputs": "price_idr, land_size_m2, tenure_type, lease_years_remaining, scenario, assumed_zone, specific_area",
        "does": "applies compound normalization formula (§8) to produce price_per_m2 in freehold-pink-equivalent baseline for cross-comparison",
        "outputs": "price_per_m2_freehold_eq_idr (BIGINT, GENERATED ALWAYS AS STORED column in properties)",
        "confidence": "deterministic — no LLM, no sampling",
        "adrs": ["ADR-011", "ADR-016"],
        "source_row": 4,
        "logic_hint": "Formula (strictly multiplicative, ADR-011): price/size ÷ tenure_decay ÷ zone_multiplier × (1 − pma_compliance_overhead_pct_applied) × (1 − expat_exit_penalty_pct). IMPORTANT (ADR-016): `pma_compliance_overhead_pct` is COMPLIANCE costs on PT PMA (notary, accountant, LKPM, BPJS, virtual office) — NOT taxes. Taxes (BPHTB, PPh, PPN, PBB) = separate transaction-economics block (Q-OPEN-14, Phase 2). Leasehold-aware amortization: pma_applied = 0.05 × (effective_amortization_years / 10), where effective_amortization_years = freehold: 10; leasehold: min(10, lease_years_remaining). See §8 numerical examples: leasehold-20y → 5% applied ($1,649/m²); leasehold-5y → 2.5% applied ($6,774/m² but heavy warn на <25y). Implemented as PostgreSQL generated column in migration 0003 + lookup `_lookup_evaluation_constants` for defaults.",
    },
    {
        "catalog_id": "EVL-COMP-005",
        "human_name": "find_comps_land",
        "mission": "Comparables",
        "calibration_type": "sql_query",
        "applies_to": "listing_subtype = land",
        "inputs": "specific_area, assumed_zone, land_size_m2, size_bucket (derived)",
        "does": "retrieves ≥10 land-comps from properties WHERE listing_subtype=land AND same area × zone × size-bucket; returns price_per_m2_freehold_eq statistics (median, MAD, p10, p90)",
        "outputs": "land_comp_range = {median, p10, p90, sample_size}; attached to subject for price_interval step",
        "confidence": "sample-based: ≥30 high, 10-29 low, <10 uncalibrated",
        "adrs": ["ADR-003", "ADR-017"],
        "source_row": 5,
        "logic_hint": "SQL: `SELECT percentile_cont(ARRAY[0.10,0.50,0.90]) WITHIN GROUP (ORDER BY price_per_m2_freehold_eq_idr), COUNT(*) FROM properties WHERE specific_area=:area AND zoning=:zone AND listing_subtype='land' AND land_size_m2 BETWEEN :low AND :high AND evaluation_status IS NOT NULL AND last_seen_at > NOW()-INTERVAL '365 days'`. Size bucket: ±50% of subject.",
    },
    {
        "catalog_id": "EVL-COMP-006",
        "human_name": "find_comps_villa",
        "mission": "Comparables",
        "calibration_type": "sql_query",
        "applies_to": "listing_subtype = villa (also one branch of ambiguous)",
        "inputs": "specific_area, assumed_zone, bedrooms, bathrooms, building_size_m2, condition_class",
        "does": "retrieves villa-comps segmented by (area × zone × BR/BA × building-size bucket × condition ±1 class); returns stats",
        "outputs": "villa_comp_range = {median, p10, p90, sample_size}",
        "confidence": "sample-based same as COMP-005",
        "adrs": ["ADR-017", "ADR-003"],
        "source_row": 6,
        "logic_hint": "Villa-specific segmentation (do NOT merge with rumah — ADR-017 nonegotiable). Canggu villa median ~$350K, Canggu rumah median ~$150K — объединённая медиана $250K искажает z-score. Phase 2 может добавить pool_present, design_style filters.",
    },
    {
        "catalog_id": "EVL-COMP-007",
        "human_name": "find_comps_rumah",
        "mission": "Comparables",
        "calibration_type": "sql_query",
        "applies_to": "listing_subtype = rumah (also one branch of ambiguous)",
        "inputs": "specific_area, assumed_zone, bedrooms, bathrooms, building_size_m2, condition_class",
        "does": "retrieves rumah-comps segmented similarly; returns stats",
        "outputs": "rumah_comp_range = {median, p10, p90, sample_size}",
        "confidence": "sample-based",
        "adrs": ["ADR-017", "ADR-003"],
        "source_row": 7,
        "logic_hint": "Mirror of COMP-006 but for rumah segment. Separate comp-pool is critical because rumah targets local family buyer, price-per-m² systematically different from villa (tourist/expat segment).",
    },
    {
        "catalog_id": "EVL-COMP-008",
        "human_name": "find_comps_apartment",
        "mission": "Comparables",
        "calibration_type": "sql_query",
        "applies_to": "listing_subtype = apartment",
        "inputs": "specific_area, assumed_zone, bedrooms, building_size_m2, amenity_count_bucket, with_management (bool)",
        "does": "retrieves apartment-comps segmented by (area × zone × BR × size × management-presence × amenity bucket)",
        "outputs": "apt_comp_range = {median, p10, p90, sample_size}",
        "confidence": "sample-based",
        "adrs": ["ADR-017"],
        "source_row": 8,
        "logic_hint": "MVP: minimal apartment fields (with_management boolean + amenity_count threshold). Phase 2: full management_company name + service_charge + M1-M5 brand classification.",
    },
    {
        "catalog_id": "EVL-COMP-009",
        "human_name": "find_comps_commercial",
        "mission": "Comparables",
        "calibration_type": "sql_query",
        "applies_to": "listing_subtype ∈ {commercial_office, commercial_warehouse, commercial_industrial, commercial_shop}",
        "inputs": "specific_area, assumed_zone, commercial_subtype, building_size_m2, land_size_m2 (where applicable)",
        "does": "retrieves commercial-comps by (area × zone × commercial_subtype × size bucket); **for commercial_industrial → forced uncalibrated regardless of sample (ADR-018)**",
        "outputs": "commercial_comp_range = {median, p10, p90, sample_size, forced_uncalibrated (bool)}",
        "confidence": "sample-based; commercial_industrial always uncalibrated",
        "adrs": ["ADR-017", "ADR-018"],
        "source_row": 9,
        "logic_hint": "Parametrized by commercial_subtype. Primary metric: price_per_m2_building (not land) for office/warehouse/shop. For industrial: ALWAYS returns forced_uncalibrated=true, regardless of sample size. Narrative then triggers S_COMMERCIAL_DISCLAIMER industrial variant.",
    },
    {
        "catalog_id": "EVL-STAT-010",
        "human_name": "compute_price_interval",
        "mission": "Statistics",
        "calibration_type": "sql_query",
        "applies_to": "all listings with valid comp_range from one of COMP-005..009",
        "inputs": "comp_range (from relevant COMP skill), tenure_decay, zone_multiplier, pma_overhead, expat_exit_penalty, subject size",
        "does": "computes [low=p10, mid=p50, high=p90] asking-side interval, adjusted by compound formula back from freehold-pink-eq to subject-tenure-zone equivalent; applies market_health_gap if fresh",
        "outputs": "price_interval = {low_idr, mid_idr, high_idr}",
        "confidence": "inherits from comp_range sample + market_health_gap freshness",
        "adrs": ["ADR-010", "ADR-014"],
        "source_row": 10,
        "logic_hint": "Step 1: multiply comp freehold-pink-eq medians BACK by subject's tenure_decay × zone_multiplier to get subject-tenure-zone asking-equivalent. Step 2: if market_health_gap fresh → multiply all by (1 - gap%). Step 3: scale by subject size.",
    },
    {
        "catalog_id": "EVL-STAT-011",
        "human_name": "compute_z_score",
        "mission": "Statistics",
        "calibration_type": "sql_query",
        "applies_to": "all with valid comp_range",
        "inputs": "subject.price_per_m2_freehold_eq_idr, comp_range.median, comp_range.MAD",
        "does": "computes robust z-score: z = 0.6745 × (value − median) / MAD (Iglewicz & Hoaglin 1993)",
        "outputs": "narrative_s4_z_score NUMERIC(4,2); narrative_s4_z_calibrated BOOLEAN; calibration_level ∈ {high_confidence (sample≥30), low_confidence (10≤sample<30), uncalibrated (sample<10)}",
        "confidence": "sample-based (ADR-014)",
        "adrs": ["ADR-013", "ADR-014"],
        "source_row": 11,
        "logic_hint": "CRITICAL: use MAD (Median Absolute Deviation), NOT standard deviation. std is outlier-sensitive — one scam listing @ $100M breaks entire segment's std. MAD robust. Coefficient 0.6745 is standard (Iglewicz & Hoaglin). If market_health_gap stale → z_calibrated=false with narrative flag.",
    },
    {
        "catalog_id": "EVL-LIQ-012",
        "human_name": "assess_liquidity_proxy",
        "mission": "Liquidity",
        "calibration_type": "rule_based",
        "applies_to": "all listings",
        "inputs": "days_on_market, first_seen_at, last_seen_at, price_history (JSONB)",
        "does": "classifies liquidity signal: strong (<90 days, no price drops) / medium (90-365 days OR 1 drop) / weak (>365 days OR 2+ drops) / dead (>1000 days, excluded from comp medians)",
        "outputs": "liquidity_signal TEXT; attached to narrative S7 reasoning",
        "confidence": "n/a (deterministic rule table)",
        "adrs": [],
        "source_row": 12,
        "logic_hint": "Rule table: <90d+no_drops=strong, 90-365d=medium, >365d=weak, >1000d=dead. Price drops detection: len(price_history) > 1. Dead listings excluded from comp medians (ADR-014 related).",
    },
    {
        "catalog_id": "EVL-VAL-013",
        "human_name": "detect_validity_violations",
        "mission": "Validity",
        "calibration_type": "rule_based",
        "applies_to": "all listings entering Evaluator",
        "inputs": "all properties fields relevant to validity (price, size, tenure, listing_subtype, zoning, scenario)",
        "does": "applies fail/warn rules per §11; surfaces violations to narrative S6",
        "outputs": "validity_surfacing (structured list); additions to red_flags JSONB",
        "confidence": "n/a",
        "adrs": ["ADR-002"],
        "source_row": 13,
        "logic_hint": "Deterministic rule evaluator. Fail rules: price=0/NULL, size=0/NULL, tenure=unknown AND listing=land, leasehold AND lease_years NULL, SHM+leasehold conflict. Warn rules: leasehold<25y, price outside p10-p90, bata unconfirmed, gap stale, sample<10, zone confidence low. See §11.",
    },
    {
        "catalog_id": "EVL-LEG-014",
        "human_name": "route_legal_to_external",
        "mission": "Legal routing",
        "calibration_type": "rule_based",
        "applies_to": "all listings with any red_flags",
        "inputs": "red_flags JSONB",
        "does": "filters high-severity legal markers (from `_lookup_red_flags_vocabulary` categories tenure_risks, permit_risks, zoning_foreign_restricted); builds routing recommendation block for narrative S6",
        "outputs": "legal_routing_block (structured text for narrative)",
        "confidence": "n/a",
        "adrs": ["ADR-004"],
        "source_row": 14,
        "logic_hint": "Rule: IF any red_flag has severity='high' AND category IN ('tenure_risks', 'permit_risks', 'zoning_foreign_restricted') → add routing line 'документы передать в Индологос bot / PNB Law Firm до задатков'. Medium severity → 'отметить для юриста при due diligence'. Low/positive → no routing.",
    },
    {
        "catalog_id": "EVL-NAR-015",
        "human_name": "generate_advisory_narrative",
        "mission": "Narrative",
        "calibration_type": "llm_prompt",
        "applies_to": "all listings with evaluation_status != failed",
        "inputs": "all intermediate results from skills 1-14",
        "does": "slot-fills S1 + S4 + S6 + S7 templates (+ conditional S_ZONE_CONFIRMATION, S_SUBTYPE_CONFIRMATION, S_COMMERCIAL_DISCLAIMER) per §12 and §12.1 diagnostic principle",
        "outputs": "narrative_full_text + denormalized fields (narrative_s1_verdict, narrative_s4_z_score, narrative_s7_recommendation, narrative_s7_walk_away_price_idr)",
        "confidence": "LLM-generated; post-generation check bans forbidden phrases ('is worth', 'guaranteed', etc.)",
        "adrs": ["ADR-008", "ADR-003", "ADR-017", "ADR-018"],
        "source_row": 15,
        "logic_hint": "CRITICAL (ADR-008): diagnostic principle — narrative is NOT marketing text. Every adjective backed by number/ID traceable to specific skill/lookup. Template-driven slot-filling, no free-form generation. Post-gen regex check for banned phrases → regenerate if found.",
    },
    {
        "catalog_id": "EVL-ORC-016",
        "human_name": "evaluate_sales_comparison",
        "mission": "Orchestration",
        "calibration_type": "orchestrator",
        "applies_to": "meta — single skill per property evaluation",
        "inputs": "properties.id",
        "does": "invokes skills 1-15 in correct order, manages skip-conditions (listing_subtype routing, validity early-exit, industrial force-uncalibrated); writes evaluation_status",
        "outputs": "properties.evaluation_status ∈ {ok, uncalibrated, failed}",
        "confidence": "n/a (meta)",
        "adrs": ["ADR-001", "ADR-006", "ADR-007", "ADR-017", "ADR-018"],
        "source_row": 16,
        "logic_hint": "Orchestrator control flow: (1) enrich_area_context + classify_condition + classify_assumed_zoning in parallel. (2) normalize_tenure. (3) detect_validity: if fail → exit status=failed. (4) listing_subtype routing to correct find_comps_* skill (dual for ambiguous). (5) if commercial_industrial → force uncalibrated. (6) compute_price_interval + compute_z_score. (7) assess_liquidity + route_legal in parallel. (8) generate_advisory_narrative. (9) write evaluation_status.",
    },
]


# ─────────────────────────────────────────────────────────────
# SKILL.md template renderer
# ─────────────────────────────────────────────────────────────

ADR_TITLES = {
    "ADR-001": "4-tool pipeline with status-field contract",
    "ADR-002": "Validator as separate tool",
    "ADR-003": "Zoning as soft-layer (not hard blocker)",
    "ADR-004": "Legal as external contour (Indologos + PNB)",
    "ADR-005": "Sales Comparison primary, Income/Cost Phase 2",
    "ADR-006": "Scraper parametrized (not 4 separate skills)",
    "ADR-007": "Status fields in properties (not separate table)",
    "ADR-008": "Diagnostic narrative principle",
    "ADR-009": "27-area closed enum gazetteer",
    "ADR-010": "Zone sensitivity matrix scenario-dependent",
    "ADR-011": "Tenure × Zone strictly multiplicative compound",
    "ADR-012": "Condition C1-C5 with renovation premium absorption",
    "ADR-013": "Robust z-score via MAD (not std dev)",
    "ADR-014": "Sample size thresholds (10 / 30)",
    "ADR-015": "OLX dropped from MVP",
    "ADR-016": "pma_overhead_pct = 5% MVP default",
    "ADR-017": "9-value listing_subtype enum including commercial",
    "ADR-018": "Industrial forced uncalibrated",
    "ADR-019": "Calibration type per skill",
    "ADR-020": "Markdown ADR log (not vectorization)",
}


def render_skill_md(skill: dict) -> str:
    adr_lines = []
    for adr_id in skill["adrs"]:
        title = ADR_TITLES.get(adr_id, "")
        adr_lines.append(f"- **{adr_id}** — {title}")
    adr_block = "\n".join(adr_lines) if adr_lines else "- (no skill-specific ADR; falls under general pipeline ADR-001, ADR-007)"

    does = skill["does"].strip()
    description = does[0].upper() + does[1:]
    if not description.endswith("."):
        description = description + "."

    return f"""---
name: {skill["catalog_id"]}
description: "{description}"
catalog_id: {skill["catalog_id"]}
revision: v1
grade: pending
phase: Evaluator
mission: {skill["mission"]}
human_name: {skill["human_name"]}
calibration_type: {skill["calibration_type"]}
applies_to: {skill["applies_to"]}
version_created: {GENERATED_DATE}
last_calibrated: pending
source_doc: sales-comparison-logic.md v1.1 §5 row {skill["source_row"]}
---

# {skill["human_name"]} ({skill["catalog_id"]}.v1)

## Mission

{skill["does"]}.

## Inputs

{skill["inputs"]}.

## Outputs

{skill["outputs"]}.

## Logic (draft)

{skill["logic_hint"]}

*Detailed implementation — filled in Phase B (stack mapping) and Phase D (code). This section is intentionally high-level at v1.*

## Confidence output

{skill["confidence"]}

## Architectural lineage

This skill implements decisions from:

{adr_block}

**Do NOT change core behavior without reading listed ADRs and creating a new superseding ADR.**

## Calibration history

*Empty at v1 creation. Populated during Day 3-5 triangulation / SQL-diff / unit-test batteries.*

| Date | Battery # | Grade | Notes |
|---|---|---|---|
| — | — | pending | not yet calibrated |

## Related

- Source logic: `docs/sales-comparison-logic.md` v1.1 §5 row {skill["source_row"]}
- Pipeline context: `docs/tool-architecture.md` v1.1
- ADR index: `docs/decisions-log.md`
"""


# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def main() -> int:
    SKILLS_DIR.mkdir(exist_ok=True)
    created = []
    for skill in SKILLS:
        skill_dir = SKILLS_DIR / skill["catalog_id"]
        skill_dir.mkdir(exist_ok=True)
        path = skill_dir / "SKILL.md"
        path.write_text(render_skill_md(skill), encoding="utf-8")
        created.append(str(path.relative_to(REPO_ROOT)))
        print(f"  ✓ {skill['catalog_id']:<15} {skill['human_name']:<36} [{skill['calibration_type']}]")
    print(f"\nCreated {len(created)} SKILL.md files under {SKILLS_DIR.relative_to(REPO_ROOT)}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
