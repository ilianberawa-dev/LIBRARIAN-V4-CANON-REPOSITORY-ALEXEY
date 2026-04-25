#!/usr/bin/env python3
"""Probe #2 — real URL patterns from Google. Chrome120 impersonation.
Goal: validate 3 sources return HTTP 200, extract detail-URL pattern, count listings.
NOT scraping — 1 request per source with human jitter.
"""
import random, time, re, json, sys
from curl_cffi import requests as rq

TIMEOUT = 30

SOURCES = [
    {
        "name": "lamudi_canggu_villa",
        "url": "https://www.lamudi.co.id/jual/bali/badung/canggu-1/rumah/vila/",
        "detail_rx": r'href="(/(?:jual|en/for-sale)/[^"]+?/(?:\d+|[a-z0-9-]{10,}))"',
        "count_rx": r'(\d{1,5})\s*(?:properti|properties|hasil|vila|iklan)',
    },
    {
        "name": "99co_canggu_vila",
        "url": "https://www.99.co/id/jual/vila/area-badung/canggu",
        "detail_rx": r'href="(/id/(?:properti|listing)/[^"?#]+)"',
        "count_rx": r'(\d{1,6})\s*(?:Unit Berkualitas|unit|hasil|vila|properti)',
    },
    {
        "name": "99co_canggu_rumah_2br",
        "url": "https://www.99.co/id/jual/rumah/bali/2-kamar-tidur",
        "detail_rx": r'href="(/id/(?:properti|listing)/[^"?#]+)"',
        "count_rx": r'(\d{1,6})\s*(?:Unit|unit|hasil|rumah)',
    },
    {
        "name": "lamudi_bali_townhouse",
        "url": "https://www.lamudi.co.id/en/for-sale/bali/house/townhouse/",
        "detail_rx": r'href="(/(?:jual|en/for-sale)/[^"]+?/(?:\d+|[a-z0-9-]{10,}))"',
        "count_rx": r'(\d{1,5})\s*(?:properti|properties|results|townhouse)',
    },
]

random.shuffle(SOURCES)

def jitter():
    return random.uniform(25, 85)

def probe(src):
    session = rq.Session(impersonate="chrome120")
    try:
        r = session.get(
            src["url"],
            timeout=TIMEOUT,
            headers={
                "Referer": "https://www.google.com/",
                "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
            },
        )
        body = r.text
        head = body[:800].lower()
        blocked = any(m in head for m in ("just a moment", "cloudflare", "cf-chl", "access denied", "captcha", "checking your browser"))
        title_m = re.search(r'<title[^>]*>([^<]{0,200})</title>', body, re.IGNORECASE)
        title = (title_m.group(1) or "").strip() if title_m else ""
        detail_hits = re.findall(src["detail_rx"], body)
        count_hits = re.findall(src["count_rx"], body, re.IGNORECASE)
        samples = list(dict.fromkeys(detail_hits))[:5]
        return {
            "name": src["name"],
            "status": r.status_code,
            "blocked": blocked,
            "html_len": len(body),
            "title": title[:160],
            "detail_hits_total": len(detail_hits),
            "detail_hits_unique": len(set(detail_hits)),
            "sample_hrefs": samples,
            "count_hints": count_hits[:3],
        }
    except Exception as e:
        return {"name": src["name"], "error": f"{type(e).__name__}: {str(e)[:200]}"}
    finally:
        try: session.close()
        except: pass

results = []
for i, src in enumerate(SOURCES):
    if i > 0:
        w = jitter()
        print(f"[rhythm] sleeping {w:.0f}s before {src['name']}...", flush=True)
        time.sleep(w)
    print(f"[probe] {src['name']} → {src['url']}", flush=True)
    r = probe(src)
    results.append(r)
    print(json.dumps(r, ensure_ascii=False, indent=2), flush=True)

print("\n=== SUMMARY ===")
for r in results:
    if "error" in r:
        print(f"  {r['name']:32s} ❌ {r['error']}")
    elif r.get("status") != 200:
        print(f"  {r['name']:32s} ⚠️ status={r['status']} blocked={r.get('blocked')}")
    else:
        c = r.get("count_hints") or ["?"]
        print(f"  {r['name']:32s} ✅ status=200 detail_unique={r['detail_hits_unique']} count_hints={c[0]} html={r['html_len']}B")
