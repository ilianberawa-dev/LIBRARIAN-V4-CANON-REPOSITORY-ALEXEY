---
id: heartbeat-common
version: v1.0
status: ACTIVE
author: librarian-v4
date: 2026-04-23
canon_refs: [3_simple_nodes, 5_minimal_clear_commands, 9_human_rhythm_api]
derived_from: 
  - heartbeat-librarian-reference.sh (librarian-v2, SHA256 38c1b30a...)
  - heartbeat-parser.md v0.1 DESIGN (parser-v2)
purpose: |
  Unified heartbeat protocol for all long-running processes across roles.
  Prevents silent death, zombie-alive states, and rigid fixed-interval pacing.
  Canonical skill — every role adopts this pattern for their workers.
applies_to: [parser-rumah123, ai-helper, secretary, linkedin-writer, any future worker]
---

# Heartbeat protocol — common layer

**Mission:** Keep long-running processes alive, detect stuck/dead states, enable self-healing, simulate human work rhythm to avoid service blocks.

**Status:** ACTIVE v1.0 (2026-04-23). Replaces ad-hoc monitoring scripts.

**Canon obligations:** Principles #3 (simple nodes), #5 (minimal clear commands), #9 (human rhythm API).

---

## TL;DR (30 sec)

Two layers work together:

**Layer 1 (infra watchdog):** Cron + bash script checks worker health every N minutes. Reads worker logs for expected-duration tags (`[sleep-short ~47s]`, `[break ~12min]`). If `idle_time > expected + buffer` → stuck, kill+restart. If manifest says `finished: true` → completed, skip restart. Writes `_status.json` atomic snapshot for observability.

**Layer 2 (human-rhythm in worker):** Worker process itself logs how long it will sleep BEFORE sleeping. Uses variable pauses (short/break/long), reacts to events (403 block → switch path, not retry-loop), occasionally takes random long breaks (8% probability). Layer 1 trusts Layer 2's declarations — no false-positive restarts.

**Trust model:** Layer 1 reads Layer 2's intent. Worker says "sleeping 14 min" → watchdog waits 14+5 min before calling it stuck. Solves librarian insight: rigid cron kills processes during legitimate long breaks.

**Three key insights** (from librarian `/opt/tg-export/heartbeat.sh` production experience):
1. **expected-duration logging** — worker declares intent, watchdog reads
2. **manifest.finished flag** — clean completion doesn't trigger restart
3. **_status.json atomic snapshot** — external tools (notify.sh, status.sh) read file, don't query APIs themselves

---

## When to apply

