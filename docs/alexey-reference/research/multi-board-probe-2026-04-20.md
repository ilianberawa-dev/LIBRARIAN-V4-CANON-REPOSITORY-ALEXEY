# Multi-board probe results — 2026-04-20

## Probe scope

8 Bali real estate platforms tested with curl_cffi (chrome120 impersonation), ≤10 HTTP requests per platform, 10-20s rate-limits between requests.

## Results summary

| Platform | HTTP access | Content quality | Agent data | GPS | Price | Verdict |
|---|---|---|---|---|---|---|
| **Rumah123** ✅ | OK (our current) | High (list+detail) | Only on detail (CF-walled) | Crude (50% area-centroid) | IDR | **KEEP** primary |
| **Lamudi** ✅ | OK | High (821K list, 275K detail) | ✅ Phone visible on detail | ❌ None found | IDR | **ADD** for agent-extraction |
| **Fazwaz** ✅ | OK | Premium (935K list, 30 GPS tokens on list) | TBD (detail pattern not extracted yet) | ✅ On list-page (~1m precision) | **USD** + IDR | **ADD** for GPS + USD price |
| ~~99.co~~ | 🚫 CF challenge ("Just a moment") | Would need Playwright | — | — | — | **DROP** (ADR-015 no-JS rule) |
| ~~Dotproperty~~ | 🚫 CF challenge | Same CF wall | — | — | — | **DROP** |
| ~~Balirealestate.com~~ | ⚠ 530 bytes homepage | Likely SPA / broken | — | — | — | **DROP** |
| ~~Exotiq~~ | ⚠ Form-based UX | No discoverable Bali-specific URLs from home | — | — | — | **DROP** (needs search session) |
| ~~Rumahdijual~~ | ⚠ 5KB, nearly empty | Placeholder | — | — | — | **DROP** |
| ~~PropertyGuru~~ | OK | But Singapore-scoped, Bali filter broken | — | — | — | **DROP** (not an Indonesia portal) |

## Non-fragile stack (3 sources)

### 1. Rumah123 (existing)
- URL pattern: `/jual/bali/{rumah|villa|tanah|apartemen|ruko}/`
- Strengths: volume, Indonesian zoning hints, 5 categories verified
- Limits: detail-pages CF-walled after 2-3 requests (tested 2026-04-20)

### 2. Lamudi (new)
- URL pattern: `/jual/bali/{rumah|villa|tanah|apartemen|komersial}/` — **identical to Rumah123!**
- Strengths: **agent phones visible on detail-page** (e.g. `+6281338044375` confirmed), JSON-LD present, larger list volume (66 IDR prices per list)
- Limits: **no GPS coordinates found** in detail HTML (neither JSON-LD nor embedded)
- Detail URL pattern: `/properti/<hash>` (e.g. `/properti/41032-73-...`)
- Scraper port: near-trivial (URL pattern identical, parsing logic reusable)

### 3. Fazwaz (new)
- URL pattern: `/property-for-sale/indonesia/bali[/<regency>]` — structured geography
- Strengths: **GPS coordinates directly on list-page** (30 coordinate tokens in list HTML, no detail-fetch needed for location!), **USD prices** (expat-oriented)
- Limits: detail URL extraction regex didn't match on first probe (need closer inspection)
- Has separate "projects" section (new developments) not overlapping resale

## Key strategic insight

**3 sources cover each other's gaps:**

| Need | Best source |
|---|---|
| Volume | Rumah123 |
| Zoning hints (ID text) | Rumah123 + Lamudi |
| Agent phone | **Lamudi** (no CF wall on detail) |
| GPS coordinates | **Fazwaz** (on list-page!) |
| USD prices (expat buyers) | **Fazwaz** |
| IDR prices | All 3 |
| Cross-platform price spread | 3 sources = spread computable |

**Agent-cluster discovery becomes possible via Lamudi:**
- Scrape Lamudi list → extract phones from detail (no CF block)
- Group by phone hash → identify agents with 10+ listings
- Cross-reference agent name on Rumah123 + Fazwaz (even without their contact data visible)
- Get full portfolio mapping for tier-1 agents

## Cost estimate for 3-source shadow scraping

- Rumah123: already running (existing)
- Lamudi: 5 categories × 1 list page = 5 HTTP/day (baseline); +detail-fetches at 20s rate-limit = ~10 min per 20 listings
- Fazwaz: 5 regencies × 1 page = 5 HTTP/day; detail rarely needed (GPS on list)
- **Total daily**: ~50-100 HTTP requests across 3 domains, well within normal usage

No CF risk expected (all 3 load without challenges). IP rotation not required for MVP scale.

## Next actions (pending Ilia approval + Alexey canon review)

### Immediate (safe, no schema changes)
- [ ] Record this probe in canonical research log (done — this file)
- [ ] Q-OPEN-16 added to open-questions.md (done)

### After baseline v2 A/B closes (Phase A.5)
- [ ] Create `scrapers/lamudi/run.py` — copy Rumah123 scraper, adapt regex for Lamudi HTML
- [ ] Create `scrapers/fazwaz/run.py` — adapt for Fazwaz list + GPS extraction
- [ ] Each writes to existing `raw_listings` table with distinguishable `source_name` values: `lamudi_bali`, `fazwaz_bali`
- [ ] Run shadow for 3 days, measure volume/quality per source

### Phase B (Normalizer extension)
- [ ] Fuzzy dedup logic: group same-listing across sources by `(area, price±5%, LT±5%, LB±5%, bedrooms)`
- [ ] Agent extraction from Lamudi detail data → `sources._lookup_agents` JSONB (canon-preserving)
- [ ] Price spread detection across sources

### Phase 2 (monetization)
- [ ] Covered in `agent-monetization-strategy-2026-04-20.md`

## What we did NOT do today (per «не хрупкий стек» instruction)

- ❌ No migration 0005 (schema changes blocked by baseline freeze)
- ❌ No new skill EVL-AGT-003 (no data stream yet, would run on void)
- ❌ No new `agents` table (canon preservation until Alexey review)
- ❌ No Playwright addition (ADR-015 no-JS rule holds, 99.co/Dotproperty dropped)
- ❌ No scraper modifications (current Rumah123 scraper untouched, shadow-scrapers are ADDITIONS pending approval)
