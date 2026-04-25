#!/usr/bin/env python3
"""Verify Lamudi area-slugs exist for Pererenan/Kerobokan/Seminyak/Berawa 2-bedroom villa.
One request each with human jitter. Exists = HTTP 200 + listings regex match.
"""
import random, time, re, json
from curl_cffi import requests as rq

SLUGS = [
    # guessing variations since Lamudi uses slug-dashes
    "pererenan", "pererenan-1",
    "kerobokan", "kerobokan-1", "kerobokan-kelod",
    "seminyak", "seminyak-1",
    "berawa",  # likely sub-area under canggu-1
]

BASE = "https://www.lamudi.co.id/jual/bali/badung/{slug}/rumah/vila/2-kamar-tidur/"

results = []
random.shuffle(SLUGS)

for i, slug in enumerate(SLUGS):
    if i > 0:
        time.sleep(random.uniform(15, 40))
    url = BASE.format(slug=slug)
    try:
        r = rq.get(url, impersonate="chrome120", timeout=25,
                   headers={"Referer": "https://www.google.com/", "Accept-Language": "en-US,en;q=0.9,id;q=0.8"})
        body = r.text
        listing_count = len(re.findall(r'/jual/bali/badung/[a-z0-9-]{12,120}-\d{10,14}', body))
        prop_count = len(re.findall(r'/properti/\d+-\d+-[a-f0-9-]{15,}', body))
        title_m = re.search(r'<title[^>]*>([^<]{0,200})</title>', body, re.IGNORECASE)
        title = (title_m.group(1) or "").strip() if title_m else ""
        print(f"[{slug:20s}] status={r.status_code} listings={listing_count} props={prop_count} title={title[:90]}")
        results.append({"slug": slug, "status": r.status_code, "listings": listing_count, "properti": prop_count, "title": title})
    except Exception as e:
        print(f"[{slug:20s}] ERR: {e}")
        results.append({"slug": slug, "error": str(e)})

print("\n=== SLUGS VALID FOR 2BR VILLA ===")
for r in results:
    if r.get("status") == 200 and (r.get("listings",0) > 0 or r.get("properti",0) > 0):
        print(f"  ✅ {r['slug']:20s} listings={r.get('listings')} props={r.get('properti')}")
    elif r.get("status") == 200:
        print(f"  ⚠️  {r['slug']:20s} status=200 no-listings (slug exists but empty)")
    else:
        print(f"  ❌ {r['slug']:20s} {r.get('status') or r.get('error')}")
