#!/usr/bin/env python3
"""Deep scrape of farsight24.com — all public pages.
Outputs a JSON dump with: properties sample, blog posts list, success stories,
reviews, about pages, any PDF/XLS asset URLs. Human-rhythm 20-60s between pages.
"""
import random, time, re, json, sys
from curl_cffi import requests as rq
from urllib.parse import urljoin, urlparse

BASE = "https://farsight24.com"
IMPERSONATE = "chrome120"
TIMEOUT = 30

session = rq.Session(impersonate=IMPERSONATE)

visited = set()
to_visit = [BASE + "/"]
discovered = {
    "pages": [],
    "pdf_xls": [],
    "external_links": set(),
    "internal_links": set(),
    "metrics_found": [],
}

MAX_PAGES = 80

def is_internal(url):
    try:
        return urlparse(url).netloc in ("farsight24.com", "www.farsight24.com", "")
    except:
        return False

def clean_url(url):
    # strip fragment, normalize trailing slash
    p = urlparse(url)
    return f"{p.scheme}://{p.netloc}{p.path}{'?'+p.query if p.query else ''}"

def extract_metrics(html, url):
    """Look for numeric patterns that look like load %, ADR $, revenue $."""
    found = []
    # load/occupancy %
    for m in re.finditer(r'(?:load|occupancy|загр\w*)\s*[:\-]?\s*(\d{2,3})\s*%', html, re.IGNORECASE):
        found.append({"type": "occupancy_pct", "value": m.group(1), "context": html[max(0,m.start()-80):m.end()+80]})
    # USD per night / ADR
    for m in re.finditer(r'\$\s*(\d{2,4})\s*(?:/night|per night|/ночь|в сутки|USD)', html, re.IGNORECASE):
        found.append({"type": "adr_usd", "value": m.group(1), "context": html[max(0,m.start()-80):m.end()+80]})
    # annual revenue / yield
    for m in re.finditer(r'(?:revenue|yield|ROI)\D{0,40}(\$?\d[\d,]*\s*(?:USD|\$|%)?)', html, re.IGNORECASE):
        found.append({"type": "roi_revenue", "value": m.group(1)[:40], "context": html[max(0,m.start()-80):m.end()+80]})
    return found

print(f"[start] deep-scraping {BASE}", flush=True)

while to_visit and len(visited) < MAX_PAGES:
    url = to_visit.pop(0)
    url = clean_url(url)
    if url in visited:
        continue
    visited.add(url)

    if len(visited) > 1:
        pause = random.uniform(15, 45)
        print(f"[{len(visited)}] pause {pause:.0f}s", flush=True)
        time.sleep(pause)

    try:
        r = session.get(url, timeout=TIMEOUT,
                        headers={"Referer": BASE + "/",
                                 "Accept-Language": "en-US,en;q=0.9,ru;q=0.8,id;q=0.7"})
    except Exception as e:
        print(f"[err] {url}: {e}", flush=True)
        continue

    if r.status_code != 200:
        print(f"[{r.status_code}] {url}", flush=True)
        continue

    html = r.text
    title = ""
    tm = re.search(r'<title[^>]*>([^<]{0,300})</title>', html, re.IGNORECASE)
    if tm:
        title = tm.group(1).strip()

    page_metrics = extract_metrics(html, url)
    text_size = len(html)

    page = {
        "url": url,
        "status": r.status_code,
        "title": title[:200],
        "html_size": text_size,
        "metrics": page_metrics,
    }
    discovered["pages"].append(page)
    print(f"[ok {r.status_code}] {url}  title={title[:70]!r}  html={text_size}B  metrics={len(page_metrics)}", flush=True)

    # harvest links
    for m in re.finditer(r'href=["\']([^"\']{2,400})["\']', html):
        raw = m.group(1).strip()
        if raw.startswith(("javascript:", "mailto:", "tel:", "#")):
            continue
        full = urljoin(url, raw)
        if is_internal(full):
            full = clean_url(full)
            discovered["internal_links"].add(full)
            # detect PDF/XLS
            if re.search(r'\.(pdf|xlsx?|csv|docx?)(\?|$)', full, re.IGNORECASE):
                discovered["pdf_xls"].append(full)
            elif full not in visited and full not in to_visit and len(visited) + len(to_visit) < MAX_PAGES:
                to_visit.append(full)
        else:
            discovered["external_links"].add(full)

    # save metrics for report
    for met in page_metrics:
        met["page_url"] = url
        met["page_title"] = title[:100]
        discovered["metrics_found"].append(met)

# serialize
discovered["internal_links"] = sorted(discovered["internal_links"])
discovered["external_links"] = sorted(discovered["external_links"])[:200]
discovered["pdf_xls"] = sorted(set(discovered["pdf_xls"]))

print(f"\n[done] visited={len(visited)} pages, pdf_xls={len(discovered['pdf_xls'])}, metrics={len(discovered['metrics_found'])}")
with open('/tmp/farsight_deep.json', 'w', encoding='utf-8') as f:
    json.dump(discovered, f, ensure_ascii=False, indent=2)
print("written: /tmp/farsight_deep.json")
