#!/usr/bin/env python3
"""Normalize pending raw_listings into canonical public.properties via Haiku (LiteLLM).

Canonical contract — см. architecture.md + skills/normalize_listing/SKILL.md.

Flow:
  1) SELECT raw_listings WHERE status='pending' LIMIT N
  2) Haiku extracts canonical JSON per listing (strict schema, LiteLLM json_object mode)
  3) UPSERT properties ON CONFLICT (source_url) DO UPDATE
     - last_seen_at = NOW()
     - price_changed_at = NOW() only if price_idr differs
     - fields COALESCE'd so re-normalization keeps prior non-null data
  4) UPDATE raw_listings SET status='processed', property_id=…, parsed_at=NOW()

Usage:
  python3 normalize_listings.py --limit 5 --dry-run   # no DB writes, prints Haiku JSON
  python3 normalize_listings.py --limit 5             # real writes
  python3 normalize_listings.py --all                 # process everything pending
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from typing import Any, Optional

import psycopg
from psycopg.types.json import Json

DB_DSN = os.environ["REALTY_DB_DSN"]
LITELLM_URL = os.environ.get("LITELLM_URL", "http://172.18.0.6:4000/v1/chat/completions")
LITELLM_KEY = os.environ["LITELLM_MASTER_KEY"]
MODEL = os.environ.get("NORMALIZER_MODEL", "claude-haiku")

IDR_PER_USD = int(os.environ.get("IDR_PER_USD", "16000"))

LISTING_TYPE_ENUM = {"land", "villa", "rumah", "apartment", "ruko", "unknown"}
TENURE_ENUM = {"freehold", "leasehold", "hak_pakai", "hgb", "unknown"}
RENTAL_PERIOD_VALUES = {"yearly", "monthly", "freehold", "leasehold"}
SELLER_TYPE_VALUES = {"owner", "agent", "developer", "unknown"}
RENTAL_SUITABILITY_VALUES = {"short_term", "long_term", "mixed", "unknown"}

SYSTEM_PROMPT = """Ты извлекаешь canonical поля из карточки объявления о недвижимости Бали (источник: Rumah123).
Верни СТРОГО JSON по схеме ниже. Поля которых нет в объявлении — null (НЕ придумывай).

Схема:
{
  "listing_type":   "one of: land | villa | rumah | apartment | ruko | unknown",
  "district":       "область Бали (Badung, Gianyar, Tabanan, Denpasar, Buleleng, Klungkung, Karangasem, Jembrana) или null",
  "specific_area":  "район/подрайон (Canggu, Seminyak, Ubud, Sanur, Jimbaran, Nusa Dua, Kuta, Uluwatu, Pererenan, Berawa, Ungasan, Kerobokan, etc.) или null",
  "address":        "улица/комплекс/ориентир, null если не указано",
  "bedrooms":       "int or null (камар тидур / kamar tidur / bedrooms)",
  "bathrooms":      "int or null (камар манди / kamar mandi / bathrooms)",
  "area_m2":        "int building area (LB / luas bangunan / building / bangunan) or null",
  "land_area_m2":   "int land area (LT / luas tanah / land / tanah) or null",
  "price_idr":      "int total price in rupiah (convert: Juta=1e6, Miliar/Milyar/M=1e9) or null",
  "price_original": "raw price string as shown (e.g. 'Rp 2,5 Miliar')",
  "is_price_range": "bool — true если объявление задаёт диапазон (Rp X - Rp Y)",
  "is_negotiable":  "bool — true если есть 'nego', 'nego tipis', 'bisa nego', 'negotiable'",
  "rental_period":  "one of: yearly | monthly | freehold | leasehold | null. На rumah123 /jual/* = sale (freehold/leasehold обычно), /sewa/* = rental",
  "lease_years":    "int years if leasehold with explicit duration, else null",
  "tenure_type":    "one of: freehold | leasehold | hak_pakai | hgb | unknown. SHM=freehold, HGB=hgb, Hak Pakai=hak_pakai, Leasehold/Sewa Tahunan=leasehold",
  "contact_name":   "personal name of seller/agent, null",
  "contact_phone":  "phone number digits only (+62... preserved), null",
  "contact_whatsapp": "whatsapp number (often = phone), null",
  "image_urls":     "array of https URLs found in raw_html (<img src=...>), can be empty array",
  "seller_type":    "one of: owner | agent | developer | unknown. Heuristics: 'Marketing by X'/'Listed by X'/'Dipasarkan oleh X'/agency template = agent; 'dijual oleh pemilik'/'no broker'/personal phrasing = owner; 'developer'/'perumahan baru'/'cluster perumahan'/'KPR' = developer",
  "agent_name":     "REAL ESTATE AGENCY brand name ONLY. Not complex/residence/apartment name. Valid examples: 'Ray White', 'Exotiq', 'Harcourts', 'Paradise Property', 'Bali Luxury Estate', 'Century 21'. INVALID examples (do NOT extract as agent_name): 'The Komu' (complex), 'Cozy Stay' (brand), 'Green Village' (residence), 'Starlink Residence' (project). If unclear — null. Only extract when there's explicit phrase like 'Dipasarkan oleh X Property Agent' or 'Listed by X Real Estate'.",
  "rental_suitability": "one of: short_term | long_term | mixed | unknown. SHORT_TERM (туристическая вилла для Airbnb/Booking-сдачи): есть pool/kolam renang, fully furnished, ключевые слова ROI/rental income/investment/airbnb/booking, listing_type=villa в туристической зоне (Canggu/Seminyak/Ubud/Berawa/Uluwatu/Kuta/Sanur), часто leasehold, premium/luxury отделка. LONG_TERM (жилая/долгосрочная сдача): listing_type=rumah с freehold, большой land_area (>200м²), ключевые слова perumahan/keluarga/family/cluster perumahan/KPR/subsidi, БЕЗ pool, inland locations (Denpasar/Mengwi/inner Canggu). MIXED: смешанные сигналы (villa без pool, или rumah в туристической зоне с pool). UNKNOWN: недостаточно информации для решения. Решай строго — не оставляй unknown если есть явный сигнал."
}