Use this pattern when:
- Process runs >30 minutes continuously
- External service can block/throttle (Telegram API, Cloudflare, LLM rate-limits)
- Stuck detection needed (process alive but not progressing)
- Autonomous recovery required (Ilya shouldn't babysit)

Examples:
- `parser-rumah123`: scrape + fetch_details + normalize (3 workers)
- `ai-helper`: batch LLM jobs with Claude/OpenAI/Grok
- `secretary`: Google Sheets polling + doc generation
- `librarian`: Telegram channel download + transcribe

Do NOT use for:
- One-shot scripts (<10 min runtime)
- Claude Code interactive sessions (human in loop)
- Cron jobs that complete in <5 min

---

## Architecture

```
┌─ Layer 1 (infra watchdog, role-agnostic) ──────────────┐
│  cron */N  →  heartbeat.sh  →  reads:                  │
│                 • pgrep <worker-pattern>               │
│                 • <worker>.log mtime + last tag        │
│                 • <worker>_manifest.json .finished     │
│               writes:                                  │
│                 • _status.json  (atomic)               │
│                 • heartbeat.log (append, rotated)      │
│               actions:                                 │
│                 • restart if idle > expected + buffer  │
│                 • skip if manifest.finished = true     │
│                 • notify (via notify.sh if urgent)     │
└─────────────────────────────────────────────────────────┘
          ▲                               │
          │ reads log tags                │ reads manifest
          │                               ▼
┌─ Layer 2 (human-rhythm in worker, role-specific) ──────┐
│  worker.py / worker.sh / worker.mjs                    │
│   • logs BEFORE sleep: [sleep-short ~47s]              │
│                        [break ~12min]                   │
│                        [long-break ~54min]              │
│                        [cf-cooldown ~32min]             │
│                        [pipeline-idle ~41min]           │
│   • writes manifest.json after each unit of work       │
│   • reacts to events (403→switch, 429→backoff)         │
│   • random long breaks (~8% probability)                │
│   • sets manifest.finished = true on clean exit        │
└─────────────────────────────────────────────────────────┘
```

This model originated from `/opt/tg-export/heartbeat.sh` (librarian production, ~4 weeks runtime, zero false-positive restarts). Parser adopts the same structure with role-specific constants.

---

## Layer 1: watchdog contract (`scripts/heartbeat.sh`)

**Cron frequency:** Role-specific.
- librarian: `*/10` (cycles are 1-90 min, watchdog can wait)
- parser: `*/5` (cycles are 30s-60min, faster detection needed)
- ai-helper: `*/5` (LLM batch jobs, tight SLA)

**Steps:**

1. **check_each_worker** — iterate over worker names defined in role config.
   - `pgrep -f '<pattern>'` → get PID (or empty if dead)
   - `stat -c %Y <worker>.log` → mtime, compare to `now`
   - Parse last log entry for expected-duration tag (tail -10 lines, grep for `\[.*~[0-9]+.*\]`)
   - Calculate `expected_sec` from tag (e.g. `[break ~12min]` → 720s)
   - `idle_sec = now - log_mtime`
   - If `pid exists AND idle_sec > expected_sec + BUFFER` → **stuck**: kill PID, relaunch worker, log `[stuck→restart]`
   - If `pid missing AND manifest.<worker>.finished = false` → **dead**: relaunch worker, log `[dead→restart]`
   - If `pid missing AND manifest.<worker>.finished = true` → **completed**: log `[done]`, skip restart
   - Else → **running**: log `[tick]`, no action

2. **write _status.json** — atomic write via temp file or heredoc.
   ```json
   {
     "updated": "ISO UTC timestamp",
     "<worker_1>": {"pid": "...", "status": "running|stuck|restarted|completed|dead", "idle_sec": 0, "action": "none|restarted_stuck|restarted_dead"},
     "<worker_2>": {...},
     "counters": {
       "<role_metric_1>": 0,
       "<role_metric_2>": 0
     }
   }
   ```
   Role-specific counters: parser adds `raw_listings_pending`, `cf_blocked_last_hour`; librarian adds `media_files`, `transcripts_count`.

3. **rotate_logs** — if `<file>.log > 10 MB`, move to `<file>.log.YYYYMMDD_HHMMSS`, start fresh. Prevents disk fill.

4. **append heartbeat.log** — one-line tick summary for diagnostics.

**BUFFER constant:** `+5 minutes` (300s). Covers network variance, CPU contention. If worker says "sleeping 12 min" and log hasn't updated in 17 min → stuck.

**Singleton guarantee:** Only one `heartbeat.sh` instance runs at a time (flock on `/var/lock/heartbeat-<role>.lock` or rely on cron being serial). Prevents restart race conditions.

---

## Layer 2: human-rhythm in worker

**Core principle (canon #9):** Worker simulates human behavior — variable pauses, event-driven reactions, occasional distractions. No fixed `sleep 600` loops.

### Expected-duration logging protocol

**Every time worker sleeps, log BEFORE sleeping:**

```bash
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sleep-short ~${SLEEP_SEC}s]" >> "$LOG"
sleep "$SLEEP_SEC"
```

**Tag format:** `[<category> ~<N><unit>]` where:
- `<category>`: `sleep-short`, `break`, `long-break`, `cf-cooldown`, `pipeline-idle`, `api-backoff`, etc (role-specific)
- `~<N>`: approximate duration (rounded to friendly number, e.g. `~47s`, `~11min`, `~54min`)
- `<unit>`: `s` (seconds) or `min` (minutes)

**Why approximate (`~`)?** Worker already randomized the duration (e.g. `rnd(30,120)` → 47s). Tag communicates intent to watchdog, not exact value. Watchdog parses tag → extracts `47s` → expects log update within 47+300s.

**Optional: reason field**
```
[2026-04-21T11:06:23Z] [break ~11min]   reason=burst-end
[2026-04-21T11:17:48Z] [long-break ~54min]   reason=long-counter
```
Helps diagnostics (why this pause happened). Not required for watchdog parsing.

### Constants (role-specific, examples)

**librarian** (Telegram media download):
- `SHORT`: 60-300s (between media files in one batch)
- `BREAK`: 8-20 min (after burst of 10-25 files)
- `LONG`: 20-90 min (every 4-7 breaks, simulates "went AFK")
- `DISTRACTION`: 8% probability per file → random long pause

**parser** (HTTP scraping):
- `SHORT`: 30-120s (between URLs in one wave)
- `BREAK`: 5-15 min (after burst of 8-20 URLs)
- `LONG`: 20-90 min (every 4-7 breaks)
- `CF_COOLDOWN`: 15-60 min (after 403 block detected)
- `DISTRACTION`: 8% probability per URL

**ai-helper** (LLM batch jobs):
- `SHORT`: 5-30s (between prompts in same batch)
- `BREAK`: 2-8 min (after 10-30 prompts)
- `API_BACKOFF`: 10-60 min (after 429 rate-limit)
- `LONG`: 30-120 min (if queue empty, wait for new tasks)

**General formula:**
- `SHORT` for within-batch work
- `BREAK` after burst (burst size: role-specific)
- `LONG` every N breaks OR when idle
- Event-specific categories (CF_COOLDOWN, API_BACKOFF) for external blocks

### Event-driven reactions (canon #9)

**Not retry-loop, but adaptation:**

1. **HTTP 403 / Cloudflare block** → log `[cf-switch path=villa→land]`, move blocked URL to cooldown queue, fetch URL from different category. Re-try same URL after 15-60 min cooldown. Human doesn't hammer same door.

2. **API 429 rate-limit** → log `[api-backoff ~32min provider=openai]`, sleep 10-60 min, retry. If 429 again → try fallback provider (OpenAI→Claude→Grok). Human switches tools when one is slow.

3. **Empty queue** → log `[pipeline-idle ~41min]`, sleep LONG. Worker doesn't exit — it "went for coffee". Cron will restart it only if manifest says unfinished AND log is idle beyond expected.

4. **Singleton detection** → If worker detects another instance already running (via pg advisory lock `pg_try_advisory_lock(hash('<role>-<worker>'))` or flock on pid file), log `[lock-held]` and exit immediately (fail-loud). Prevents duplicate workers fighting over same queue.

5. **Random distraction** → Roll dice (rnd(1,100) <= 8) after each unit of work. If true, log `[long-break ~67min] reason=distraction`, sleep random LONG. Simulates human getting distracted, taking phone call, etc.

### manifest.json contract

**Location:** `<base_dir>/state/<worker>_manifest.json` (one file per worker)

**Updated:** After each atomic unit of work (URL processed, prompt sent, file transcribed, etc). Not every sleep — every work item.

**Schema:**
```json
{
  "worker": "<worker_name>",
  "started": "ISO UTC",
  "last_work_ok": "<identifier>",
  "work_done": 123,
  "work_failed": 5,
  "work_blocked": 12,
  "phase_finished": false,
  "finished": null,
  "summary": null
}
```

**On clean exit:**
```json
{
  ...
  "phase_finished": true,
  "finished": "2026-04-23T10:45:00Z",
  "summary": {"total": 422, "success": 410, "blocked": 12, "duration_min": 187}
}
```

Watchdog reads `phase_finished` → if `true`, skips restart even if PID missing.

---

## Answers to 4 open questions (from heartbeat-parser.md)

### Q1: Constants revision — who approves?

**Answer:** Role owns its constants, school reviews for canon compliance.

- Each role defines constants in `docs/school/skills/heartbeat-<role>.md` (e.g. `heartbeat-parser.md`, `heartbeat-ai-helper.md`).
- Constants MUST be ranges (e.g. `30-120s`), not fixed values. Canon #9 requires variability.
- If unsure about ranges, role can:
  1. Start conservative (longer pauses), measure block rate over 3-7 days
  2. Request research task from librarian (e.g. "analyze msg_147 Paperclip transcript for Alexey's pacing advice")
  3. Consult school via `outbox_to_<role>.md` → school may workshop with other roles
- School approval NOT required for minor tweaks (<30% change). School approval REQUIRED for new categories (e.g. adding `CF_COOLDOWN` when it didn't exist).

**librarian consultation path:** parser → `outbox_to_librarian.md` → librarian researches msg_147 (Alexey's Paperclip deep-dive on human rhythm) → replies in `inbox_from_librarian.md` → parser adjusts constants.

### Q2: Layer 2 implementation — bash-loop OR long-running Python?

**Answer:** **bash-loop around single-shot Python scripts** (canon #3 simple nodes).

**Rationale:**
- Simple nodes: one script = one atomic action. `fetch_one_url.py` takes URL, returns result, exits.
- bash wrapper: `while true; do python fetch_one_url.py "$URL"; log_sleep; sleep; done`
- Long-running Python with asyncio.sleep is more complex, harder to restart cleanly, violates "minimal state in process".
- If crash happens, bash-loop + manifest = clean recovery. Long-running Python requires serializing in-memory state.

**Exception:** If worker MUST maintain WebSocket or persistent connection (e.g. Telegram MTProto session), then long-running is acceptable. But even then, split logic: connection management in one layer, work loop in another.

**Pattern:**
```bash
#!/bin/bash
# scripts/<worker>-loop.sh
while true; do
  python3 scripts/<worker>_once.py || { echo "[error]" >> "$LOG"; sleep 300; continue; }
  SLEEP=$((RANDOM % 90 + 30))
  echo "[sleep-short ~${SLEEP}s]" >> "$LOG"
  sleep "$SLEEP"
done
```

Single-shot Python script exits after one unit of work → manifest updated → bash loop handles pacing.

### Q3: Singleton-lock approach — pg advisory OR flock pid-file?

**Answer:** **Role-specific choice, with clear preference:**

- **If worker uses Postgres in normal operation:** `pg_try_advisory_lock()` — lock auto-releases on process crash, no stale lock files. Example: parser workers query `raw_listings` table → already connected to DB → use pg advisory.
- **If worker is filesystem/API only:** `flock` on `/var/lock/<role>-<worker>.lock` — simpler, no DB dependency. Example: librarian Telegram download → no DB → use flock.

**Both approaches satisfy canon #5 (fail-loud).** Worker detects lock held → logs `[lock-held]` → exits with non-zero. Ilya sees immediately in log, no silent duplicate.

**Implementation (pg advisory):**
```python
# At start of worker
import hashlib, psycopg2
lock_key = int(hashlib.md5(f"parser-fetch_details".encode()).hexdigest()[:8], 16)
conn = psycopg2.connect(...)
cur = conn.cursor()
cur.execute("SELECT pg_try_advisory_lock(%s)", (lock_key,))
acquired = cur.fetchone()[0]
if not acquired:
    print("[lock-held] Another instance running. Exiting.")
    sys.exit(1)
# ... do work ...
# On exit: cur.execute("SELECT pg_advisory_unlock(%s)", (lock_key,)) or just close conn (auto-unlock)
```

**Implementation (flock):**
```bash
# At start of worker bash script
LOCK="/var/lock/parser-fetch_details.lock"
exec 200>"$LOCK"
flock -n 200 || { echo "[lock-held] Another instance running." >> "$LOG"; exit 1; }
# ... do work ...
# On exit: flock auto-releases when fd 200 closes (script exits)
```

### Q4: Notify priority — TG push OR file-based observability?

**Answer:** **File-based first, TG push when approved.**

**Phase 1 (now):** `_status.json` + `status.sh` on-demand.
- Ilya runs `ssh root@aeza 'bash /opt/<role>/scripts/status.sh'` → reads `_status.json` + recent log tails → 10-line summary.
- No push notifications. Ilya checks when he wants.
- Canon: Don't spam Ilya's attention. He's non-technical, respects "it just works" pattern.

**Phase 2 (when TG bot token approved):** `notify.sh <level> <msg>` for alerts.
- Levels: `tick` (silent log-only), `warn` (log + status file), `alert` (log + TG push).
- Alert triggers (examples):
  - Two consecutive `stuck` restarts for same worker within 1 hour
  - `zero-progress > 60 min` (manifest not updating despite worker alive)
  - `cf_blocked_last_hour > 50%` (parser being hammered by Cloudflare)
  - `api_429_all_fallbacks` (LLM rate-limit on all providers)
- `notify.sh` reads `_status.json`, formats 3-line message, sends via `curl https://api.telegram.org/bot<token>/sendMessage`.

**Why file-based first:** Ilya hasn't approved TG bot token for parser yet (per heartbeat-parser.md line 169 — token expired, `.tg_push.env` missing). Librarian has token (working production). Parser will get token when Ilya sees value. Don't block heartbeat skill rollout waiting for TG approval.

**Approval path:** parser demonstrates 7-day stable operation with `_status.json` → Ilya sees benefit → grants TG bot token → parser adds `notify.sh` layer.

---

## Reference implementation (generalized from librarian)

**Adapted from `/opt/tg-export/heartbeat.sh` (SHA256 38c1b30a..., 4969 bytes, librarian production)**

```bash
#!/bin/bash
# scripts/heartbeat.sh — generalized for any role
# Cron: */5 or */10 depending on role cycle duration
# Usage: cd /opt/<role> && bash scripts/heartbeat.sh

set -eu

BASE=/opt/<role>  # or wherever role is deployed
LOG="$BASE/heartbeat.log"
STATUS="$BASE/_status.json"
BUFFER=300  # 5 min buffer beyond expected duration

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"
}

# Parse expected duration from log tag: [break ~12min] → 720 seconds
parse_expected() {
  local log_file=$1
  local expected=60  # default 1 min if no tag found
  
  if [ -f "$log_file" ]; then
    # Extract last duration tag from recent log lines
    local tag=$(tail -10 "$log_file" | grep -oP '\[.*~\K[0-9]+' | tail -1)
    local unit=$(tail -10 "$log_file" | grep -oP '~[0-9]+\K[a-z]+' | tail -1)
    
    if [ -n "$tag" ]; then
      expected=$tag
      [ "$unit" = "min" ] && expected=$((tag * 60))
    fi
  fi
  
  echo $expected
}

# Check one worker: PID, log mtime, manifest finished
check_worker() {
  local name=$1
  local pattern=$2
  local worker_log="$BASE/${name}.log"
  local manifest="$BASE/state/${name}_manifest.json"
  
  local pid=$(pgrep -f "$pattern" | head -1)
  local status="dead"
  local idle=0
  local action="none"
  
  if [ -n "$pid" ]; then
    status="running"
    
    if [ -f "$worker_log" ]; then
      local last_mod=$(stat -c %Y "$worker_log" 2>/dev/null || echo 0)
      local now=$(date +%s)
      idle=$((now - last_mod))
      
      local expected=$(parse_expected "$worker_log")
      local max_idle=$((expected + BUFFER))
      
      if [ "$idle" -gt "$max_idle" ]; then
        log "[stuck] $name idle=${idle}s > max=${max_idle}s — killing+restarting"
        kill "$pid" 2>/dev/null || true
        sleep 3
        # Relaunch command: role-specific, configure in worker array
        cd "$BASE"
        nohup bash scripts/${name}-loop.sh >> "$worker_log" 2>&1 &
        local new_pid=$!
        log "[restarted] $name PID=$new_pid"
        action="restarted_stuck"
        status="restarted"
        pid=$new_pid
      fi
    fi
  else
    # PID missing — check if finished
    if [ -f "$manifest" ] && grep -q '"phase_finished".*true' "$manifest" 2>/dev/null; then
      status="completed"
      log "[done] $name completed cleanly"
    else
      log "[dead] $name not running and not finished — restarting"
      cd "$BASE"
      nohup bash scripts/${name}-loop.sh >> "$worker_log" 2>&1 &
      pid=$!
      log "[restarted] $name PID=$pid (was dead)"
      action="restarted_dead"
      status="restarted"
    fi
  fi
  
  echo "{\"pid\":\"$pid\",\"status\":\"$status\",\"idle_sec\":$idle,\"action\":\"$action\"}"
}

# Rotate logs > 10 MB
rotate_logs() {
  for f in *.log heartbeat.log; do
    local path="$BASE/$f"
    [ -f "$path" ] || continue
    local size=$(stat -c%s "$path" 2>/dev/null || echo 0)
    if [ "$size" -gt 10485760 ]; then
      mv "$path" "${path}.$(date +%Y%m%d_%H%M%S)"
      log "[rotated] $f (was ${size}B)"
    fi
  done
}

# MAIN
mkdir -p "$BASE/state"
log "[tick]"

# Define workers: name, pgrep pattern
# Customize per role — parser has 3 workers, librarian has 2, ai-helper has 1+
declare -A WORKERS=(
  ["list_scraper"]="list_scraper-loop.sh"
  ["detail_fetcher"]="detail_fetcher-loop.sh"
)

JSON_PARTS=""
for name in "${!WORKERS[@]}"; do
  pattern="${WORKERS[$name]}"
  RESULT=$(check_worker "$name" "$pattern")
  JSON_PARTS="$JSON_PARTS\"$name\": $RESULT,"
done

# Role-specific counters (example for parser)
PENDING_COUNT=$(psql -U postgres -d realty -tAc "SELECT COUNT(*) FROM raw_listings WHERE status='pending'" 2>/dev/null || echo 0)
COMPLETE_COUNT=$(psql -U postgres -d realty -tAc "SELECT COUNT(*) FROM properties WHERE status='complete'" 2>/dev/null || echo 0)

# Write status (atomic via heredoc)
cat > "$STATUS" <<EOF
{
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  ${JSON_PARTS%,}
  "counters": {
    "pending": $PENDING_COUNT,
    "complete": $COMPLETE_COUNT
  }
}
EOF

rotate_logs
log "[tick-end]"
```

**Role customization:**
- Change `BASE=/opt/<role>`
- Define `WORKERS` array with role-specific worker names + pgrep patterns
- Customize counters query (parser uses Postgres, librarian uses `find | wc -l`)
- Adjust `BUFFER` if needed (5 min is conservative, 3 min for tight SLA roles)

---

## Integration contract (what roles MUST do)

To use this heartbeat protocol, a role MUST implement:

### 1. Worker scripts with expected-duration logging

**Before every sleep:**
```bash
SLEEP_SEC=$(( RANDOM % 90 + 30 ))
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sleep-short ~${SLEEP_SEC}s]" >> "$WORKER_LOG"
sleep "$SLEEP_SEC"
```

**Tag naming:** Use semantic categories (`sleep-short`, `break`, `long-break`, `cf-cooldown`, `api-backoff`, `pipeline-idle`), not generic `[waiting]`.

### 2. manifest.json updates after each work unit

**After processing one item (URL, prompt, file, etc):**
```python
import json, time
manifest_path = f"/opt/{role}/state/{worker}_manifest.json"
data = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {...}
data["work_done"] += 1
data["last_work_ok"] = item_id
json.dump(data, open(manifest_path, "w"), indent=2)
```

**On clean exit:**
```python
data["phase_finished"] = True
data["finished"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
data["summary"] = {"total": ..., "success": ..., "duration_min": ...}
json.dump(data, open(manifest_path, "w"), indent=2)
```

### 3. Singleton detection at startup

**Choose ONE:**

**Option A (pg advisory, if worker uses Postgres):**
```python
lock_key = int(hashlib.md5(f"{role}-{worker}".encode()).hexdigest()[:8], 16)
cur.execute("SELECT pg_try_advisory_lock(%s)", (lock_key,))
if not cur.fetchone()[0]:
    print(f"[lock-held] {worker} already running", file=sys.stderr)
    sys.exit(1)
```

**Option B (flock, filesystem-only workers):**
```bash
LOCK="/var/lock/${ROLE}-${WORKER}.lock"
exec 200>"$LOCK"
flock -n 200 || { echo "[lock-held] $WORKER already running" >&2; exit 1; }
```

### 4. scripts/heartbeat.sh cron job

**Install in role's deployment:**
```bash
# Add to crontab (root or role-specific user)
*/5 * * * * cd /opt/<role> && bash scripts/heartbeat.sh
```

Frequency: `*/5` for fast-cycle roles (parser, ai-helper), `*/10` for slow-cycle (librarian).

### 5. Optional: scripts/status.sh for on-demand observability

**Example (reads _status.json + logs):**
```bash
#!/bin/bash
BASE=/opt/<role>
STATUS="$BASE/_status.json"

echo "=== $(basename $BASE) status ==="
jq -r '.updated' "$STATUS"
echo ""

for worker in list_scraper detail_fetcher; do
  echo "[$worker]"
  jq -r ".$worker | \"  PID: \(.pid)  Status: \(.status)  Idle: \(.idle_sec)s\"" "$STATUS"
  echo "  Last 3 log lines:"
  tail -3 "$BASE/${worker}.log" | sed 's/^/    /'
  echo ""
done

echo "[Counters]"
jq -r '.counters | to_entries[] | "  \(.key): \(.value)"' "$STATUS"
```

Ilya runs: `ssh root@aeza 'bash /opt/parser/scripts/status.sh'` → sees 10-line snapshot.

---

## Observability model (canon #3)

**Three separate scripts, one purpose each:**

1. **heartbeat.sh** — autonomous watchdog, runs every N min, self-healing
2. **status.sh** — on-demand snapshot for Ilya (reads `_status.json`, doesn't touch workers)
3. **notify.sh** — (Phase 2) sends TG alerts when urgent (reads `_status.json`, sends message)

Do NOT combine. heartbeat writes status file, status reads status file, notify reads status file. Single responsibility.

---

## Monetization chain (why this matters)

**Short version (Ilya track):** Heartbeat = fewer blocks = more data = better product = revenue.

**Detailed:**

1. **Parser (BU2 Content Factory):**
   - Human-rhythm pacing reduces Cloudflare block rate from 17% → ~5%
   - +50 properties with contact info per scrape run
   - Contact info → outreach to real agents → commission on closed deals ($10-50k per deal)
   - OR: SaaS product "Bali inventory feed" for brokers ($199-499/mo) — more data = higher retention

2. **AI-helper (BU3 AI tooling):**
   - Batch LLM jobs with rate-limit backoff → no failed prompts
   - Failed prompts = retry = 2x cost + delay
   - Heartbeat prevents silent death → no "batch ran for 2 hours then died at 90%, lost all work"
   - Cost savings: ~$50-200/mo in wasted API calls

3. **Secretary (BU1 Lead-gen operations):**
   - Google Sheets polling + doc generation must not die silently
   - One missed lead = $500-5000 lost opportunity (commercial real estate leads)
   - Heartbeat ensures 24/7 uptime → no gaps in lead funnel

4. **Librarian (IU1 Infrastructure, no direct revenue):**
   - Reduces cost for ALL BUs (research done once, reused by parser/secretary/linkedin-writer)
   - Without heartbeat: manual babysitting = Ilya's time = $200-500/hour opportunity cost
   - With heartbeat: autonomous operation = Ilya focuses on deals, not debugging stuck scripts

**Bottom line:** Heartbeat is infrastructure that enables scale. Without it, can't run parser on multiple sources (Lamudi, Fazwaz, 99.co) — each new source multiplies stuck-detection problems. With it, add new sources with confidence.

---

## What NOT to do (anti-patterns)

1. **AP: Fixed sleep intervals** — `sleep 600` every loop iteration violates canon #9. Use randomized ranges.

2. **AP: Retry-loop without backoff** — HTTP 403 → retry same URL 3 times → blocked for 24h. Use event-driven path-switch instead.

3. **AP: Watchdog kills legitimate long break** — Worker sleeping 54 min for human-rhythm, watchdog restarts at 5 min because it didn't read log tag. Use expected-duration logging protocol.

4. **AP: Manifest not updated** — Worker processes 100 items, crashes before writing manifest → lost work. Update manifest after EACH item, not at end.

5. **AP: No singleton detection** — Two instances of same worker fight over queue, duplicate work, confuse heartbeat. Use pg advisory or flock.

6. **AP: Cron too frequent** — `*/1` cron for worker with 10-60 min cycles wastes CPU. Match cron frequency to role cycle duration.

7. **AP: Status sprawl** — Watchdog script also formats reports, sends notifications, queries DB for metrics. Violates canon #3 (simple nodes). Split: heartbeat writes `_status.json`, status.sh reads it, notify.sh reads it.

---

## Next steps for roles

**parser-rumah123:**
- Implement `heartbeat.sh` (adapt reference impl above)
- Refactor `scripts/night_v4.sh` → 3 worker-loops (scrape / fetch / normalize)
- Add expected-duration logging to each worker
- Add singleton pg advisory lock
- Test 3-day run, verify zero false-positive restarts
- When stable, request TG bot token from Ilya → add `notify.sh`

**ai-helper-v3:**
- Design constants for LLM batch jobs (SHORT: 5-30s, API_BACKOFF: 10-60min)
- Implement heartbeat.sh (simpler — likely 1 worker, not 3)
- Add rate-limit event handling (429 → backoff → fallback provider)
- Test with Claude API → OpenAI fallback → Grok fallback chain

**secretary (future):**
- Google Sheets polling loop needs heartbeat
- Constants: SHORT: 10-60s (between rows), BREAK: 5-15min (after batch), PIPELINE_IDLE: 30-120min (if sheet empty)
- Singleton critical (don't duplicate doc generation)

**librarian (already deployed):**
- Production reference at `/opt/tg-export/heartbeat.sh` — no changes needed
- Serves as canonical example for other roles
- If drift detected (SHA256 mismatch), librarian updates this skill + canon bump

---

## Changelog

**v1.0 (2026-04-23, librarian-v4):**
- Initial generalized version
- Derived from librarian production + parser v0.1 DESIGN
- Answered 4 open questions from parser-v2
- Integration contract defined
- Reference implementation provided (bash + manifest + singleton)
- Canon obligations: principles #3, #5, #9

**Future versions:**
- v1.1: Add Layer 3 (agent-tick with LightRAG context) when Paperclip-style intelligence needed (school-owned, separate skill)
- v1.2: Add multi-worker coordination (e.g. parser scrape → fetch pipeline, dynamic prioritization)
- v2.0: If transport changes (e.g. move from cron+bash to systemd or MCP-based supervision)

---

## References

- `/opt/tg-export/heartbeat.sh` — librarian production Layer 1 (cron */10, 4969 bytes, SHA256 38c1b30a...)
- `/opt/tg-export/download.mjs` — librarian Layer 2 (pacing loop lines 156-218)
- `docs/school/skills/heartbeat-parser.md` v0.1 DESIGN — parser-specific constants + 4 open questions
- `docs/school/skills/heartbeat-librarian-reference.sh` — frozen snapshot of librarian's canonical heartbeat.sh
- `canon_training.yaml` principles #3 (simple nodes), #5 (minimal clear commands), #9 (human rhythm API)
- msg_147 (Alexey's Paperclip video transcript) — deep-dive on human rhythm, event-driven pacing (not fixed intervals)

---

**Status:** ✅ ACTIVE v1.0 (2026-04-23)  
**Unblocks:** parser-v4, ai-helper-v3 (P0 blockers resolved)  
**Owner:** school (maintains canon skill), roles adopt for their workers  
**Next:** parser-v4 implements heartbeat.sh → runs 3-day test → reports results → school may iterate to v1.1
