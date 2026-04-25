#!/usr/bin/env python3
"""V2 library builder: enriched context, no truncation, thread grouping, junk removal."""
import json, re
from pathlib import Path
from collections import defaultdict

BASE = Path("C:/work/realty-portal")
EXPORT = BASE / "docs/alexey-reference/export-2026-04-20"
DUMP = EXPORT / "result.json"
PRIORITY = EXPORT / "p4_priority.json"
SCHOOL = BASE / "docs/school"

CHANNEL_ID = 2653037830
URL_BASE = f"https://t.me/c/{CHANNEL_ID}"

# Broader topic map with Russian aliases
TOPIC_MAP = {
    "LightRAG": ["lightrag", "лайтраг", "граф rag"],
    "Paperclip": ["paperclip", "пейперклип"],
    "OpenClaw": ["openclaw", "опенкло"],
    "Леший": ["леший"],
    "Kilo Code": ["kilo code", "kilocode", "кило код"],
    "Claude Code": ["claude code", "клод код", "claude-code"],
    "Cursor": ["cursor", "курсор"],
    "Gemini CLI": ["gemini cli", "gemini-cli"],
    "n8n": ["n8n", "энейтэйн"],
    "Supabase": ["supabase", "супабейз"],
    "Docker": ["docker", "докер", "докер-композ"],
    "MCP": ["mcp", "model context protocol"],
    "RAG": ["rag", "ретрив", "векторн"],
    "Контент-завод": ["контент-завод", "контент завод"],
    "Skills": ["скилл", "skill.md", "skill_"],
    "Telegram": ["telegram", "телеграм", "тг-", "тг "],
    "N8N MCP": ["n8n mcp", "n8n-mcp"],
    "Supabase MCP": ["supabase mcp", "supabase-mcp"],
    "DevOps": ["devops", "девопс"],
    "Multi-agent": ["мультиагент", "multi-agent", "мультиагент"],
    "Voice": ["голос", "voice", "audio"],
    "Baserow": ["baserow"],
    "Nginx": ["nginx", "nginx-proxy"],
    "Portainer": ["portainer"],
    "VPS": ["vps", "сервер", "vds"],
    "Kilocode": ["kilo"],
    "TGStat": ["tgstat", "тгстат"],
    "BotFather": ["botfather"],
    "Kong": ["kong"],
    "Tribute": ["tribute"],
    "LibreChat": ["librechat"],
}

def extract_title(text):
    if not text:
        return None
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    for line in lines:
        clean = re.sub(r"^[^\wа-яА-ЯёЁ]+", "", line).strip()
        if len(clean) > 8:
            return clean[:150]
    return lines[0][:150] if lines else None

def extract_topics(text):
    t = (text or "").lower()
    topics = []
    for topic, kws in TOPIC_MAP.items():
        if any(kw in t for kw in kws):
            topics.append(topic)
    return topics

def detect_media_type(filename, ext):
    if not filename:
        return "text"
    if ext in {".mp4", ".mov", ".webm", ".mkv", ".avi"}:
        return "video"
    if ext in {".wav", ".mp3", ".m4a", ".ogg", ".flac"}:
        return "audio"
    if ext in {".jpg", ".jpeg", ".png", ".gif", ".webp"}:
        return "photo"
    if ext in {".pdf"}:
        return "pdf"
    if ext in {".zip", ".tar", ".gz", ".7z"}:
        return "archive"
    if ext in {".md", ".txt"}:
        return "doc"
    if ext in {".json", ".yml", ".yaml", ".sh", ".py", ".js"}:
        return "code"
    if ext in {".csv"}:
        return "data"
    return "media"

def detect_post_kind(text, title):
    """What kind of post: announcement, tutorial, file-share, meeting-record, promo, etc."""
    t = (text or "").lower()
    tl = (title or "").lower()
    if "видеозапись встречи" in t or "аудио запись встречи" in t or "🎥" in (title or "") and "созвон" in t:
        return "meeting_record"
    if "установка" in tl or "install" in tl or "как подключить" in tl or "подключение" in tl:
        return "install_guide"
    if "день х" in tl or "день настал" in tl or "релиз" in tl or "вышел" in tl or "готов" in tl:
        return "release_announcement"
    if "созвон" in tl or "созвон через час" in tl or "видеосозвон" in tl:
        return "meeting_announce"
    if "итоги" in tl or "привет" in tl or "ребят" in tl or "короче" in tl:
        if "установк" not in t and "mcp" not in t:
            return "announce_general"
    if "за кулисами" in tl or "нюансы" in tl or "лайфхаки" in tl:
        return "backstage"
    if "скачай" in tl or "файлы" in tl or "архив" in tl or "📦" in (text or "")[:10]:
        return "file_release"
    if "обновил" in tl or "обновлени" in tl:
        return "update"
    if "навигация" in tl or "оглавлени" in tl:
        return "navigation"
    if len(t) > 500:
        return "tutorial"
    return "post"

