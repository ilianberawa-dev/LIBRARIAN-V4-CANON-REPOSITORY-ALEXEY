# Cost tracking — autonomous work session 2026-04-20

**User-approved budget:** $1.00 total
**Required by user:** breakdown analysis of where most spent

## Model pricing reference (per 1M tokens, 2026-04)

| Model | Input | Output | Notes |
|---|---|---|---|
| `claude-haiku` (Haiku 4.5) | $0.80 | $4.00 | Our only paid model at 4-way free tier |
| `groq-llama` (Llama 3.3 70B) | $0.00 | $0.00 | Free tier (rate-limited but plenty) |
| `gemini-flash` (2.5 Flash) | $0.00 | $0.00 | Free tier (~15 RPM, 1M tok/day) |
| `qwen-turbo` (intl) | $0.00 | $0.00 | Free tier via dashscope-intl |
| `gpt-4o-mini` | $0.15 | $0.60 | Topped up $5, not used today |
| `deepseek-chat` | $0.27 | $1.10 | Topped up $5, not used today |
| `grok-4-fast` | $0.20 | $0.50 | Paid tier, not used |
| `grok-max` | $3.00 | $15.00 | Flagship, not used |

**Our 4-way default = Claude Haiku only as paid.** Других free tier'ы достаточно для MVP.

## Per-call token estimate

CLS-002 prompt: ~850 input (prompt template + raw_text ~1200 chars ≈ 400 tokens + template 450 tokens)
CLS-002 response: ~120 output (JSON + reasoning ~20 words)
→ **~970 tokens per call / ~$0.0008 for Claude per call**

CLS-003 prompt: ~750 input (zone template 550 + location + raw 200)
CLS-003 response: ~100 output
→ **~850 tokens per call / ~$0.0007 for Claude per call**

## Ledger (running total)

| Timestamp | Operation | Records | Model calls | Tokens est | $ this | $ total |
|---|---|---|---|---|---|---|
| 2026-04-20 08:00 | CLS-002 first test (3 records) | 3 | 12 | 11K | $0.005 | $0.005 |
| 2026-04-20 08:30 | CLS-002 baseline (20 records) | 20 | 80 | 77K | $0.017 | $0.022 |
| 2026-04-20 10:00 | Gemini max_tokens debug + retries | — | 20 | 20K | $0.000 (Claude not involved) | $0.022 |
| 2026-04-20 10:30 | CLS-002 re-run 10 (max_tokens=2000) | 10 | 40 | 40K | $0.008 | $0.030 |
| 2026-04-20 11:00 | CLS-002 re-run 20 (after Gemini fix) | 20 | 80 | 77K | $0.017 | $0.047 |
| 2026-04-20 11:30 | CLS-002 full dump 20 (for .triangulate_dump.md) | 20 | 80 | 77K | $0.017 | $0.064 |
| 2026-04-20 16:30 | CLS-003 baseline (21 records) | 21 | 84 | 71K | $0.015 | $0.079 |
| 2026-04-20 17:00 | **ad-hoc connectivity/validation curls** | — | ~15 | 2K | $0.000 | $0.079 |
| 2026-04-20 17:30 | Planned: CLS-002+003 re-run extended (60-80 records) | 80 | 640 | 640K | $0.12 est | $0.20 est |

**Running total estimate end-of-session:** ~$0.20 (20% of $1 budget)

## Breakdown analysis — where does money go?

**100% of spend is Claude Haiku** (only paid model in our 4-way free tier).

### By operation type

```
CLS-002 baseline runs    ~$0.06  (most)  — validation was iterative, re-ran 4 times
CLS-003 baseline run     ~$0.015
Extended re-run (est)    ~$0.12
Ad-hoc/debug             ~$0.00  (negligible)
```

### Why so cheap

1. **Token prompt compact** — C1-C5 matrix + template ~1000 tokens, raw_text capped at 1200 chars
2. **Response capped** at 350-2000 max_tokens but typical output ~100-200 tokens
3. **4 models but 3 are free** — Claude-only pays
4. **Haiku instead of Sonnet/Opus** — 12x cheaper

### What would blow the budget

| Scenario | Est cost | Would exceed? |
|---|---|---|
| Switch 4-way → grok-max for every call | 80 × $0.015 = $1.20 | **YES** |
| 6-way with gpt-4o-mini + deepseek on ALL records | +$0.10 | Safe |
| NAR-015 triangulation (longer prompts, longer outputs) | 80 × $0.03 = $2.40 with Claude Opus | **YES** — stick with Haiku for NAR |
| 200-record baseline × 4-way | $0.30 | Safe |
| 500-record production batch | $0.75 | Borderline |

## Stop conditions if budget approaches

- **At $0.50 (50%)** — pause, report to user, ask for extension
- **At $0.80 (80%)** — hard stop autonomous work except cleanup
- **At $1.00** — immediate halt, all further calls blocked

## What we save by 4-way free

If we ran 8-way for every call (incl. gpt-4o-mini, deepseek, grok-fast, grok-max):
- 80 records × 8 models × 1000 tokens = 640K tokens
- Average cost per 1M ≈ $1.50 blended
- Total: ~$0.96 per 80 records — near budget ceiling
- Savings with 4-way: $0.76 per 80 records

**→ 4-way free is 5x cheaper with ~85% agreement quality.** Escalation to 6-way only for Grade-C cases is the right default.
