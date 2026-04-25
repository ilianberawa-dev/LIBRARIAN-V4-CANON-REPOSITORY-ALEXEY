#!/usr/bin/env python3
"""Lamudi.co.id Bali scraper — 2-bedroom villa list pages.

Собирает detail-URLs (2 pattern-а: /jual/.../slug-timestamp/ и /properti/hash) из:
  https://www.lamudi.co.id/jual/bali/badung/{slug}/rumah/vila/2-kamar-tidur/

Пишет в public.raw_listings с source_name='lamudi_bali' и status='pending'.
Нормализация происходит позже через scripts/normalize_listings.py --refresh после fetch_details.

Canon: fail-loud (REALTY_DB_DSN из .env, без fallback), одна задача (scrape list → raw insert).
Human-rhythm внутри: random pause между страницами.
"""
from __future__ import annotations

import argparse
import os
import random
import re
import sys
import time
from typing import Optional

import psycopg
from curl_cffi import requests as rq

BASE = "https://www.lamudi.co.id"
WARM_URL = BASE + "/"
IMPERSONATE = "chrome120"
BLOCK_MARKERS = ("just a moment", "cloudflare", "cf-chl", "access denied", "captcha")

# Validated slugs from probe 2026-04-21 (all under /jual/bali/badung/<slug>/rumah/vila/2-kamar-tidur/)
DEFAULT_SLUGS = ["canggu-1", "pererenan", "seminyak", "kerobokan", "kerobokan-kelod"]

PATH_TPL = "/jual/bali/badung/{slug}/rumah/vila/2-kamar-tidur/"

# Two detail-URL forms seen on Lamudi list pages:
#   A) /jual/bali/badung/<slug-with-dashes>-<10-14-digit-id>/
#   B) /properti/<hash-like 41032-73-xxxx-xxxx>
RE_DETAIL_A = re.compile(r'href=["\'](/jual/bali/badung/[a-z0-9-]{10,180}-\d{10,14}/?)["\']')
RE_DETAIL_B = re.compile(r'href=["\'](/properti/\d+-\d+-[a-f0-9-]{15,})["\']')

DB_DSN = os.environ["REALTY_DB_DSN"]  # fail-loud


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def is_blocked(resp) -> bool:
    if resp.status_code in (403, 429, 503):
        return True
    if resp.status_code != 200:
        return False
    head = resp.text[:800].lower()
    return any(m in head for m in BLOCK_MARKERS)


def fetch(session, url: str, referer: Optional[str], timeout: int = 30):
    headers = {
        "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
    }
    if referer:
        headers["Referer"] = referer
    return session.get(url, headers=headers, timeout=timeout)


def parse_list_page(html: str, base: str) -> list[dict]:
    """Extract detail-URLs + minimal raw text snippets surrounding each href."""
    out = []
    seen = set()

    for rx, kind in [(RE_DETAIL_A, "slug"), (RE_DETAIL_B, "properti")]:
        for m in rx.finditer(html):
            href = m.group(1)
            url = href if href.startswith("http") else base + href
            if url in seen:
                continue
            seen.add(url)

            # raw_text snippet: take ~400 chars around the match
            start = max(0, m.start() - 150)
            end = min(len(html), m.end() + 250)
            snippet = html[start:end]
            snippet_clean = re.sub(r"<[^>]+>", " ", snippet)
            snippet_clean = re.sub(r"\s+", " ", snippet_clean).strip()[:400]

            out.append({
                "source_url": url,
                "raw_text": snippet_clean,
                "raw_html": snippet,  # full markup snippet for debugging
                "detail_kind": kind,
            })
    return out


def insert_raw(conn, source_name: str, items: list[dict]) -> int:
    inserted = 0
    with conn.cursor() as cur:
        for it in items:
            cur.execute(
                """
                INSERT INTO public.raw_listings (source_name, source_url, raw_text, raw_html, status)
                VALUES (%s, %s, %s, %s, 'pending')
                ON CONFLICT (source_url) DO NOTHING
                """,
                (source_name, it["source_url"], it["raw_text"], it["raw_html"]),
            )
            if cur.rowcount:
                inserted += 1
        conn.commit()
    return inserted


