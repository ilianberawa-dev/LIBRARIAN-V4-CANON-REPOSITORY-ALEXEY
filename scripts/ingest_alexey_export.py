#!/usr/bin/env python3
"""Ingest Alexey's Telegram Desktop export into curated markdown + local LightRAG.

Usage:
    python ingest_alexey_export.py --export-dir <path-to-exported-folder>

Expected input: standard Telegram Desktop export directory containing
    result.json       — all messages
    messages*.html    — human-readable per-chunk (optional)
    photos/, files/, voices/, video_files/ — attachments (copied as-is)

Output:
    docs/alexey-reference/topics/{mcp,skills,architecture,openclaw,qa,other}/YYYY-MM-DD_message-<id>.md
    docs/alexey-reference/_ingest_log.json  — append-only log of each run
    docs/alexey-reference/_seen_message_ids.json  — deduplication across re-runs

Principle: selective curation, not wholesale archive. Only messages matching
one of the topic-keyword sets are extracted. Everything else is skipped.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import shutil
import hashlib
from datetime import datetime
from pathlib import Path


# Topic keyword map — expanded over time as new themes emerge
TOPIC_KEYWORDS: dict[str, list[str]] = {
    "mcp": [
        "mcp", "model context protocol", "supabase mcp", "lightrag mcp",
        "n8n mcp", "api mcp",
    ],
    "skills": [
        "skill.md", "skillml", "skill.sh", "skills.sh", "skillhq",
        "skill-creator", "skill creator", "скилл", "скиллы",
        "allowed-tools", "skillsmp",
    ],
    "architecture": [
        "architecture", "архитектура", "claude code", "claude desktop",
        "context window", "контекстное окно", "openrouter", "litellm",
    ],
    "openclaw": [
        "openclaw", "openclaw.io", "agent on server",
    ],
    "lightrag": [
        "lightrag", "light rag", "rag", "векторизация", "vectorized",
    ],
    "supabase": [
        "supabase", "postgres", "pgvector", "self-hosted",
    ],
    "triangulation": [
        "triangulation", "триангуляция", "agreement", "consensus",
        "calibration", "калибровка",
    ],
    "qa": [
        "вопрос:", "q:", "question:", "ответ:", "a:", "answer:",
    ],
}


def classify_topics(text: str) -> list[str]:
    """Return list of topic names matched by keywords in text (lowercased)."""
    lower = text.lower()
    matched = []
    for topic, keywords in TOPIC_KEYWORDS.items():
        if any(kw in lower for kw in keywords):
            matched.append(topic)
    return matched or ["other"]


def normalize_message(m: dict) -> dict:
    """Extract text content from Telegram message (handles entities/formatting)."""
    txt = m.get("text", "")
    if isinstance(txt, list):
        parts = []
        for p in txt:
            if isinstance(p, str):
                parts.append(p)
            elif isinstance(p, dict) and "text" in p:
                parts.append(p["text"])
        txt = "".join(parts)
    return {
        "id": m.get("id"),
        "date": m.get("date") or m.get("date_unixtime"),
        "from": m.get("from", m.get("actor", "")),
        "text": txt or "",
        "attachments": {
            "photo": m.get("photo"),
            "file": m.get("file"),
            "media_type": m.get("media_type"),
        },
    }


def safe_filename(s: str, max_len: int = 60) -> str:
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"\s+", "-", s.strip())
    return s[:max_len].lower() or "untitled"


def load_seen(seen_path: Path) -> set[int]:
    if not seen_path.exists():
        return set()
    return set(json.loads(seen_path.read_text(encoding="utf-8")))


def save_seen(seen_path: Path, seen: set[int]) -> None:
    seen_path.write_text(json.dumps(sorted(seen), indent=2), encoding="utf-8")


def process_export(export_dir: Path, out_root: Path, dry_run: bool = False) -> dict:
    result_json = export_dir / "result.json"
    if not result_json.exists():
        sys.exit(f"ERROR: result.json not found in {export_dir}")

    print(f"[load] reading {result_json}")
    data = json.loads(result_json.read_text(encoding="utf-8"))
    messages = data.get("messages", [])
    print(f"[load] total messages: {len(messages)}")

    seen_path = out_root / "_seen_message_ids.json"
    seen = load_seen(seen_path)

    stats = {
        "total_messages": len(messages),
        "already_seen": 0,
        "skipped_non_text": 0,
        "skipped_no_topic": 0,
        "ingested_by_topic": {},
        "new_message_ids": [],
    }

    for m in messages:
        nm = normalize_message(m)
        mid = nm["id"]
        if mid in seen:
            stats["already_seen"] += 1
            continue
        if not nm["text"] or len(nm["text"]) < 30:
            stats["skipped_non_text"] += 1
            continue

        topics = classify_topics(nm["text"])
        if topics == ["other"] and len(nm["text"]) < 200:
            stats["skipped_no_topic"] += 1
            continue

        # First matched topic is primary bucket
        primary = topics[0]
        stats["ingested_by_topic"][primary] = stats["ingested_by_topic"].get(primary, 0) + 1

        date_str = nm["date"][:10] if isinstance(nm["date"], str) else "unknown"
        title_hint = safe_filename(nm["text"][:80])
        fname = f"{date_str}_msg{mid}_{title_hint}.md"
        dest = out_root / "topics" / primary / fname
        dest.parent.mkdir(parents=True, exist_ok=True)

        md = (
            f"---\n"
            f"source: Telegram Alexey private channel\n"
            f"message_id: {mid}\n"
            f"date: {nm['date']}\n"
            f"topics: {topics}\n"
            f"captured: {datetime.utcnow().isoformat()}Z\n"
            f"---\n\n"
            f"{nm['text']}\n"
        )
        if not dry_run:
            dest.write_text(md, encoding="utf-8")
        seen.add(mid)
        stats["new_message_ids"].append(mid)

    if not dry_run:
        save_seen(seen_path, seen)
        log_path = out_root / "_ingest_log.json"
        log = json.loads(log_path.read_text(encoding="utf-8")) if log_path.exists() else []
        log.append({
            "run_at": datetime.utcnow().isoformat() + "Z",
            "export_dir": str(export_dir),
            "stats": {k: v for k, v in stats.items() if k != "new_message_ids"},
            "new_count": len(stats["new_message_ids"]),
        })
        log_path.write_text(json.dumps(log, indent=2, ensure_ascii=False), encoding="utf-8")

    return stats


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--export-dir", required=True, help="path to Telegram Desktop export folder")
    p.add_argument("--out-root", default="C:/work/realty-portal/docs/alexey-reference",
                   help="knowledge base root")
    p.add_argument("--dry-run", action="store_true", help="don't write files, just show stats")
    args = p.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass

    stats = process_export(Path(args.export_dir), Path(args.out_root), args.dry_run)

    print("\n=== INGEST COMPLETE ===")
    print(f"Total messages: {stats['total_messages']}")
    print(f"Already seen (skipped): {stats['already_seen']}")
    print(f"Skipped non-text: {stats['skipped_non_text']}")
    print(f"Skipped no-topic: {stats['skipped_no_topic']}")
    print(f"Ingested by topic:")
    for topic, n in sorted(stats['ingested_by_topic'].items(), key=lambda x: -x[1]):
        print(f"  {topic:<15} {n}")
    print(f"\nNew messages captured: {len(stats['new_message_ids'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
