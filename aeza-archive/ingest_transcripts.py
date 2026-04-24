#!/usr/bin/env python3
"""
LightRAG ingest for Telegram transcripts.

Zone: artifact owned by school-v4, deployed by librarian-v3.
Target: Aeza, /opt/tg-export/
Run: cron every 2h, or manual `python3 ingest_transcripts.py`

Reads:
    $TRANSCRIPTS_DIR/*.txt          transcript text
    $TRANSCRIPTS_DIR/*.json         paired metadata (same basename)
    $LIBRARY_INDEX                  optional title/date fallback
    $INGESTED_LOG                   idempotency ledger (one msg_id per line)

Writes:
    POST $LIGHTRAG_URL$LIGHTRAG_INGEST_ENDPOINT   insert document
    append to $INGESTED_LOG                       after successful insert

Env (required):
    LIGHTRAG_API_KEY                bearer token

Env (optional, with defaults):
    LIGHTRAG_URL                    http://localhost:9621
    LIGHTRAG_INGEST_ENDPOINT        /documents/text
    TRANSCRIPTS_DIR                 /opt/tg-export/transcripts
    LIBRARY_INDEX                   /opt/tg-export/library_index.json
    INGESTED_LOG                    /opt/tg-export/ingested.txt
    HTTP_TIMEOUT                    60
    RATE_LIMIT_SLEEP                1.0

Exit codes:
    0   all done (including nothing-to-do)
    1   config error (missing API key)
    2   one or more documents failed; others succeeded
    3   transport error (LightRAG unreachable)
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


# ---------- config ----------

def env(name: str, default: str | None = None) -> str:
    val = os.environ.get(name, default)
    if val is None:
        sys.stderr.write(f"[ingest] missing required env: {name}\n")
        sys.exit(1)
    return val


API_KEY = env("LIGHTRAG_API_KEY")
BASE_URL = env("LIGHTRAG_URL", "http://localhost:9621").rstrip("/")
ENDPOINT = env("LIGHTRAG_INGEST_ENDPOINT", "/documents/text")
TRANSCRIPTS_DIR = Path(env("TRANSCRIPTS_DIR", "/opt/tg-export/transcripts"))
LIBRARY_INDEX = Path(env("LIBRARY_INDEX", "/opt/tg-export/library_index.json"))
INGESTED_LOG = Path(env("INGESTED_LOG", "/opt/tg-export/ingested.txt"))
HTTP_TIMEOUT = float(env("HTTP_TIMEOUT", "60"))
RATE_LIMIT_SLEEP = float(env("RATE_LIMIT_SLEEP", "1.0"))


# ---------- helpers ----------

MSG_ID_IN_NAME = re.compile(r"(?:^|[_\-.])(?:msg[_\-]?)?(\d{2,7})(?:[_\-.]|$)")


def load_index() -> dict[str, dict]:
    if not LIBRARY_INDEX.exists():
        return {}
    try:
        data = json.loads(LIBRARY_INDEX.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        sys.stderr.write(f"[ingest] library_index unreadable: {e}\n")
        return {}
    # accept either {"posts": [...]} or a bare list
    posts = data.get("posts") if isinstance(data, dict) else data
    if not isinstance(posts, list):
        return {}
    return {str(p.get("msg_id")): p for p in posts if p.get("msg_id") is not None}


def load_ingested() -> set[str]:
    if not INGESTED_LOG.exists():
        return set()
    return {
        line.strip()
        for line in INGESTED_LOG.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }


def mark_ingested(msg_id: str) -> None:
    INGESTED_LOG.parent.mkdir(parents=True, exist_ok=True)
    with INGESTED_LOG.open("a", encoding="utf-8") as f:
        f.write(f"{msg_id}\n")


def extract_msg_id(txt_path: Path, meta: dict | None) -> str | None:
    if meta and meta.get("msg_id") is not None:
        return str(meta["msg_id"])
    m = MSG_ID_IN_NAME.search(txt_path.name)
    return m.group(1) if m else None


def load_meta(txt_path: Path) -> dict | None:
    # try: foo.transcript.txt -> foo.transcript.json, foo.txt -> foo.json
    candidates = [
        txt_path.with_suffix(".json"),
        txt_path.with_name(txt_path.name.removesuffix(".txt") + ".json"),
    ]
    for c in candidates:
        if c.exists():
            try:
                return json.loads(c.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
    return None


# ---------- LightRAG client ----------

def post_document(text: str, doc_id: str, metadata: dict) -> tuple[bool, str]:
    body = json.dumps(
        {
            "text": text,
            "description": metadata.get("title") or f"tg msg {metadata.get('msg_id')}",
            "file_source": f"tg-{metadata.get('msg_id')}",
            "ids": [doc_id],
            "metadata": metadata,
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        url=f"{BASE_URL}{ENDPOINT}",
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-API-Key": API_KEY,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return True, f"{resp.status} {resp.read(200).decode('utf-8', 'replace')}"
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        return False, f"HTTP {e.code}: {detail}"
    except urllib.error.URLError as e:
        return False, f"URLError: {e.reason}"


# ---------- main ----------

def main() -> int:
    if not TRANSCRIPTS_DIR.is_dir():
        sys.stderr.write(f"[ingest] TRANSCRIPTS_DIR missing: {TRANSCRIPTS_DIR}\n")
        return 1

    index = load_index()
    ingested = load_ingested()
    transcripts = sorted(TRANSCRIPTS_DIR.glob("*.txt"))
    if not transcripts:
        print(f"[ingest] no .txt files in {TRANSCRIPTS_DIR}")
        return 0

    ok = 0
    skipped = 0
    failed = 0

    for txt in transcripts:
        meta = load_meta(txt) or {}
        msg_id = extract_msg_id(txt, meta)
        if msg_id is None:
            sys.stderr.write(f"[ingest] skip (no msg_id): {txt.name}\n")
            skipped += 1
            continue

        doc_id = f"tg-{msg_id}"
        if msg_id in ingested:
            skipped += 1
            continue

        try:
            text = txt.read_text(encoding="utf-8", errors="replace").strip()
        except OSError as e:
            sys.stderr.write(f"[ingest] read fail {txt.name}: {e}\n")
            failed += 1
            continue
        if not text:
            sys.stderr.write(f"[ingest] empty: {txt.name}\n")
            skipped += 1
            continue

        idx_entry = index.get(msg_id, {})
        metadata = {
            "msg_id": msg_id,
            "doc_id": doc_id,
            "title": meta.get("title") or idx_entry.get("title"),
            "date": meta.get("date") or idx_entry.get("date"),
            "priority": meta.get("priority") or idx_entry.get("priority"),
            "source": "telegram:alexey-kolesov-private",
            "kind": "transcript",
            "file": txt.name,
        }

        success, info = post_document(text, doc_id, metadata)
        if success:
            mark_ingested(msg_id)
            ok += 1
            print(f"[ingest] OK   {doc_id}  {metadata['title'] or ''}")
        else:
            failed += 1
            sys.stderr.write(f"[ingest] FAIL {doc_id}: {info}\n")
            if "404" in info:
                sys.stderr.write(
                    f"[ingest] hint: endpoint {ENDPOINT} may be wrong for this "
                    f"LightRAG version. Try LIGHTRAG_INGEST_ENDPOINT=/documents "
                    f"or /documents/upload.\n"
                )
                return 3

        time.sleep(RATE_LIMIT_SLEEP)

    print(f"[ingest] done: ok={ok} skipped={skipped} failed={failed}")
    if failed and ok == 0:
        return 3
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
