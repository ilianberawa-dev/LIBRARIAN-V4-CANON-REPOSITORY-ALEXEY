#!/usr/bin/env python3
"""Merge chunked transcript JSONs into single file per source."""
import json, glob, os, re

OUT_DIR = "/opt/tg-export/transcripts"

# Find unique base names from _part000 files
part_files = glob.glob(f"{OUT_DIR}/*_part000.transcript.json")
bases = [re.sub(r"_part000\.transcript\.json$", "", os.path.basename(p)) for p in part_files]

for base in bases:
    parts = sorted(glob.glob(f"{OUT_DIR}/{base}_part*.transcript.json"))
    if not parts:
        continue
    combined_text, combined_words, offset = [], [], 0.0
    for p in parts:
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception as e:
            print("skip", p, e)
            continue
        combined_text.append(d.get("text", ""))
        for w in d.get("words", []):
            combined_words.append({
                "text": w.get("text", ""),
                "start": w.get("start", 0) + offset,
                "end": w.get("end", 0) + offset,
            })
        offset += float(d.get("duration", 0))
    out = {
        "text": " ".join(combined_text),
        "words": combined_words,
        "duration": offset,
        "chunked": True,
        "parts": len(parts),
    }
    out_path = f"{OUT_DIR}/{base}.transcript.json"
    json.dump(out, open(out_path, "w", encoding="utf-8"), ensure_ascii=False)
    summary = "merged {b}: {n} parts, {d:.1f}s, {c} chars, {w} words".format(
        b=base, n=len(parts), d=offset, c=len(out["text"]), w=len(combined_words)
    )
    print(summary)
