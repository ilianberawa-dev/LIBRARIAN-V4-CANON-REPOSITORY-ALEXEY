#!/usr/bin/env python3
"""Classify P4 (video/audio) files from Alexey channel by code/sales relevance.

Logic:
  - For each P4 item: get its caption OR nearest neighboring message text
  - Score by keyword categories: CODE, SALES, CHIT
  - HIGH = code>=3 OR sales>=3
  - MED = 1<=code+sales<3
  - LOW = 0 (chit-chat or no context)
Output: p4_priority.json with ranked list (HIGH first, smallest first within tier)
"""

import json
from pathlib import Path

CATALOG = "C:/work/realty-portal/docs/alexey-reference/export-2026-04-20/p4_catalog.json"
DUMP = "C:/work/realty-portal/docs/alexey-reference/export-2026-04-20/result.json"
OUT = "C:/work/realty-portal/docs/alexey-reference/export-2026-04-20/p4_priority.json"

CODE_KW = [
    "скрипт","api","mcp","docker","n8n","supabase","agent","код","sql","bash","python",
    "typescript","javascript","устан","setup","deploy","install","config","cli","github",
    "npm","kilo","claude code","cursor","gemini","openclaw","lightrag","paperclip","baserow",
    "kong","nginx","postgres","webhook","endpoint","env","cron","systemd","ubuntu","vps",
    "сервер","контейнер","команд","workflow","автомати","леший","skillhq","skill","botfather",
    "docker-compose","docker compose","supabase mcp","n8n mcp","mtproto","telegram api",
    "кластер","векторн","rag","llm","prompt","embedding","промпт","агент","скилл",
    "tribute","монетиз","ingest","pipeline","fetch","json",
]
SALES_KW = [
    "продаж","монетиз","лид","маркет","конверс","воронк","клиент","бизнес","доход","подписк",
    "тариф","реклам","crm","email маркет","онбординг","retention","trial","platежm","stripe",
    "платеж","контент-завод","trend","контент","dashboard","assistant","ассистент","продавец",
    "ценник","прайс","оплата","checkout","продукт","метрики","аналитика",
]
CHIT_KW = [
    "привет","поделиться мыслями","подпишись","коммент","о жизни","ламповый","чаек",
    "размышления","размышляю","новости","обсуждение","живой эфир","дисклэймер",
    "новый день","доброе утро","отдохну","выходной","отпуск","путешеств","семья","женили",
]


def score(text: str):
    if not text:
        return (0, 0, 0)
    t = text.lower()
    c = sum(t.count(k) for k in CODE_KW)
    s = sum(t.count(k) for k in SALES_KW)
    ch = sum(t.count(k) for k in CHIT_KW)
    return (c, s, ch)


def category(c, s, ch):
    if c + s == 0 and ch >= 2:
        return "LOW_CHIT"
    if c >= 3 and c > s * 1.5:
        return "HIGH_CODE"
    if s >= 3:
        return "HIGH_SALES"
    if c + s >= 3:
        return "HIGH_MIXED"
    if c + s >= 1:
        return "MED"
    return "LOW_UNCLEAR"


def main():
    cat = json.load(open(CATALOG, encoding="utf-8"))
    dump = json.load(open(DUMP, encoding="utf-8"))
    msgs_by_id = {m["id"]: m for m in dump["messages"]}

    ranked = []
    for item in cat["items"]:
        mid = item["msg_id"]
        # Own caption first
        text = item.get("caption", "") or ""
        source = "own"

        # If own caption empty, look at ±2 neighbors
        if not text.strip():
            for offset in [-1, 1, -2, 2]:
                nid = mid + offset
                if nid in msgs_by_id and (msgs_by_id[nid].get("text") or ""):
                    text = msgs_by_id[nid]["text"]
                    source = f"neighbor_{offset:+d}"
                    break

        c, s, ch = score(text)
        cat_tag = category(c, s, ch)

        ranked.append({
            "msg_id": mid,
            "filename": item["filename"],
            "size_mb": item["size_mb"],
            "size_bytes": item["size_bytes"],
            "date": item["date"],
            "category": cat_tag,
            "code_score": c,
            "sales_score": s,
            "chit_score": ch,
            "caption_source": source,
            "caption_sample": text[:200],
        })

    # Sort: HIGH first, smaller first within tier
    priority_order = {"HIGH_CODE": 0, "HIGH_SALES": 1, "HIGH_MIXED": 2, "MED": 3, "LOW_UNCLEAR": 4, "LOW_CHIT": 5}
    ranked.sort(key=lambda r: (priority_order[r["category"]], r["size_bytes"]))

    # Cumulative cost estimate (Grok STT $0.10/hour; assume 500 MB/hour average compression)
    total_sec = 0
    cumul_mb = 0
    for r in ranked:
        est_sec = r["size_bytes"] / (500 * 1024 * 1024 / 3600)  # 500 MB/hour
        r["est_duration_sec"] = round(est_sec, 1)
        r["est_cost_usd"] = round(est_sec / 3600 * 0.10, 4)
        total_sec += est_sec
        cumul_mb += r["size_mb"]
        r["cumul_cost_usd"] = round(total_sec / 3600 * 0.10, 4)
        r["cumul_size_mb"] = round(cumul_mb, 1)

    json.dump({"total_items": len(ranked), "items": ranked}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

    from collections import Counter
    c = Counter(r["category"] for r in ranked)
    print("=== Priority distribution ===")
    for k, v in sorted(c.items(), key=lambda x: priority_order.get(x[0], 9)):
        print(f"  {k}: {v}")

    print("\n=== HIGH priority (sorted small-first) ===")
    for r in ranked:
        if r["category"].startswith("HIGH"):
            print(f"  [{r['category']}] msg {r['msg_id']}: {r['size_mb']} MB | c={r['code_score']} s={r['sales_score']} | ~${r['est_cost_usd']} | cumul ${r['cumul_cost_usd']}")
            print(f"      \"{r['caption_sample'][:150]}\"")

    print(f"\n=== Budget check ===")
    high_only = [r for r in ranked if r["category"].startswith("HIGH")]
    high_size_gb = sum(r['size_bytes'] for r in high_only) / 1e9
    high_cost = sum(r['est_cost_usd'] for r in high_only)
    print(f"HIGH tier: {len(high_only)} files, {high_size_gb:.2f} GB, ~${high_cost:.2f}")

    med_only = [r for r in ranked if r["category"] == "MED"]
    med_size_gb = sum(r['size_bytes'] for r in med_only) / 1e9
    med_cost = sum(r['est_cost_usd'] for r in med_only)
    print(f"MED tier:  {len(med_only)} files, {med_size_gb:.2f} GB, ~${med_cost:.2f}")

    print(f"\nSaved to: {OUT}")


if __name__ == "__main__":
    main()
