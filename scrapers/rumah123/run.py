#!/usr/bin/env python3
"""Rumah123 Bali scraper (MVP).

Парсит /jual/bali/rumah/ страницы 1..max_pages через curl_cffi + BS4,
пишет карточки в public.raw_listings (status='pending'), обновляет public.sources.

Детерминированный контракт — см. skills/parse_listings_web/SKILL.md.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from typing import Optional

from bs4 import BeautifulSoup
from curl_cffi import requests as rq

BASE = "https://www.rumah123.com"
WARM_URL = BASE + "/"
LIST_PATH = "/jual/bali/rumah/"
PRICE_SELECTOR = '[data-testid="ldp-text-price"]'
LISTING_LINK_SELECTOR = 'a[href*="/properti/"]'
IMPERSONATE = "chrome120"
BLOCK_MARKERS = ("just a moment", "cloudflare", "cf-chl")
CONTAINER_CLIMB_MAX = 15

RE_SPECS_TOKEN = re.compile(r"\d+(?:\s*\+\s*\d+)?")
RE_LEADING_INT = re.compile(r"^\s*(\d+)")
RE_LAND = re.compile(r"LT[:\s]*(\d+)\s*m", re.I)
RE_BUILDING = re.compile(r"LB[:\s]*(\d+)\s*m", re.I)
RE_LOCATION = re.compile(r"^[A-Za-z][A-Za-z\s]*,\s*[A-Za-z][A-Za-z\s]*$")


def is_blocked(resp) -> bool:
    if resp.status_code != 200:
        return True
    head = resp.text[:500].lower()
    return any(marker in head for marker in BLOCK_MARKERS)


def fetch(session, url: str, referer: Optional[str], timeout: int = 25):
    headers = {"Referer": referer} if referer else {}
    return session.get(url, headers=headers, timeout=timeout)


def _num(regex: re.Pattern, text: str) -> Optional[int]:
    m = regex.search(text)
    return int(m.group(1)) if m else None


def _find_card_container(price_el):
    """Подняться от price до ближайшего предка, содержащего <a href*=/properti/>."""
    node = price_el
    for _ in range(CONTAINER_CLIMB_MAX):
        node = node.parent
        if node is None:
            return None
        if node.find("a", href=lambda h: h and "/properti/" in h):
            return node
    return None


def _extract_location(card) -> str:
    """Location = первый <p>/<span> с текстом 'X, Y' без цифр/валюты."""
    for el in card.find_all(["p", "span"]):
        t = el.get_text(strip=True)
        if not t or "Rp" in t or any(ch.isdigit() for ch in t):
            continue
        if RE_LOCATION.match(t):
            return t
    return ""


def _extract_specs_block(card):
    """Найти <div>, текст которого содержит и 'LT' и 'LB' (блок specs)."""
    for d in card.find_all("div"):
        t = d.get_text(" ", strip=True)
        if "LT" in t and "LB" in t and len(t) < 120:
            return d
    return None


def parse_list_page(html: str) -> list[dict]:
    soup = BeautifulSoup(html, "lxml")
    out = []
    seen_in_page = set()

    for price_el in soup.select(PRICE_SELECTOR):
        card = _find_card_container(price_el)
        if card is None:
            continue

        link = card.find("a", href=lambda h: h and "/properti/" in h)
        if link is None:
            continue
        href = link.get("href") or ""
        url = href if href.startswith("http") else BASE + href
        if url in seen_in_page:
            continue
        seen_in_page.add(url)

        title = (link.get("title") or "").strip()
        price_text = price_el.get_text(strip=True)
        location = _extract_location(card)

        bedrooms = bathrooms = None
        land = building = None
        specs = _extract_specs_block(card)
        if specs is not None:
            specs_text = specs.get_text(" ", strip=True)
            before_lt = specs_text.split("LT", 1)[0]
            tokens = RE_SPECS_TOKEN.findall(before_lt)
            if len(tokens) >= 1:
                m = RE_LEADING_INT.match(tokens[0])
                if m:
                    bedrooms = int(m.group(1))
            if len(tokens) >= 2:
                m = RE_LEADING_INT.match(tokens[1])
                if m:
                    bathrooms = int(m.group(1))
            land = _num(RE_LAND, specs_text)
            building = _num(RE_BUILDING, specs_text)

        raw_text = card.get_text(" ", strip=True)
        raw_html = str(card)

        out.append({
            "source_url": url,
            "title": title,
            "price_text": price_text,
            "location": location,
            "bedrooms": bedrooms,
            "bathrooms": bathrooms,
            "land_area_m2": land,
            "building_area_m2": building,
            "raw_text": raw_text,
            "raw_html": raw_html,
        })
    return out


def update_sources(db_url: str, source_name: str, inserted: int, err_increment: int, last_error: Optional[str]) -> None:
    import psycopg
    with psycopg.connect(db_url) as conn, conn.cursor() as cur:
        cur.execute(
            """
            UPDATE public.sources
            SET last_parsed_at = now(),
                total_parsed   = COALESCE(total_parsed, 0) + %s,
                error_count    = COALESCE(error_count, 0) + %s,
                last_error     = %s
            WHERE name = %s
            """,
            (inserted, err_increment, last_error, source_name),
        )


def insert_raw(db_url: str, source_name: str, items: list[dict]) -> int:
    import psycopg
    inserted = 0
    with psycopg.connect(db_url) as conn, conn.cursor() as cur:
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
    return inserted


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def main() -> int:
    p = argparse.ArgumentParser(description="Rumah123 Bali scraper (MVP)")
    p.add_argument("--source-name", default="rumah123_bali")
    p.add_argument("--list-path", default=LIST_PATH,
                   help=f"Bali listing path, default {LIST_PATH}. Other: /jual/bali/villa/, /jual/bali/tanah/, /jual/bali/apartemen/, /jual/bali/ruko/")
    p.add_argument("--max-pages", type=int, default=2)
    p.add_argument("--rate-limit", type=float, default=6.0, help="seconds between requests")
    p.add_argument("--dry-run", action="store_true", help="parse only, no DB writes, print JSON preview")
    p.add_argument("--db-url", default=os.environ.get("REALTY_DB_DSN") or os.environ.get("DATABASE_URL"))
    args = p.parse_args()

    if not args.dry_run and not args.db_url:
        log("ERROR: REALTY_DB_DSN not set (source .env via scripts/run_with_env.sh, or pass --db-url)")
        return 1

    session = rq.Session(impersonate=IMPERSONATE)

    # Warm-up
    log(f"warm-up: GET {WARM_URL}")
    try:
        r = fetch(session, WARM_URL, referer=None)
    except Exception as e:
        log(f"warm-up exception: {e!r}")
        if not args.dry_run:
            update_sources(args.db_url, args.source_name, 0, 1, f"warm-up exception: {e!r}"[:500])
        return 1
    if is_blocked(r):
        msg = f"warm-up blocked: HTTP {r.status_code}"
        log(msg)
        if not args.dry_run:
            update_sources(args.db_url, args.source_name, 0, 1, msg[:500])
        return 2
    time.sleep(args.rate_limit)

    # List pages
    all_items: list[dict] = []
    seen_urls: set[str] = set()
    referer = WARM_URL
    last_error: Optional[str] = None

    for page in range(1, args.max_pages + 1):
        url = BASE + args.list_path if page == 1 else f"{BASE}{args.list_path}?page={page}"
        log(f"page {page}: GET {url}")
        try:
            r = fetch(session, url, referer=referer)
        except Exception as e:
            last_error = f"page {page} exception: {e!r}"[:500]
            log(last_error)
            break
        if is_blocked(r):
            last_error = f"page {page} blocked: HTTP {r.status_code}"
            log(last_error)
            break
        items = parse_list_page(r.text)
        new_items = [it for it in items if it["source_url"] not in seen_urls]
        for it in new_items:
            seen_urls.add(it["source_url"])
        log(f"page {page}: {len(items)} cards ({len(new_items)} new in this run)")
        all_items.extend(new_items)
        referer = url
        if page < args.max_pages:
            time.sleep(args.rate_limit)

    log(f"parsed total: {len(all_items)}")

    if args.dry_run:
        preview = [
            {k: v for k, v in it.items() if k != "raw_html"}
            for it in all_items[:3]
        ]
        print(json.dumps(preview, ensure_ascii=False, indent=2))
        print(f"(dry-run: {len(all_items)} cards parsed, first 3 shown without raw_html)")
        return 0

    err_increment = 1 if last_error else 0
    try:
        inserted = insert_raw(args.db_url, args.source_name, all_items)
    except Exception as e:
        msg = f"DB insert exception: {e!r}"[:500]
        log(msg)
        update_sources(args.db_url, args.source_name, 0, 1, msg)
        return 1

    update_sources(args.db_url, args.source_name, inserted, err_increment, last_error)
    log(f"inserted: {inserted}, errors: {err_increment}, last_error: {last_error}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
