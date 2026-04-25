# Indonesian Valuation Standards Reference

**Purpose:** narrative disclaimer references SPI/KJPP/MAPPI правильно; Phase 2 Income Approach получает pre-calibrated cap rates; legitimization argument для industrial force-uncalibrated (ADR-018).

**Source:** Indonesian regulatory framework, Colliers Indonesia market data, Knight Frank Indonesia, published KJPP practice.

**Status:** reference data, не код. Читается narrative skill и Phase 2 Income Approach.

---

## 1. Regulatory framework

| Element | Details |
|---|---|
| **Standard** | Standar Penilaian Indonesia (SPI) Edition VI, 2015 |
| **Based on** | International Valuation Standards (IVS) 2013 from IVSC |
| **Regulator** | MAPPI (Masyarakat Profesi Penilai Indonesia) |
| **Code of ethics** | KEPI (Kode Etik Penilai Indonesia) |
| **Licensing body** | Indonesian Ministry of Finance (Kementerian Keuangan) |
| **Licensed appraiser company** | Kantor Jasa Penilai Publik (KJPP) |

### Specialized SPI guidelines

| Guideline | Topic |
|---|---|
| **SPI 306** | Land acquisition / public interest (government expropriation) |
| **SPI 360** | Highest and Best Use (HBU) analysis for land |
| **OJK guidelines** | Capital market property valuation |

---

## 2. Three approaches — Indonesian naming

| Approach | Indonesian term | English | Primary for |
|---|---|---|---|
| Market Approach | **Pendekatan Pasar** | Sales Comparison | residential, commercial with active market |
| Income Approach | **Pendekatan Pendapatan** | Income Approach | office, retail, warehouse, hotel |
| Cost Approach | **Pendekatan Biaya** | Cost Approach | industrial, unique properties, new construction |

**Practice note:** KJPPs используют **weighted combination**, не single method. Stable fully-leased office может взвешивать Income 60-70%.

**Наша позиция в triad:** Sales Comparison primary (MVP Phase A). Income + Cost — Phase 2 super-verifications (ADR-005).

---

## 3. Primary method by commercial subtype

### Office (`kantor`) — EVL-COMP-009 (commercial_office)

| Aspect | Value |
|---|---|
| **Primary method** | Income Approach (Direct Capitalization / DCF) |
| **Formula** | `Value = NOI / Cap Rate` |
| **Bali cap rate range** | 8-10% |
| **Jakarta CBD Grade A cap** | 7-8% |
| **Sales Comparison secondary** | only for Grade A comparables in same sub-locale |
| **Our MVP narrative** | approximation с S_COMMERCIAL_DISCLAIMER, Phase 2 подключает Income |

### Retail shop / ruko (`ruko`) — EVL-COMP-009 (commercial_shop)

| Aspect | Value |
|---|---|
| **Primary method** | Income Approach (multi-tenant) |
| **Formula** | `Value = NOI / Cap Rate` |
| **Cap rate range** | 7-9% |
| **Hybrid nature** | retail frontage + residential upper floors = 2 NOI streams |
| **Frontage premium** | main-road vs courtyard = 2-3× price at identical area |

### Warehouse (`gudang`) — EVL-COMP-009 (commercial_warehouse)

| Aspect | Value |
|---|---|
| **Primary method** | Income Approach (leased); Cost Approach (new builds) |
| **Bali yield range** | 6-8% |
| **Jakarta/Bekasi prime cap** | 8-9% |
| **Market drivers** | e-commerce USD 68B by 2025, occupancy ~90%, port access scarcity |

### Industrial (`pabrik`) — EVL-COMP-009 (commercial_industrial) — **FORCED UNCALIBRATED**

| Aspect | Value |
|---|---|
| **Primary method** | Cost Approach (replacement cost + land value) |
| **Income Approach** | rarely applicable (factory-specific equipment) |
| **Sales Comparison** | **NOT APPLICABLE** — see below |
| **Why Sales NOT applicable** | Each factory unique: equipment 30-60% of value, environmental permits (izin lingkungan), workforce infrastructure, utility connections |
| **SPI requirement** | SPI recommends specialized industrial appraiser |
| **Our system decision** | `evaluation_status = uncalibrated` (forced, regardless of sample). See ADR-018 |
| **Cap rate (if Income attempted)** | 10-14% — unreliable |

### Hotel / hospitality

| Aspect | Value |
|---|---|
| **Primary method** | Income Approach (RevPAR-based) |
| **Formula** | `Value = (RevPAR × 365 × Rooms × occupancy − OpEx) / Cap Rate` |
| **Jakarta 4-5 star cap** | 9-11% |
| **Bali prime cap** | 8-10% |
| **Bali secondary cap** | 11-13% |

### Villa / hotel hybrid — **IL'S CORE USE CASE**

