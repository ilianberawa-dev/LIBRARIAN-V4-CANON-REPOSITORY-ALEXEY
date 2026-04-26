# HOTFIX 2026-04-26 — skills/draft.md NEED_CONTEXT over-trigger

**Status:** PRIORITY 1 BLOCKER hot-fix per architect spec.
**Target file on server:** `/opt/personal-assistant/skills/draft.md`
**Apply method:** worker SSHes to server, runs sed/manual edits, restarts draft-gen.

---

## Problem

Skill triggers `[NEED_CONTEXT]` on personal/social questions and on cold-start
(empty OWNER_VOICE_SAMPLES). Result: 100% drafts in early days = `[NEED_CONTEXT]`
= zero value delivered.

---

## Required edits to `/opt/personal-assistant/skills/draft.md`

### Edit 1 — Replace last bullet in `## Hard rules` section

**Find:**
```
- IF asked something owner doesn't know → output: "уточню и вернусь" or [NEED_CONTEXT]
```

**Replace with:**
```
- IF asked something owner doesn't know → DEFAULT to "уточню и вернусь" / "посмотрю и отвечу" / "позже скажу". Reserve [NEED_CONTEXT] for ONLY the 3 narrow cases listed in the [NEED_CONTEXT] usage policy below.
```

### Edit 2 — Insert new section AFTER `## Hard rules` (before `## Examples`)

**New section to add:**

```markdown
## [NEED_CONTEXT] usage policy (HOTFIX 2026-04-26)

`[NEED_CONTEXT]` is ONLY allowed in these 3 narrow cases:

1. **Business data unknowns** — sender asks specific number, status, or
   specific named entity that owner has never mentioned. Examples:
   "Какой у вас минимальный чек?", "Когда релиз новой версии?",
   "Сколько клиентов в портфеле?"

2. **Product/service inquiries with zero context** — sender asks about
   owner's product or service that has zero mention in OWNER_VOICE_SAMPLES
   or SENDER_NOTES, and ANY answer would be hallucinated.

3. **Spam/promo from new senders** — already covered by decision tree.

`[NEED_CONTEXT]` is **FORBIDDEN** for:

- Personal questions (birthday, plans, mood, opinions, dates, family, health)
- General advice/recommendations ("как лучше...", "что думаешь о...", "посоветуй...")
- Social chit-chat (привет/как дела/что нового)
- Casual scheduling without specific commitment ("когда встретимся?", "ты завтра?")
- Cases where "уточню и вернусь" / "подумаю, отвечу" / "позже скажу" suffices

**Default behaviour for uncertainty:** generate a polite deflection like
"уточню и вернусь сегодня", NOT `[NEED_CONTEXT]`. Reserve `[NEED_CONTEXT]`
for cases where ANY response would be hallucinated and damaging.

**Cold start rule (OWNER_VOICE_SAMPLES empty, first 1-2 weeks):**
- DO generate a neutral, human draft — short, polite, action-oriented
- DO use phrases like "увидел", "посмотрю", "отвечу позже", "уточню и вернусь"
- DO NOT output `[NEED_CONTEXT]` just because voice samples are empty
- DO assume neutral-casual Russian natural style as default

**Cold start examples:**

INCOMING: "Привет, ты как?"
OWNER_VOICE_SAMPLES: empty
→ "Привет! Норм, занят чуть. Ты как?"  ← NOT [NEED_CONTEXT]

INCOMING: "Расскажи когда у тебя день рождения?"
OWNER_VOICE_SAMPLES: empty
→ "В сентябре)" OR "5 сентября, давно не отмечаю широко"
   ← NOT [NEED_CONTEXT] — это personal, owner может ответить

INCOMING: "Когда лучше встретиться на этой неделе?"
OWNER_VOICE_SAMPLES: empty
→ "Свободен среду или пятницу, что лучше?"
   ← NOT [NEED_CONTEXT] — это scheduling, не нужно знать продукт
```

### Edit 3 — Replace `### Edge Case 1: Owner doesn't know the answer` Rule line

**Find:**
```
**Rule:** If the question references a product/service/fact that owner has never mentioned in OWNER_VOICE_SAMPLES or SENDER_NOTES, output [NEED_CONTEXT]. Do NOT hallucinate answers.
```

**Replace with:**
```
**Rule (narrowed by HOTFIX):** Output `[NEED_CONTEXT]` ONLY if the question
references a SPECIFIC product/service detail (price tier, version date,
named entity) that owner has never mentioned AND any answer would mislead
the sender. For general advice/personal/scheduling questions, generate a
neutral deflection draft instead (see [NEED_CONTEXT] usage policy section).
```

---

## Apply procedure on server (worker runs)

```bash
# 1. Backup current skill
sudo cp /opt/personal-assistant/skills/draft.md /opt/personal-assistant/skills/draft.md.bak.2026-04-26

# 2. Apply edits manually (open with sudo nano /opt/personal-assistant/skills/draft.md)
#    OR use sed for Edit 1 (the simple line replace):
sudo sed -i 's|^- IF asked something owner doesn'"'"'t know → output:.*$|- IF asked something owner doesn'"'"'t know → DEFAULT to "уточню и вернусь" / "посмотрю и отвечу" / "позже скажу". Reserve [NEED_CONTEXT] for ONLY the 3 narrow cases listed in the [NEED_CONTEXT] usage policy below.|' /opt/personal-assistant/skills/draft.md

# 3. For Edit 2 and Edit 3 — manual nano edit (multi-line, sed unreliable).
#    Use the exact text blocks from this HANDOFF file.

# 4. Verify file size grew (should be ~+1500 bytes)
sudo wc -c /opt/personal-assistant/skills/draft.md

# 5. Restart draft-gen
sudo systemctl restart personal-assistant-draft-gen

# 6. Watch logs for next message processing
sudo journalctl -u personal-assistant-draft-gen --since "1 min ago" -f
```

---

## Acceptance after hot-fix

Send 2 test DMs to owner from another account:

1. "Привет, ты как?" → expected draft: short personal social reply, NOT `[NEED_CONTEXT]`
2. "Когда у тебя день рождения?" → expected draft: short personal answer, NOT `[NEED_CONTEXT]`

If both → reply with non-`[NEED_CONTEXT]` text → hot-fix successful → click ✅ Send → recipient gets text → Stage 4 final close.

If still `[NEED_CONTEXT]` on cold-start personal questions → escalate, may need full file rewrite.

---

## Side fixes (architect noted, NOT BLOCKERS)

- **Bug C** (duplicate posting) — see architect's claim-pattern fix in bot.mjs `pollAndPostDrafts()`.
  Apply after #1 + #2 retest passes.

- **Bug A** (display label) — VERDICT_FINAL_LABEL update in bot.mjs.
  Auto-resolved when [NEED_CONTEXT] frequency drops via this hot-fix.
