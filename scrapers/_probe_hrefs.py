#!/usr/bin/env python3
from curl_cffi import requests as rq
import re, time, random

SOURCES = [
  ('99co_villa_canggu',      'https://www.99.co/id/jual/vila/area-badung/canggu'),
  ('lamudi_villa_canggu',    'https://www.lamudi.co.id/jual/bali/badung/canggu-1/rumah/vila/'),
]

for i, (name, url) in enumerate(SOURCES):
    if i > 0:
        time.sleep(random.uniform(20, 50))
    r = rq.get(url, impersonate='chrome120', timeout=30,
               headers={'Referer': 'https://www.google.com/',
                        'Accept-Language': 'en-US,en;q=0.9,id;q=0.8'})
    body = r.text
    # any href to relative path
    hrefs = re.findall(r'href=["\'](/[^"\'<> ]{10,200})["\']', body)
    unique = list(dict.fromkeys(hrefs))
    candidates = [h for h in unique if any(k in h for k in
                  ('properti', 'listing', '/jual/', '/for-sale/', 'vila', 'villa', 'rumah', 'detail', 'house'))]
    print(f"=== {name} (status={r.status_code}, html={len(body)}B) ===")
    print(f"all unique relative hrefs: {len(unique)}")
    print(f"listing-like candidates:   {len(candidates)}")
    print("top-15 candidates:")
    for h in candidates[:15]:
        print(f"  {h}")
    # looking for numeric-id patterns
    id_patterns = re.findall(r'href=["\'](/[^"\'<> ]*/(?:\d{5,}|[a-z0-9-]{15,})/?)["\']', body)
    id_unique = list(dict.fromkeys(id_patterns))
    print(f"\nnumeric-id hrefs: {len(id_unique)}")
    for h in id_unique[:10]:
        print(f"  {h}")
    print()