| Aspect | Value |
|---|---|
| **Primary method** | Hybrid: Income (STR revenue) + Sales Comparison (freehold/leasehold villa comps) |
| **Applies to scenario** | `foreign_investor_str_via_pma` (MVP default) |
| **Bali villa STR cap range** | 7-10% |

### Commercial land (`tanah komersial`)

| Aspect | Value |
|---|---|
| **Primary method** | Market Approach + Residual Land Value method |
| **HBU (SPI 360)** | required |
| **Residual formula** | `Max Land Price = Exit Value − Construction − Soft Costs − Holding − Developer Margin (15-25%) − Selling (3-5%)` |
| **Our scenario** | `land_for_development` (MVP 2nd default), Cost Approach in Phase 2 |

---

## 4. Bali commercial yield benchmarks (2026)

| Benchmark | Value |
|---|---|
| International average cap rate | 5% |
| Indonesia official average | 8% |
| **Bali commercial typical range** | **10-16%** |
| Rationale for Bali premium | tourist-economy risk premium + currency risk для foreign investors |
| Denpasar Q1 2024 index YoY | +12.46% |

---

## 5. Major KJPP players with Bali coverage

- **KJPP Billy Anthony Lie & Rekan** — oldest, since 1985, state-owned assets focus
- **Colliers Indonesia** — Monica Koesnovagril (Bali contact)
- **Knight Frank Indonesia** — PT Willson Properti Advisindo
- **TÜV SÜD Indonesia** — industrial specialization
- Multiple local Bali KJPPs in Denpasar

---

## 6. When KJPP appraisal is **legally required** (our system NOT substitute)

- Bank mortgage (banks require KJPP report)
- BPHTB tax assessment (sometimes, for underpriced declarations)
- Court cases (asset division, disputes)
- REIT listing or institutional investment
- Government expropriation (SPI 306)

---

## 7. When our system IS appropriate substitute

- **Private investment decisions** between buyer/seller
- **Pre-purchase due diligence** (screening before committing to full KJPP)
- **Portfolio monitoring** (ongoing value tracking)
- **Investor screening tool** — NOT final valuation

---

## 8. Narrative disclaimer standard references

Narrative skill (EVL-NAR-015) использует эти формулировки в условных секциях.

### Для commercial general (S_COMMERCIAL_DISCLAIMER standard variant)

> Наша оценка применяет Market Approach (SPI terminology: Pendekatan Pasar), который для коммерческой недвижимости согласно SPI является **secondary** для income-producing properties. Для банковской ипотеки, судебных дел или institutional investment требуется KJPP appraisal с weighted application трёх методов (Market + Income + Cost).

### Для industrial (S_COMMERCIAL_DISCLAIMER industrial sub-variant)

> Для промышленной недвижимости (pabrik) SPI требует specialized industrial appraiser. Каждая фабрика уникальна — equipment permanently installed (30-60% общей стоимости), environmental permits (izin lingkungan), workforce infrastructure. Наш Sales Comparison method не применим в принципе. `evaluation_status = uncalibrated`. Рекомендуем обращение в KJPP с industrial specialization (например, TÜV SÜD Indonesia).

### Для office / warehouse / retail (S_COMMERCIAL_DISCLAIMER office variant)

> Наш Sales Comparison — approximation среднего уровня точности для pre-purchase screening. Для финального investment decision требуется Income Approach (NOI / Cap Rate). Phase 2 подключает Income Approach с cap rates per segment из Colliers / Knight Frank reports.

---

## 9. Phase 2 Income Approach cap rate constants

Для записи в `sources._lookup_evaluation_constants.cap_rates_by_segment` (Phase 2).

```json
{
  "bali_cap_rates_by_segment_2026": {
    "office":            {"low": 0.08, "mid": 0.09,  "high": 0.10},
    "retail_ruko":       {"low": 0.09, "mid": 0.10,  "high": 0.11},
    "warehouse":         {"low": 0.07, "mid": 0.08,  "high": 0.09},
    "hotel_hospitality": {"low": 0.09, "mid": 0.11,  "high": 0.13},
    "villa_str":         {"low": 0.07, "mid": 0.085, "high": 0.10},
    "industrial":        {"low": 0.10, "mid": 0.12,  "high": 0.14,
                          "warning": "unreliable — use KJPP specialist"}
  }
}
```

Revision trigger: Phase 2 start + latest Colliers / Knight Frank report (Q-OPEN-11).

---

## 10. Cross-references

| Related docs |
|---|
| `decisions-log.md` ADR-005 (Sales Comparison primary) |
| `decisions-log.md` ADR-018 (industrial forced uncalibrated) |
| `sales-comparison-logic.md` §1 (IVSC triad position) |
| `sales-comparison-logic.md` §12.1 (narrative disclaimers) |
| `open-questions.md` Q-OPEN-11 (cap rates calibration trigger) |
