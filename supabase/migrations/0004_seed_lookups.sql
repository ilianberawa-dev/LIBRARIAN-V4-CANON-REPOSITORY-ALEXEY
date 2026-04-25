-- ─────────────────────────────────────────────────────────────
-- Realty Portal — Migration 0004
-- Seed sources с lookup-записями (Patch #4 Q1 решение вместо
-- отдельной таблицы area_defaults):
--   _lookup_area_defaults    — 12 priority Bali areas
--   _lookup_bali_gazetteer   — closed enum for specific_area field
--   _lookup_red_flags_vocab  — полный dictionary Q2 Patch #4
--   _lookup_fx_rates         — USD/EUR→IDR rates (hardcoded MVP)
-- Канон Алексея (4 таблицы) не нарушается.
-- ─────────────────────────────────────────────────────────────

-- 1. AREA DEFAULTS (12 priority areas)
INSERT INTO public.sources (name, type, url, config, is_active)
VALUES (
    '_lookup_area_defaults',
    'lookup',
    NULL,
    $JSON$
    {
        "Canggu":    {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.6, "kdb_default":0.50, "social_bucket_default":"expat_enclave",       "subak_risk_level":"low"},
        "Berawa":    {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.6, "kdb_default":0.50, "social_bucket_default":"expat_enclave",       "subak_risk_level":"low"},
        "Pererenan": {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.6, "kdb_default":0.50, "social_bucket_default":"mixed_transitional",  "subak_risk_level":"medium"},
        "Umalas":    {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.6, "kdb_default":0.50, "social_bucket_default":"expat_enclave",       "subak_risk_level":"low"},
        "Kerobokan": {"parent_district":"Badung",  "default_zoning":"yellow","far_default":0.4, "kdb_default":0.40, "social_bucket_default":"mixed_international", "subak_risk_level":"low"},
        "Seminyak":  {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.6, "kdb_default":0.50, "social_bucket_default":"expat_enclave",       "subak_risk_level":"none"},
        "Sanur":     {"parent_district":"Denpasar","default_zoning":"pink",  "far_default":0.5, "kdb_default":0.50, "social_bucket_default":"mixed_international", "subak_risk_level":"low"},
        "Ubud":      {"parent_district":"Gianyar", "default_zoning":"mixed", "far_default":0.5, "kdb_default":0.45, "social_bucket_default":"mixed_international", "subak_risk_level":"high"},
        "Uluwatu":   {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.4, "kdb_default":0.40, "social_bucket_default":"mixed_international", "subak_risk_level":"none"},
        "Jimbaran":  {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.5, "kdb_default":0.45, "social_bucket_default":"mixed_international", "subak_risk_level":"low"},
        "Nusa Dua":  {"parent_district":"Badung",  "default_zoning":"pink",  "far_default":0.5, "kdb_default":0.45, "social_bucket_default":"mixed_international", "subak_risk_level":"none"},
        "Tabanan":   {"parent_district":"Tabanan", "default_zoning":"green", "far_default":0.3, "kdb_default":0.35, "social_bucket_default":"local_dominant",      "subak_risk_level":"high"}
    }
    $JSON$::jsonb,
    TRUE
)
ON CONFLICT (name) DO UPDATE SET config = EXCLUDED.config;

