#!/usr/bin/env python3
"""Audit library index + filesystem hygiene. Report issues, suggest fixes."""
import json, os, re
from pathlib import Path
from collections import Counter, defaultdict

BASE = Path("C:/work/realty-portal")
SCHOOL = BASE / "docs/school"
EXPORT = BASE / "docs/alexey-reference/export-2026-04-20"

lib = json.load(open(SCHOOL / "library_index.json", encoding="utf-8"))
posts = lib["posts"]

issues = defaultdict(list)

# 1. Empty titles
for p in posts:
    if p["title"].startswith("[без текста]"):
        issues["empty_title"].append(p["msg_id"])

# 2. Duplicate titles (ambiguous)
title_counts = Counter(p["title"] for p in posts)
for title, cnt in title_counts.items():
    if cnt > 1 and title != "[без текста]":
        ids = [p["msg_id"] for p in posts if p["title"] == title]
        issues["dup_titles"].append(f"{cnt}×: {title[:60]} → msgs {ids}")

# 3. Posts with no topics
no_topics = [p for p in posts if not p["topics"]]
issues["no_topics"] = [p["msg_id"] for p in posts if not p["topics"]]

# 4. Zero-byte files flagged
for p in posts:
    size = p.get("size_mb", 0)
    if size and size < 1:
        issues["tiny_media"].append(f"msg {p['msg_id']}: {size}MB {p.get('filename','')}")

# 5. Type mismatches (text posts with filenames — impossible, media posts without filenames)
for p in posts:
    if p["type"] != "text" and not p.get("filename"):
        issues["media_no_filename"].append(p["msg_id"])

# 6. Typo check in topics
all_topics = set()
for p in posts:
    all_topics.update(p["topics"])
weird_topics = [t for t in all_topics if len(t) < 2 or t.startswith("_")]
if weird_topics:
    issues["weird_topics"] = weird_topics

# 7. Missing full text (if short truncated)
for p in posts:
    if p["text_preview"] and len(p["text_preview"]) == 400:
        issues["text_possibly_truncated"].append(p["msg_id"])

# 8. Date format
for p in posts:
    if not p["date"] or "T" not in p["date"]:
        issues["bad_date"].append(p["msg_id"])

# Print report
print("=" * 60)
print("LIBRARY AUDIT REPORT")
print("=" * 60)
print(f"\nTotal posts: {len(posts)}")
print(f"Total topics: {len(all_topics)}")
print()

for key, vals in issues.items():
    if isinstance(vals, list) and vals and isinstance(vals[0], int):
        print(f"⚠ {key}: {len(vals)} items")
        print(f"   e.g. msg_ids: {vals[:10]}{'...' if len(vals) > 10 else ''}")
    elif vals:
        print(f"⚠ {key}: {len(vals)} items")
        for v in vals[:5]:
            print(f"   {v}")
        if len(vals) > 5:
            print(f"   ... and {len(vals) - 5} more")

# Topic distribution
print("\n=== Topic distribution ===")
topic_counts = Counter()
for p in posts:
    for t in p["topics"]:
        topic_counts[t] += 1
for topic, cnt in topic_counts.most_common():
    print(f"  {topic}: {cnt}")

# Size stats
print("\n=== Media stats ===")
total_size_mb = sum(p.get("size_mb", 0) for p in posts)
media_posts = [p for p in posts if p.get("size_mb", 0) > 0]
print(f"Posts with media: {len(media_posts)}")
print(f"Total media size in channel: {total_size_mb/1024:.2f} GB")

# Priority distribution
print("\n=== Priority distribution ===")
prio_c = Counter(p.get("priority", "N/A") for p in posts)
for prio, cnt in prio_c.most_common():
    print(f"  {prio}: {cnt}")