ВАЖНО:
- price_idr — числом без пробелов/точек. '2,5 Miliar' → 2500000000. '358 Juta' → 358000000.
- Даже если заголовок обещает, проверяй в тексте: может быть диапазон или KPR (ежемесячный платёж, не цена).
- image_urls — ТОЛЬКО из raw_html (src=...). Если raw_html пустой или без <img> — верни [].
- Никакого markdown, никаких комментариев вне JSON. Только валидный JSON-объект."""


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def _extract_detail_signals(detail_html: str) -> str:
    """Pull compact signals from 480KB detail HTML: images, phones, WA, sertifikat, agent mentions.

    Returns a shortlist string that fits Haiku context cheaply.
    """
    if not detail_html:
        return ""
    parts = []

    # og:image (title photo)
    og_imgs = re.findall(r'property="og:image"[^>]+content="(https?://[^"]+)"', detail_html)
    if og_imgs:
        parts.append("og:image: " + og_imgs[0][:300])

    # all <img src=...> urls (max 30)
    imgs = re.findall(r'<img[^>]+src="(https?://picture\.rumah123\.com/[^"]+)"', detail_html)
    if imgs:
        uniq = list(dict.fromkeys(imgs))[:30]
        parts.append("images (" + str(len(uniq)) + "): " + " | ".join(u[:200] for u in uniq[:10]))

    # phones in context (40 chars around match)
    for m in re.finditer(r"(\+62[\d\s\-]{8,}|0\d{9,12})", detail_html):
        s = max(0, m.start() - 40); e = min(len(detail_html), m.end() + 40)
        ctx = re.sub(r"\s+", " ", detail_html[s:e])
        parts.append("phone_ctx: " + ctx[:200])
        if len(parts) > 20:
            break

    # WhatsApp
    wa = re.findall(r'(wa\.me/\S+|api\.whatsapp\.com/\S+)', detail_html, re.I)
    if wa:
        parts.append("wa_links: " + " | ".join(wa[:5]))

    # Sertifikat/tenure context (first 3 matches)
    for m in list(re.finditer(r"(SHM|HGB|Hak Pakai|Sertifikat\s+Hak\s+Milik|Freehold|Leasehold|Hak\s+Guna\s+Bangunan)", detail_html, re.I))[:3]:
        s = max(0, m.start() - 80); e = min(len(detail_html), m.end() + 80)
        ctx = re.sub(r"\s+", " ", detail_html[s:e])
        parts.append("tenure_ctx: " + ctx[:300])

    # Agent/developer markers
    for m in list(re.finditer(r"(Dipasarkan\s*oleh|Marketing\s*by|Listed\s*by|Property\s*Agent|Agen\s*Property|Developed\s*by)[^<\n]{0,100}", detail_html, re.I))[:5]:
        parts.append("agent_ctx: " + re.sub(r"\s+", " ", m.group())[:200])

    # description near h1 (property title/description)
    desc = re.search(r'<h1[^>]*>([^<]{5,200})</h1>', detail_html)
    if desc:
        parts.append("h1: " + desc.group(1).strip()[:200])
    # description block — try meta description
    md = re.search(r'<meta\s+name="description"\s+content="([^"]{30,500})"', detail_html)
    if md:
        parts.append("meta_desc: " + md.group(1)[:500])

    return "\n".join(parts)


def _log_usage(model: str, usage: dict, latency_ms: int, success: bool, error_text: str = "") -> None:
    """Append one row to public.llm_usage_log; swallow any DB errors."""
    try:
        with psycopg.connect(DB_DSN, connect_timeout=5) as c:
            with c.cursor() as cur:
                # rough cost: Haiku 4.5 ~ $1/Mtok input, $5/Mtok output (approx, conservative)
                it = int(usage.get("prompt_tokens") or 0)
                ot = int(usage.get("completion_tokens") or 0)
                ct = int((usage.get("prompt_tokens_details") or {}).get("cached_tokens") or 0)
                cost = (it * 1.0 + ot * 5.0) / 1_000_000.0 if model.startswith("claude") else (it * 0.15 + ot * 0.6) / 1_000_000.0
                cur.execute(
                    "INSERT INTO public.llm_usage_log (model, source_script, source_task, input_tokens, output_tokens, cached_tokens, total_tokens, cost_usd, latency_ms, success, error_text) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                    (model, "normalize_listings.py", "canonical_extract", it, ot, ct, it + ot, round(cost, 6), latency_ms, success, error_text[:500]),
                )
    except Exception:
        pass


def call_haiku(raw_text: str, raw_html: str, detail_html: str = "", timeout: int = 40) -> dict[str, Any]:
    """One Haiku call via LiteLLM. Returns parsed dict or raises."""
    user_content = (
        f"raw_text:\n{raw_text[:2500]}\n\n---\nraw_html (card, truncated):\n{raw_html[:3000]}"
    )
    if detail_html:
        signals = _extract_detail_signals(detail_html)
        if signals:
            user_content += "\n\n---\ndetail_page_signals:\n" + signals
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.0,
        "max_tokens": 900,
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        LITELLM_URL,
        data=body,
        headers={
            "Authorization": f"Bearer {LITELLM_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            resp = json.loads(r.read())
        latency_ms = int((time.time() - t0) * 1000)
        _log_usage(MODEL, resp.get("usage") or {}, latency_ms, success=True)
    except Exception as e:
        latency_ms = int((time.time() - t0) * 1000)
        _log_usage(MODEL, {}, latency_ms, success=False, error_text=f"{type(e).__name__}: {str(e)[:300]}")
        raise
    content = resp["choices"][0]["message"]["content"]
    return json.loads(_strip_fences(content))


def _strip_fences(content: str) -> str:
    """Haiku often wraps JSON in ```json ... ``` even with json_object response_format."""
    s = content.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*", "", s)
        s = re.sub(r"\s*```\s*$", "", s)
    # fallback: extract first {...} block
    if not s.startswith("{"):
        m = re.search(r"\{.*\}", s, re.DOTALL)
        if m:
            s = m.group(0)
    return s


def normalize_enum(value: Any, allowed: set[str], default: Optional[str] = None) -> Optional[str]:
    if value is None:
        return default
    if isinstance(value, str):
        v = value.strip().lower().replace(" ", "_").replace("-", "_")
        if v in allowed:
            return v
        # common variants
        if v in ("house",):
            return "rumah"
        if v in ("shop", "shophouse"):
            return "ruko"
        if v in ("tanah",):
            return "land"
    return default


def coerce_int(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        digits = re.sub(r"[^\d]", "", value)
        return int(digits) if digits else None
    return None


def coerce_bool(value: Any) -> Optional[bool]:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        v = value.strip().lower()
        if v in ("true", "yes", "1", "y"):
            return True
        if v in ("false", "no", "0", "n"):
            return False
    return None


def coerce_image_urls(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    out = []
    for u in value:
        if isinstance(u, str) and u.startswith(("http://", "https://")):
            out.append(u[:500])
    return out[:50]


def canonicalize(extracted: dict[str, Any]) -> dict[str, Any]:
    """Clean + enum-check Haiku output. Silently drops invalid enum values."""
    listing_type = normalize_enum(extracted.get("listing_type"), LISTING_TYPE_ENUM, "unknown")
    tenure_type = normalize_enum(extracted.get("tenure_type"), TENURE_ENUM, "unknown")

    rental_period = extracted.get("rental_period")
    if isinstance(rental_period, str):
        rp = rental_period.strip().lower()
        rental_period = rp if rp in RENTAL_PERIOD_VALUES else None
    else:
        rental_period = None

    seller_type = extracted.get("seller_type")
    if isinstance(seller_type, str):
        st = seller_type.strip().lower()
        seller_type = st if st in SELLER_TYPE_VALUES else "unknown"
    else:
        seller_type = "unknown"

    rental_suitability = extracted.get("rental_suitability")
    if isinstance(rental_suitability, str):
        rs = rental_suitability.strip().lower()
        rental_suitability = rs if rs in RENTAL_SUITABILITY_VALUES else "unknown"
    else:
        rental_suitability = "unknown"

    price_idr = coerce_int(extracted.get("price_idr"))
    price_usd = round(price_idr / IDR_PER_USD, 2) if price_idr else None

    return {
        "listing_type": listing_type,
        "type": listing_type,  # legacy field mirror
        "district": (extracted.get("district") or None),
        "specific_area": (extracted.get("specific_area") or None),
        "address": (extracted.get("address") or None),
        "bedrooms": coerce_int(extracted.get("bedrooms")),
        "bathrooms": coerce_int(extracted.get("bathrooms")),
        "area_m2": coerce_int(extracted.get("area_m2")),
        "land_area_m2": coerce_int(extracted.get("land_area_m2")),
        "land_size_m2": coerce_int(extracted.get("land_area_m2")),
        "building_size_m2": coerce_int(extracted.get("area_m2")),
        "price_idr": price_idr,
        "price_usd": price_usd,
        "price_original": (extracted.get("price_original") or None),
        "price_raw_string": (extracted.get("price_original") or None),
        "is_price_range": coerce_bool(extracted.get("is_price_range")) or False,
        "is_negotiable": coerce_bool(extracted.get("is_negotiable")) or False,
        "rental_period": rental_period,
        "lease_years": coerce_int(extracted.get("lease_years")),
        "tenure_type": tenure_type,
        "contact_name": (extracted.get("contact_name") or None),
        "contact_phone": (extracted.get("contact_phone") or None),
        "contact_whatsapp": (extracted.get("contact_whatsapp") or None),
        "image_urls": coerce_image_urls(extracted.get("image_urls")),
        "seller_type": seller_type,
        "agent_name": (extracted.get("agent_name") or None),
        "rental_suitability": rental_suitability,
    }


UPSERT_SQL = """
INSERT INTO public.properties (
    source_url, source_name, raw_text,
    type, listing_type, district, specific_area, address,
    bedrooms, bathrooms,
    area_m2, land_area_m2, land_size_m2, building_size_m2,
    price_idr, price_usd, price_original, price_raw_string,
    is_price_range, is_negotiable,
    rental_period, lease_years, tenure_type,
    contact_name, contact_phone, contact_whatsapp,
    image_urls, agent_name, seller_type, rental_suitability,
    is_active, first_seen_at, last_seen_at,
    normalization_status, normalization_attempted_at, normalization_llm_used
)
VALUES (
    %(source_url)s, %(source_name)s, %(raw_text)s,
    %(type)s, %(listing_type)s, %(district)s, %(specific_area)s, %(address)s,
    %(bedrooms)s, %(bathrooms)s,
    %(area_m2)s, %(land_area_m2)s, %(land_size_m2)s, %(building_size_m2)s,
    %(price_idr)s, %(price_usd)s, %(price_original)s, %(price_raw_string)s,
    %(is_price_range)s, %(is_negotiable)s,
    %(rental_period)s, %(lease_years)s, %(tenure_type)s,
    %(contact_name)s, %(contact_phone)s, %(contact_whatsapp)s,
    %(image_urls)s, %(agent_name)s, %(seller_type)s, %(rental_suitability)s,
    true, now(), now(),
    'complete', now(), %(llm_used)s
)
ON CONFLICT (source_url) DO UPDATE SET
    last_seen_at = now(),
    price_changed_at = CASE
        WHEN public.properties.price_idr IS DISTINCT FROM EXCLUDED.price_idr
        THEN now() ELSE public.properties.price_changed_at END,
    price_idr     = EXCLUDED.price_idr,
    price_usd     = EXCLUDED.price_usd,
    is_active     = true,
    type          = COALESCE(EXCLUDED.type, public.properties.type),
    listing_type  = COALESCE(EXCLUDED.listing_type, public.properties.listing_type),
    district      = COALESCE(EXCLUDED.district, public.properties.district),
    specific_area = COALESCE(EXCLUDED.specific_area, public.properties.specific_area),
    address       = COALESCE(EXCLUDED.address, public.properties.address),
    bedrooms      = COALESCE(EXCLUDED.bedrooms, public.properties.bedrooms),
    bathrooms     = COALESCE(EXCLUDED.bathrooms, public.properties.bathrooms),
    area_m2       = COALESCE(EXCLUDED.area_m2, public.properties.area_m2),
    land_area_m2  = COALESCE(EXCLUDED.land_area_m2, public.properties.land_area_m2),
    land_size_m2  = COALESCE(EXCLUDED.land_size_m2, public.properties.land_size_m2),
    building_size_m2 = COALESCE(EXCLUDED.building_size_m2, public.properties.building_size_m2),
    rental_period = COALESCE(EXCLUDED.rental_period, public.properties.rental_period),
    lease_years   = COALESCE(EXCLUDED.lease_years, public.properties.lease_years),
    tenure_type   = EXCLUDED.tenure_type,
    contact_name  = COALESCE(EXCLUDED.contact_name, public.properties.contact_name),
    contact_phone = COALESCE(EXCLUDED.contact_phone, public.properties.contact_phone),
    contact_whatsapp = COALESCE(EXCLUDED.contact_whatsapp, public.properties.contact_whatsapp),
    image_urls    = CASE
        WHEN array_length(EXCLUDED.image_urls, 1) IS NOT NULL
        THEN EXCLUDED.image_urls
        ELSE public.properties.image_urls END,
    agent_name    = COALESCE(EXCLUDED.agent_name, public.properties.agent_name),
    seller_type   = CASE
        WHEN EXCLUDED.seller_type IS NOT NULL AND EXCLUDED.seller_type <> 'unknown'
        THEN EXCLUDED.seller_type
        ELSE COALESCE(public.properties.seller_type, EXCLUDED.seller_type) END,
    rental_suitability = CASE
        WHEN EXCLUDED.rental_suitability IS NOT NULL AND EXCLUDED.rental_suitability <> 'unknown'
        THEN EXCLUDED.rental_suitability
        ELSE COALESCE(public.properties.rental_suitability, EXCLUDED.rental_suitability) END,
    normalization_status = 'complete',
    normalization_attempted_at = now(),
    normalization_llm_used = %(llm_used)s
