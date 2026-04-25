#!/usr/bin/env python3
"""Fetch Rumah123 detail pages for URLs already in raw_listings.

Populates:
  raw_listings.raw_detail_html
  raw_listings.detail_fetched_at
  raw_listings.detail_status ∈ {ok, blocked, not_found, error}

Handles CloudFlare via curl_cffi chrome120 impersonation + warm-up pattern.
On 403: retry once with 60s backoff, then mark 'blocked' — don't hammer.

Usage:
  python3 fetch_details.py --limit 5 --rate-limit 15 --dry-run
  python3 fetch_details.py --limit 20 --rate-limit 15
  python3 fetch_details.py --all --rate-limit 15
  python3 fetch_details.py --retry-blocked    # only retry entries marked 'blocked'
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from typing import Optional

import psycopg
from curl_cffi import requests as rq

DB_DSN = os.environ["REALTY_DB_DSN"]

IMPERSONATE = "chrome120"
WARMUP_EVERY = 15  # re-fetch home page every N details
BACKOFF_SEC = 60

# Source-specific configs (fetch_details is now multi-source aware)
SOURCE_CONFIG = {
    "rumah123_bali": {
        "warm_url": "https://www.rumah123.com/",
        "block_markers": ("just a moment", "cloudflare", "cf-chl"),
    },
    "lamudi_bali": {
        "warm_url": "https://www.lamudi.co.id/",
        "block_markers": ("just a moment", "cloudflare", "cf-chl", "access denied", "captcha", "halaman tidak ditemukan"),
    },
}
# back-compat module-level defaults
WARM_URL = SOURCE_CONFIG["rumah123_bali"]["warm_url"]
BLOCK_MARKERS = SOURCE_CONFIG["rumah123_bali"]["block_markers"]


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def is_blocked(resp, markers=None) -> bool:
    if resp.status_code in (403, 429, 503):
        return True
    if resp.status_code != 200:
        return False  # other codes — not CF block
    head = resp.text[:500].lower()
    for m in (markers or BLOCK_MARKERS):
        if m in head:
            return True
    return False


def fetch_one(session, url: str, referer: str, timeout: int = 25):
    return session.get(url, headers={"Referer": referer}, timeout=timeout)


def fetch_pending(conn, limit: int, retry_blocked: bool, source_name: str) -> list[tuple[str, str]]:
    with conn.cursor() as cur:
        if retry_blocked:
            cur.execute(
                "SELECT id, source_url FROM public.raw_listings "
                "WHERE detail_status = 'blocked' AND source_name = %s "
                "ORDER BY detail_fetched_at ASC LIMIT %s",
                (source_name, limit),
            )
        else:
            cur.execute(
                "SELECT id, source_url FROM public.raw_listings "
                "WHERE detail_fetched_at IS NULL AND source_name = %s "
                "ORDER BY created_at ASC LIMIT %s",
                (source_name, limit),
            )
        return cur.fetchall()


def save_detail(conn, row_id: str, html: Optional[str], status: str) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE public.raw_listings SET raw_detail_html=%s, detail_fetched_at=now(), detail_status=%s WHERE id=%s",
            (html, status, row_id),
        )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=10)
    p.add_argument("--all", action="store_true")
    p.add_argument("--rate-limit", type=float, default=15.0)
    p.add_argument("--retry-blocked", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--source-name", default="rumah123_bali",
                   help=f"source to fetch details for (one of: {sorted(SOURCE_CONFIG.keys())})")
    args = p.parse_args()

    limit = 1000 if args.all else args.limit

    cfg = SOURCE_CONFIG.get(args.source_name)
    if not cfg:
        log(f"ERROR: unknown --source-name={args.source_name}. Known: {sorted(SOURCE_CONFIG.keys())}")
        return 1
    warm_url = cfg["warm_url"]
    block_markers = cfg["block_markers"]

    with psycopg.connect(DB_DSN, connect_timeout=10) as conn:
        rows = fetch_pending(conn, limit, args.retry_blocked, args.source_name)
    log(f"queued {len(rows)} detail urls (source={args.source_name}, retry_blocked={args.retry_blocked})")

    if not rows:
        return 0

    session = rq.Session(impersonate=IMPERSONATE)

    # warm-up with retry (CF can bounce us even when probe passed)
    warm_ok = False
    for attempt in range(1, 4):
        log(f"warm-up attempt {attempt}: GET {warm_url}")
        try:
            r0 = session.get(warm_url, timeout=20,
                             headers={"Accept-Language": "en-US,en;q=0.9,id;q=0.8"})
            if not is_blocked(r0, block_markers):
                log(f"warm-up OK: HTTP {r0.status_code} len={len(r0.text)}")
                warm_ok = True
                break
            log(f"warm-up blocked: HTTP {r0.status_code}, sleep {BACKOFF_SEC}s")
            time.sleep(BACKOFF_SEC)
        except Exception as e:
            log(f"warm-up exception: {e!r}, sleep {BACKOFF_SEC}s")
            time.sleep(BACKOFF_SEC)
    if not warm_ok:
        log("warm-up failed after 3 attempts — aborting")
        return 2
    time.sleep(args.rate_limit)

    referer = warm_url
    counts = {"ok": 0, "blocked": 0, "error": 0, "not_found": 0}
    t0 = time.time()

    for i, (row_id, url) in enumerate(rows, 1):
        # periodic warm-up
        if i > 1 and i % WARMUP_EVERY == 0:
            try:
                session.get(warm_url, timeout=20)
                time.sleep(args.rate_limit)
                log(f"[{i}/{len(rows)}] refreshed warm-up")
            except Exception:
                pass

        # attempt 1
        status, html = _attempt(session, url, referer, block_markers)

        # retry once on block
        if status == "blocked":
            log(f"[{i}/{len(rows)}] blocked, backoff {BACKOFF_SEC}s then retry")
            time.sleep(BACKOFF_SEC)
            try:
                session.get(warm_url, timeout=20)
                time.sleep(5)
            except Exception:
                pass
            status, html = _attempt(session, url, referer, block_markers)

        counts[status] += 1
        tag = url[-55:]
        log(f"[{i}/{len(rows)}] {status.upper():8s} {tag}  "
            f"(len={len(html) if html else 0})")

        if not args.dry_run:
            with psycopg.connect(DB_DSN, connect_timeout=10) as conn:
                save_detail(conn, row_id, html if status == "ok" else None, status)

        referer = url
        # if we just got blocked+blocked sequence — extend rate limit for next calls
        wait = args.rate_limit * (2 if status == "blocked" else 1)
        time.sleep(wait)

    dt = time.time() - t0
    log("")
    log("=" * 60)
    log(f"DONE in {dt:.0f}s: ok={counts['ok']} blocked={counts['blocked']} "
        f"not_found={counts['not_found']} error={counts['error']}")
    return 0 if counts["error"] == 0 else 2


def _attempt(session, url: str, referer: str, block_markers=None) -> tuple[str, Optional[str]]:
    try:
        r = fetch_one(session, url, referer)
    except Exception as e:
        return ("error", f"exception: {e!r}"[:500])
    if r.status_code == 404:
        return ("not_found", None)
    if is_blocked(r, block_markers):
        return ("blocked", None)
    if r.status_code != 200:
        return ("error", f"HTTP {r.status_code}")
    return ("ok", r.text)


if __name__ == "__main__":
    sys.exit(main())
