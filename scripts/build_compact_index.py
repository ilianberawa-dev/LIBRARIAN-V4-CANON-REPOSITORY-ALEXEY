#!/usr/bin/env python3
"""
Создаёт компактный индекс библиотеки.
Сливает: library_index.json + transcript_keys.json + taxonomy.json
Результат: index_compact.json (~30-50 КБ — для загрузки в чат)
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "alexey-materials" / "metadata"

with open(META / "library_index.json", encoding="utf-8") as f:
    full = json.load(f)
with open(META / "transcript_keys.json", encoding="utf-8") as f:
    tkeys = json.load(f)
with open(META / "taxonomy.json", encoding="utf-8") as f:
    taxonomy = json.load(f)["categories"]

# Построить обратный маппинг tag -> category
tag_to_cat = {}
for cat_id, cat_data in taxonomy.items():
    for tag in cat_data.get("tags", []):
        tag_to_cat[tag.lower()] = cat_id

def assign_category(topics):
    if not topics:
        return "PRINCIPLES_BIZ"
    counts = {}
    for t in topics:
        cat = tag_to_cat.get(t.lower())
        if cat:
            counts[cat] = counts.get(cat, 0) + 1
    if not counts:
        return "PRINCIPLES_BIZ"
    return max(counts.items(), key=lambda x: x[1])[0]

posts_compact = []
for p in full["posts"]:
    msg_id = p["msg_id"]
    record = {
        "id": msg_id,
        "title": p.get("title", "")[:120],
        "category": assign_category(p.get("topics") or []),
        "topics": p.get("topics") or [],
        "type": p.get("type", "text"),
        "url": p.get("url", ""),
        "preview": (p.get("text_preview") or "")[:300],
    }
    # Транскрипт ключи
    if str(msg_id) in tkeys:
        record["transcript_keys"] = tkeys[str(msg_id)][:10]
        record["has_transcript"] = True
    if p.get("filename"):
        record["filename"] = p["filename"]
    posts_compact.append(record)

# Статистика
from collections import Counter
cat_stats = Counter(p["category"] for p in posts_compact)

out = {
    "version": "1.0",
    "generated": "2026-04-27",
    "total": len(posts_compact),
    "category_stats": dict(cat_stats.most_common()),
    "posts": posts_compact
}

OUT = META / "index_compact.json"
OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
size_kb = OUT.stat().st_size / 1024
print(f"OK — {len(posts_compact)} записей, {size_kb:.1f} КБ")
print()
print("Распределение по категориям:")
for cat, n in cat_stats.most_common():
    print(f"  {n:3d}  {cat}")