RETURNING id
"""


FAIL_RAW_SQL = """
UPDATE public.raw_listings
SET status='failed', error_message=%s, parsed_at=now()
WHERE id=%s
"""

MARK_DONE_SQL = """
UPDATE public.raw_listings
SET status='processed', property_id=%s, parsed_at=now()
WHERE id=%s
"""


def fetch_pending(conn, limit: int, refresh: bool = False) -> list[dict]:
    with conn.cursor() as cur:
        if refresh:
            # re-normalize rows that now have detail_html available
            cur.execute(
                "SELECT id, source_url, source_name, raw_text, raw_html, raw_detail_html "
                "FROM public.raw_listings "
                "WHERE detail_status='ok' AND raw_detail_html IS NOT NULL "
                "ORDER BY detail_fetched_at DESC LIMIT %s",
                (limit,),
            )
        else:
            cur.execute(
                "SELECT id, source_url, source_name, raw_text, raw_html, raw_detail_html "
                "FROM public.raw_listings WHERE status='pending' "
                "ORDER BY created_at ASC LIMIT %s",
                (limit,),
            )
        rows = cur.fetchall()
        cols = [d.name for d in cur.description]
        return [dict(zip(cols, r)) for r in rows]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=5)
    p.add_argument("--all", action="store_true")
    p.add_argument("--dry-run", action="store_true", help="no DB writes, print Haiku output")
    p.add_argument("--rate-limit", type=float, default=0.5)
    p.add_argument("--refresh", action="store_true",
                   help="Re-normalize rows with detail_html available (for filling contact_*/images/tenure after detail fetch)")
    args = p.parse_args()

    limit = 10_000 if args.all else args.limit

    t0 = time.time()
    with psycopg.connect(DB_DSN, connect_timeout=10) as conn:
        rows = fetch_pending(conn, limit, refresh=args.refresh)
    log(f"fetched {len(rows)} pending raw_listings")

    fill_counters: dict[str, int] = {}
    processed = 0
    failed = 0
    dry_preview = []

    for i, row in enumerate(rows, 1):
        try:
            extracted = call_haiku(
                row["raw_text"],
                row["raw_html"] or "",
                detail_html=row.get("raw_detail_html") or "",
            )
            canon = canonicalize(extracted)
        except Exception as e:
            failed += 1
            msg = f"haiku/parse error: {type(e).__name__}: {str(e)[:200]}"
            log(f"[{i}/{len(rows)}] FAIL {row['source_url']}: {msg}")
            if not args.dry_run:
                with psycopg.connect(DB_DSN, connect_timeout=10) as conn:
                    with conn.cursor() as cur:
                        cur.execute(FAIL_RAW_SQL, (msg[:500], row["id"]))
            continue

        # fill rate counter
        for k, v in canon.items():
            if v not in (None, "", "unknown", [], False, 0):
                fill_counters[k] = fill_counters.get(k, 0) + 1

        log(f"[{i}/{len(rows)}] OK type={canon['listing_type']} district={canon['district']} "
            f"area={canon['specific_area']} price_idr={canon['price_idr']} "
            f"br={canon['bedrooms']} land={canon['land_area_m2']} "
            f"tenure={canon['tenure_type']} seller={canon['seller_type']} "
            f"phone={bool(canon['contact_phone'])} imgs={len(canon['image_urls'])}")

        if args.dry_run:
            dry_preview.append({
                "source_url": row["source_url"],
                "canon": canon,
            })
            processed += 1
            time.sleep(args.rate_limit)
            continue

        # real UPSERT
        params = {
            "source_url": row["source_url"],
            "source_name": row["source_name"],
            "raw_text": row["raw_text"][:10000],
            "llm_used": MODEL,
            **canon,
        }
        try:
            with psycopg.connect(DB_DSN, connect_timeout=10) as conn:
                with conn.cursor() as cur:
                    cur.execute(UPSERT_SQL, params)
                    prop_id = cur.fetchone()[0]
                    cur.execute(MARK_DONE_SQL, (prop_id, row["id"]))
            processed += 1
        except Exception as e:
            failed += 1
            msg = f"upsert error: {type(e).__name__}: {str(e)[:300]}"
            log(f"[{i}/{len(rows)}] UPSERT FAIL: {msg}")
            with psycopg.connect(DB_DSN, connect_timeout=10) as conn:
                with conn.cursor() as cur:
                    cur.execute(FAIL_RAW_SQL, (msg[:500], row["id"]))

        time.sleep(args.rate_limit)

    dt = time.time() - t0
    log("")
    log("=" * 60)
    log(f"DONE: processed={processed} failed={failed} in {dt:.1f}s")
    log("fill rate (non-null / total):")
    n = len(rows) or 1
    tracked = [
        "district", "specific_area", "bedrooms", "bathrooms",
        "area_m2", "land_area_m2", "price_idr",
        "rental_period", "lease_years", "tenure_type",
        "contact_name", "contact_phone", "contact_whatsapp",
        "image_urls", "seller_type", "agent_name",
    ]
    for k in tracked:
        c = fill_counters.get(k, 0)
        pct = 100 * c / n
        log(f"  {k:20s} {c:>3}/{n}  ({pct:>4.0f}%)")

    if args.dry_run:
        print(json.dumps(dry_preview, ensure_ascii=False, indent=2))

    return 0 if failed == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