def main():
    dump = json.load(open(DUMP, encoding="utf-8"))
    prio_cat = json.load(open(PRIORITY, encoding="utf-8"))
    prio_by_id = {p["msg_id"]: p for p in prio_cat["items"]}

    msgs = dump["messages"]
    msgs_by_id = {m["id"]: m for m in msgs}

    # Pass 1: basic enrichment
    posts = []
    for m in sorted(msgs, key=lambda x: x["id"]):
        mid = m["id"]
        text = m.get("text") or ""
        prio_item = prio_by_id.get(mid, {})

        filename = prio_item.get("filename", "")
        ext = prio_item.get("ext", "")
        size_mb = prio_item.get("size_mb", 0)
        # Skip 171 (0-byte preview, not real media)
        if mid == 171 and size_mb == 0:
            # still index as text-type post, but mark as preview-embed
            filename = ""
            ext = ""

        media_type = detect_media_type(filename, ext)
        own_title = extract_title(text)
        own_topics = extract_topics(text)
        kind = detect_post_kind(text, own_title)

        posts.append({
            "msg_id": mid,
            "date": m.get("date", ""),
            "own_title": own_title,
            "own_topics": own_topics,
            "kind": kind,
            "media_type": media_type,
            "filename": filename,
            "ext": ext,
            "size_mb": size_mb,
            "priority": prio_item.get("category", ""),
            "url": f"{URL_BASE}/{mid}",
            "text_full": text,
        })

    # Pass 2: context inheritance for title-less media posts.
    # Strategy: prefer recent preceding titled post (scroll back up to 10).
    # If that fails, scroll forward (maybe caption is after media burst).
    posts_by_id = {p["msg_id"]: p for p in posts}
    ids_sorted = sorted(posts_by_id.keys())
    for p in posts:
        if p["own_title"] or p["media_type"] == "text":
            continue
        parent_title = None
        parent_topics = []
        parent_msg_id = None
        # Search backwards first (caption usually BEFORE media burst)
        for offset in range(1, 11):
            neighbor = posts_by_id.get(p["msg_id"] - offset)
            if neighbor and neighbor["own_title"] and len(neighbor["own_title"]) > 15:
                parent_title = neighbor["own_title"]
                parent_topics = neighbor["own_topics"]
                parent_msg_id = neighbor["msg_id"]
                break
        # Fallback: forward
        if not parent_title:
            for offset in range(1, 11):
                neighbor = posts_by_id.get(p["msg_id"] + offset)
                if neighbor and neighbor["own_title"] and len(neighbor["own_title"]) > 15:
                    parent_title = neighbor["own_title"]
                    parent_topics = neighbor["own_topics"]
                    parent_msg_id = neighbor["msg_id"]
                    break
        if parent_title:
            p["inherited_title"] = f"(из msg {parent_msg_id}) {parent_title}"
            p["inherited_topics"] = parent_topics
            p["thread_parent"] = parent_msg_id

    # Pass 3: final title/topics (own or inherited) + detect empty/service posts
    for p in posts:
        has_title = bool(p.get("own_title") or p.get("inherited_title"))
        has_content = bool(p["text_full"].strip() or p.get("filename"))
        if not has_content:
            p["title"] = f"[пустой пост msg {p['msg_id']}]"
            p["topics"] = []
            p["kind"] = "empty_or_deleted"
        else:
            p["title"] = p.get("own_title") or p.get("inherited_title") or f"{p['media_type']}_msg_{p['msg_id']}"
            p["topics"] = p.get("own_topics") or p.get("inherited_topics") or []

    # Pass 4: add summary (up to 800 chars of text, preserving full context)
    for p in posts:
        text = p["text_full"]
        p["summary"] = text[:800].strip() if text else ""
        p["has_full_text"] = bool(text) and len(text) > 800

    # Sort: newest first
    posts.sort(key=lambda x: -x["msg_id"])

    # Stats
    empty = sum(1 for p in posts if p["kind"] == "empty_or_deleted")
    issues = sum(1 for p in posts if p["kind"] != "empty_or_deleted" and p["title"].startswith(p["media_type"] + "_msg_"))
    active = len(posts) - empty

    # Output clean JSON
    out = {
        "channel": "Алексей Колесов | Private",
        "channel_id": CHANNEL_ID,
        "url_base": URL_BASE,
        "generated": "2026-04-21",
        "total_posts": len(posts),
        "active_posts": active,
        "empty_or_deleted": empty,
        "remaining_untitled": issues,
        "posts": posts,
    }
    (SCHOOL / "library_index.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"library_index.json: {len(posts)} total ({active} active, {empty} empty), {issues} still untitled")

    # Output rich markdown
    md = [
        "# 📚 Алексей Колесов — Канон-библиотека",
        "",
        f"**Channel ID:** {CHANNEL_ID}",
        f"**URL base:** `{URL_BASE}/<msg_id>`",
        f"**Total posts:** {len(posts)}",
        f"**Последняя сборка:** 2026-04-21",
        "",
        "## Как пользоваться",
        "",
        "- Каждый пост имеет прямую ссылку `https://t.me/c/2653037830/<msg_id>` — открывается только с доступом к приватке",
        "- Поле `priority` (HIGH_CODE / HIGH_SALES / MED / LOW) — важность для канона vibe-кодинга",
        "- `kind` — тип поста: install_guide, tutorial, release_announcement, meeting_record, file_release, backstage, update",
        "- Для media без собственного заголовка → `thread_parent` указывает на соседний пост-контекст",
        "",
    ]

    # Group by topic (most populated first), skip empty posts
    by_topic = defaultdict(list)
    for p in posts:
        if p["kind"] == "empty_or_deleted":
            continue
        for t in p["topics"] or ["(без темы)"]:
            by_topic[t].append(p)

    md.append("## Темы (от наиболее представленных)")
    md.append("")
    for topic in sorted(by_topic.keys(), key=lambda t: (-len(by_topic[t]), t)):
        items = by_topic[topic]
        md.append(f"### {topic} — {len(items)} постов")
        md.append("")
        for p in items[:20]:  # top 20 per topic
            type_emoji = {
                "video": "🎥", "audio": "🎙", "photo": "📸",
                "pdf": "📕", "archive": "📦", "doc": "📝",
                "code": "⚙️", "data": "📊", "text": "💬", "media": "📎",
            }.get(p["media_type"], "•")
            prio = p.get("priority", "")
            prio_badge = f" `{prio}`" if prio.startswith("HIGH") else ""
            kind_badge = f" _{p['kind']}_" if p["kind"] != "post" else ""
            size = f" · {p['size_mb']} МБ" if p.get("size_mb", 0) > 1 else ""
            parent = f" ← [thread parent msg {p['thread_parent']}]" if p.get("thread_parent") else ""
            md.append(f"- {type_emoji} [msg {p['msg_id']}]({p['url']}){prio_badge}{kind_badge} **{p['title']}**{size}{parent}")
        if len(items) > 20:
            md.append(f"- _(и ещё {len(items) - 20} постов по теме {topic})_")
        md.append("")

    # Highlights: most important entry points
    md.append("## 🎯 Точки входа в канон (по приоритету HIGH_CODE)")
    md.append("")
    md.append("Самые важные тьюториалы для изучения:")
    md.append("")
    high_tutorials = sorted(
        [p for p in posts if p.get("priority") == "HIGH_CODE" and p["kind"] in ("install_guide", "tutorial", "release_announcement", "meeting_record")],
        key=lambda x: -x["msg_id"]
    )[:15]
    for p in high_tutorials:
        topics_str = ", ".join(p["topics"][:3]) if p["topics"] else "общее"
        md.append(f"- [msg {p['msg_id']}]({p['url']}) — **{p['title']}** ({topics_str})")
    md.append("")

    (SCHOOL / "library_index.md").write_text("\n".join(md), encoding="utf-8")
    print(f"library_index.md: {len(by_topic)} topics, {len(high_tutorials)} top tutorials")

    # Finally: check for orphan files that shouldn't be referenced
    problems = []
    for p in posts:
        if p["title"].startswith(p["media_type"] + "_msg_"):
            problems.append(f"msg {p['msg_id']}: STILL UNTITLED after neighbor-lookup")

    if problems:
        print("\n⚠ Remaining issues:")
        for prob in problems[:10]:
            print(f"  {prob}")

if __name__ == "__main__":
    main()
