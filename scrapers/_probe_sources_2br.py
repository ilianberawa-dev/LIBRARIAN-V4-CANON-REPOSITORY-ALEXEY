#!/usr/bin/env python3
"""Probe 3 alternative sources for 2BR Berawa/Canggu villa/townhouse listings.
Single request each (not scraping — only structure check).
Canon #9 human-rhythm even for probe: 30-90s random pause between requests, shuffle order.
Output: status_code, title_hint, listings_count_hint, HTML length, first 3 href patterns.
"""
import random, time, re, sys, json, urllib.parse
from curl_cffi import requests as rq

UA_IMPERSONATE = "chrome120"
TIMEOUT = 25

# Candidate URLs: use public search pages for 2BR villa in Canggu/Berawa/Seminyak
SOURCES = [
    {
        "name": "lamudi",
        "url": "https://www.lamudi.co.id/bali/badung/canggu/villa/buy/?bedrooms_min=2&bedrooms_max=2",
        "detail_regex": r'href="(/bali/[^"]+?/buy/[a-z0-9-]+/)"',
    },
    {
        "name": "fazwaz",
        "url": "https://www.fazwaz.com/bali-real-estate-for-sale/canggu?bedroom=2",
        "detail_regex": r'href="(https://www\.fazwaz\.com/[a-z0-9-]+-for-sale-[a-z0-9-]+[0-9]+)"',
    },
    {
        "name": "99co",
        "url": "https://www.99.co/id/cari/rumah-dijual/bali/canggu?minimum_bedroom=2&maximum_bedroom=2",
        "detail_regex": r'href="(/id/properti/[a-z0-9-]+)"',
    },
    {
        "name": "rumah123_compare",
        "url": "https://www.rumah123.com/jual/bali/badung/canggu/villa/?kamar-tidur-minimum=2&kamar-tidur-maksimum=2",
        "detail_regex": r'href="(/properti/[^"]+?/hos[0-9]+/)"',
    },
]

random.shuffle(SOURCES)

def jitter():
    return random.uniform(30, 90)

def probe(src):
    session = rq.Session(impersonate=UA_IMPERSONATE)
    try:
        r = session.get(src["url"], timeout=TIMEOUT, headers={"Referer": "https://www.google.com/"})
        body = r.text
        # CF / block markers
        head = body[:800].lower()
        blocked = any(m in head for m in ("just a moment", "cloudflare", "cf-chl", "access denied", "captcha"))
        title_m = re.search(r'<title>([^<]{0,200})</title>', body, re.IGNORECASE)
        title = (title_m.group(1) or "").strip() if title_m else ""
        matches = re.findall(src["detail_regex"], body)
        return {
            "name": src["name"],
            "url": src["url"],
            "status": r.status_code,
            "blocked": blocked,
            "html_len": len(body),
            "title": title[:140],
            "listings_found": len(matches),
            "sample_hrefs": list(dict.fromkeys(matches))[:3],
        }
    except Exception as e:
        return {
            "name": src["name"],
            "url": src["url"],
            "error": f"{type(e).__name__}: {str(e)[:200]}",
        }
    finally:
        try: session.close()
        except: pass

results = []
for i, src in enumerate(SOURCES):
    if i > 0:
        w = jitter()
        print(f"[human-rhythm] sleeping {w:.0f}s before {src['name']}...", flush=True)
        time.sleep(w)
    print(f"[probe] {src['name']} → {src['url']}", flush=True)
    r = probe(src)
    results.append(r)
    print(json.dumps(r, ensure_ascii=False, indent=2), flush=True)

print("\n=== SUMMARY ===")
for r in results:
    if "error" in r:
        print(f"  {r['name']:12s} ❌ {r['error']}")
    elif r.get("blocked") or r.get("status") != 200:
        print(f"  {r['name']:12s} ⚠️  status={r['status']} blocked={r.get('blocked')}")
    else:
        print(f"  {r['name']:12s} ✅ {r['listings_found']} listings, html={r['html_len']}B")