def main() -> int:
    p = argparse.ArgumentParser(description="Lamudi Bali 2BR villa scraper")
    p.add_argument("--source-name", default="lamudi_bali")
    p.add_argument("--slugs", nargs="+", default=DEFAULT_SLUGS,
                   help=f"area slugs (default: {' '.join(DEFAULT_SLUGS)})")
    p.add_argument("--max-pages", type=int, default=2, help="pages per slug (default 2)")
    p.add_argument("--min-pause", type=float, default=25.0, help="min seconds between pages")
    p.add_argument("--max-pause", type=float, default=75.0, help="max seconds between pages")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--limit-new", type=int, default=0, help="stop after N new detail URLs (0=unlimited)")
    args = p.parse_args()

    session = rq.Session(impersonate=IMPERSONATE)

    # Warm-up
    log(f"[warm] GET {WARM_URL}")
    try:
        r = fetch(session, WARM_URL, referer="https://www.google.com/")
    except Exception as e:
        log(f"[warm] exception: {e!r}")
        return 1
    if is_blocked(r):
        log(f"[warm] blocked: HTTP {r.status_code}")
        return 2
    time.sleep(random.uniform(args.min_pause, args.max_pause))

    all_items: list[dict] = []
    seen_urls: set[str] = set()
    errors = 0
    slugs = list(args.slugs)
    random.shuffle(slugs)  # randomize order across slugs (human-like browsing)

    referer = WARM_URL
    for si, slug in enumerate(slugs):
        for page in range(1, args.max_pages + 1):
            path = PATH_TPL.format(slug=slug)
            url = BASE + path if page == 1 else f"{BASE}{path}?page={page}"
            log(f"[slug={slug} page={page}] GET {url}")
            try:
                r = fetch(session, url, referer=referer)
            except Exception as e:
                log(f"  [err] {e!r}")
                errors += 1
                break

            if r.status_code == 404:
                log(f"  [404] no page {page} for slug={slug} (end of pagination)")
                break

            if is_blocked(r):
                log(f"  [blocked] HTTP {r.status_code} — switching slug (canon #9 event-driven)")
                errors += 1
                break

            items = parse_list_page(r.text, BASE)
            new = [it for it in items if it["source_url"] not in seen_urls]
            for it in new:
                seen_urls.add(it["source_url"])
                # tag with slug for diagnostics
                it["raw_text"] = f"[lamudi/{slug}/p{page}] {it['raw_text']}"
            all_items.extend(new)
            log(f"  [ok] parsed {len(items)}, new {len(new)}, running total {len(all_items)}")

            if args.limit_new > 0 and len(all_items) >= args.limit_new:
                log(f"  [limit] reached --limit-new={args.limit_new}, stopping")
                break

            referer = url
            # human pause between pages
            pause = random.uniform(args.min_pause, args.max_pause)
            log(f"  [pause ~{pause:.0f}s]")
            time.sleep(pause)

        if args.limit_new > 0 and len(all_items) >= args.limit_new:
            break

        # longer pause between slugs (like a human switching area of interest)
        if si + 1 < len(slugs):
            pause = random.uniform(args.min_pause * 2, args.max_pause * 2)
            log(f"[slug-switch pause ~{pause:.0f}s]")
            time.sleep(pause)

    log(f"[done] total detail URLs: {len(all_items)} ({errors} errors)")

    if args.dry_run:
        for it in all_items[:5]:
            print(f"  {it['detail_kind']:9s} {it['source_url']}")
        print(f"(dry-run: {len(all_items)} URLs, first 5 shown)")
        return 0

    try:
        with psycopg.connect(DB_DSN) as conn:
            inserted = insert_raw(conn, args.source_name, all_items)
    except Exception as e:
        log(f"[db] error: {e!r}")
        return 1

    log(f"[db] inserted: {inserted} new raw_listings (rest were duplicates)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