-- 2. BALI GAZETTEER (closed enum for specific_area — Patch #4 Q7)
INSERT INTO public.sources (name, type, url, config, is_active)
VALUES (
    '_lookup_bali_gazetteer',
    'lookup',
    NULL,
    $JSON$
    {
        "areas": [
            "Canggu","Berawa","Pererenan","Umalas","Kerobokan",
            "Seminyak","Legian","Kuta","Sanur","Denpasar",
            "Ubud","Penestanan","Mas",
            "Uluwatu","Jimbaran","Nusa Dua","Pecatu","Bingin","Padang Padang","Ungasan",
            "Tabanan","Cemagi","Seseh","Tanah Lot",
            "Lovina","Amed","Sidemen","Candidasa",
            "other"
        ],
        "aliases": {
            "Ungasan": "Uluwatu",
            "Pecatu": "Uluwatu",
            "Bingin": "Uluwatu",
            "Padang Padang": "Uluwatu",
            "Penestanan": "Ubud",
            "Mas": "Ubud"
        }
    }
    $JSON$::jsonb,
    TRUE
)
ON CONFLICT (name) DO UPDATE SET config = EXCLUDED.config;

-- 3. RED_FLAGS VOCABULARY (Patch #4 Q2 — closed dictionary)
INSERT INTO public.sources (name, type, url, config, is_active)
VALUES (
    '_lookup_red_flags_vocabulary',
    'lookup',
    NULL,
    $JSON$
    {
        "flip_signals": {
            "BU":                   {"severity":"high",  "language":"id",    "meaning":"butuh uang / needs cash"},
            "butuh uang":           {"severity":"high",  "language":"id",    "meaning":"needs cash explicitly"},
            "butuh uang cepat":     {"severity":"high",  "language":"id",    "meaning":"needs cash fast"},
            "dijual cepat":         {"severity":"high",  "language":"id",    "meaning":"sell fast"},
            "dijual murah":         {"severity":"medium","language":"id",    "meaning":"selling cheap"},
            "harga miring":         {"severity":"medium","language":"id",    "meaning":"below-market price"},
            "harga nego":           {"severity":"low",   "language":"id",    "meaning":"negotiable"},
            "nego tipis":           {"severity":"low",   "language":"id",    "meaning":"thin negotiation"},
            "owner pindah negara":  {"severity":"medium","language":"id",    "meaning":"owner relocating abroad"},
            "owner pindah":         {"severity":"medium","language":"id",    "meaning":"owner relocating"},
            "urgent sale":          {"severity":"high",  "language":"en",    "meaning":"urgent"},
            "motivated seller":     {"severity":"medium","language":"en",    "meaning":"motivated"},
            "price reduced":        {"severity":"medium","language":"en",    "meaning":"price reduction"},
            "divorce sale":         {"severity":"high",  "language":"en",    "meaning":"divorce motivation"}
        },
        "tenure_risks": {
            "girik":                    {"severity":"high","language":"id",   "meaning":"un-certificated land pre-BPN"},
            "petok D":                  {"severity":"high","language":"id",   "meaning":"tax receipt only not title"},
            "nominee":                  {"severity":"high","language":"mixed","meaning":"illegal nominee arrangement"},
            "atas nama orang lokal":    {"severity":"high","language":"id",   "meaning":"under local persons name"},
            "atas nama nominee":        {"severity":"high","language":"id",   "meaning":"explicit nominee"},
            "pinjam nama":              {"severity":"high","language":"id",   "meaning":"borrowed name nominee"},
            "sertifikat dalam proses":  {"severity":"high","language":"id",   "meaning":"certificate pending"},
            "sertifikat belum pecah":   {"severity":"high","language":"id",   "meaning":"plot not subdivided"},
            "sertifikat bermasalah":    {"severity":"high","language":"id",   "meaning":"certificate has problems"},
            "tanah sengketa":           {"severity":"high","language":"id",   "meaning":"disputed land"},
            "tanah warisan belum dibagi":{"severity":"high","language":"id",  "meaning":"undivided inheritance"},
            "adat":                     {"severity":"medium","language":"id", "meaning":"customary law claim possible"},
            "lease_under_25_years":     {"severity":"high","language":"en",   "meaning":"below standard liquidity threshold"},
            "lease_duration_unknown":   {"severity":"medium","language":"en", "meaning":"lease marker but years not parseable"},
            "tenure_conflicting_markers":{"severity":"medium","language":"en","meaning":"multiple conflicting tenure signals"}
        },
        "permit_risks": {
            "no PBG":              {"severity":"high",  "language":"mixed","meaning":"missing building permit post-2021"},
            "no SLF":              {"severity":"high",  "language":"mixed","meaning":"missing occupancy certificate"},
            "no IMB":              {"severity":"medium","language":"mixed","meaning":"missing legacy permit pre-2021"},
            "permit pending":      {"severity":"medium","language":"en",   "meaning":"permits in process"},
            "PBG dalam proses":    {"severity":"medium","language":"id",   "meaning":"PBG pending"},
            "tanpa Pondok Wisata": {"severity":"high",  "language":"id",   "meaning":"no STR tourism permit"},
            "izin tidak lengkap":  {"severity":"high",  "language":"id",   "meaning":"incomplete permits"}
        },
        "zoning_foreign_restricted": {
            "subak":             {"severity":"high","language":"id","meaning":"UNESCO-protected rice irrigation"},
            "sawah subak":       {"severity":"high","language":"id","meaning":"subak rice field"},
            "zona hijau":        {"severity":"high","language":"id","meaning":"green zone agricultural"},
            "lahan pertanian":   {"severity":"high","language":"id","meaning":"agricultural land"},
            "lahan konservasi":  {"severity":"high","language":"id","meaning":"conservation land"},
            "jalur hijau":       {"severity":"high","language":"id","meaning":"green corridor"},
            "RTRW kuning tanpa TDUP":{"severity":"medium","language":"mixed","meaning":"yellow zone without tourism permit"}
        },
        "price_risks": {
            "call for price":     {"severity":"medium","language":"en",   "meaning":"price hidden"},
            "harga on request":   {"severity":"medium","language":"mixed","meaning":"price on request"},
            "harga nego tinggi":  {"severity":"low",   "language":"id",   "meaning":"highly negotiable potentially inflated"},
            "termasuk komisi":    {"severity":"medium","language":"id",   "meaning":"includes agent commission"},
            "belum termasuk pajak":{"severity":"low",  "language":"id",   "meaning":"tax not included"},
            "price_unclear":      {"severity":"medium","language":"en",   "meaning":"regex failed to extract price"},
            "price_range_listed": {"severity":"low",   "language":"en",   "meaning":"price range not point value"},
            "bumped_old_listing": {"severity":"low",   "language":"en",   "meaning":"seller refreshed old listing"}
        },
        "direct_owner_signals": {
            "dijual langsung pemilik":{"severity":"low","language":"id","meaning":"direct from owner"},
            "tanpa perantara":        {"severity":"low","language":"id","meaning":"no intermediary"},
            "no broker":              {"severity":"low","language":"en","meaning":"no broker"},
            "FSBO":                   {"severity":"low","language":"en","meaning":"for sale by owner"},
            "owner langsung":         {"severity":"low","language":"id","meaning":"owner direct"}
        },
        "data_quality": {
            "size_unclear":          {"severity":"medium","language":"en","meaning":"regex failed to extract size"},
            "size_in_bata_verify":   {"severity":"low",   "language":"en","meaning":"bata unit varies by banjar"},
            "area_unresolved":       {"severity":"medium","language":"en","meaning":"specific_area not in gazetteer"},
            "no_contact_info":       {"severity":"low",   "language":"en","meaning":"no phone/WA extracted"},
            "contact_obfuscated":    {"severity":"medium","language":"en","meaning":"contact number masked"}
        },
        "quality_positive": {
            "SHM":             {"severity":"positive","language":"id","meaning":"Sertifikat Hak Milik = clean freehold"},
            "siap huni":       {"severity":"positive","language":"id","meaning":"ready to occupy"},
            "fully furnished": {"severity":"positive","language":"en","meaning":"turnkey"},
            "baru direnovasi": {"severity":"positive","language":"id","meaning":"recently renovated"},
            "baru dibangun":   {"severity":"positive","language":"id","meaning":"newly built"},
            "PBG lengkap":     {"severity":"positive","language":"id","meaning":"permits complete"},
            "turnkey":         {"severity":"positive","language":"en","meaning":"turnkey"},
            "designer villa":  {"severity":"positive","language":"en","meaning":"designer-built"}
        }
    }
    $JSON$::jsonb,
    TRUE
)
ON CONFLICT (name) DO UPDATE SET config = EXCLUDED.config;

-- 4. FX RATES (MVP hardcoded, Illya can update via Supabase UI)
INSERT INTO public.sources (name, type, url, config, is_active)
VALUES (
    '_lookup_fx_rates',
    'lookup',
    NULL,
    $JSON$
    {
        "base_currency": "IDR",
        "rates": {
            "USD": 16500,
            "EUR": 17800,
            "SGD": 12100,
            "AUD": 10700
        },
        "last_updated": "2026-04-19",
        "note": "Manual update via Supabase UI; revisit monthly or on >5% BI rate change"
    }
    $JSON$::jsonb,
    TRUE
)
ON CONFLICT (name) DO UPDATE SET config = EXCLUDED.config;
