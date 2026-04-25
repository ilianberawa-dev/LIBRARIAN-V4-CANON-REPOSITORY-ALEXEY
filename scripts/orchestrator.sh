#!/usr/bin/env bash
# orchestrator.sh — multi-source Phase-1 pilot.
# Canon: #9 human-rhythm (random pauses, event-driven switches), #3 simple-nodes
#        (each stage one tool: scrape list → fetch details → normalize → report).
#
# Usage:
#   ./scripts/orchestrator.sh pilot         # default: Lamudi × 2 slugs + fetch + normalize
#   MIN_GAP=900 MAX_GAP=2700 ./scripts/orchestrator.sh pilot   # full human-rhythm gaps (15-45 min)
#
# Reads env from /opt/realty-portal/.env via run_with_env.sh wrapper.

set -euo pipefail

BASE=${REALTY_BASE:-/opt/realty-portal}
WRAP=${WRAP:-$BASE/scripts/run_with_env.sh}
LOG=/tmp/orchestrator_$(date +%Y%m%d-%H%M%S).log
STATUS=/tmp/orchestrator_status.json

# Human-rhythm gaps BETWEEN stages (in seconds). Default = pilot (5-15 min).
# For full-sweep re-run with MIN_GAP=900 MAX_GAP=2700 (15-45 min).
MIN_GAP=${MIN_GAP:-300}
MAX_GAP=${MAX_GAP:-900}

rand() {
  local lo=$1 hi=$2
  python3 -c "import random; print(random.randint($lo,$hi))"
}

log() {
  echo "[$(date -u +%H:%M:%SZ)] $*" | tee -a "$LOG"
}

write_status() {
  cat > "$STATUS" <<EOF
{"stage":"$1","updated":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","log":"$LOG","pause_sec":${2:-0}}
EOF
}

pause_random() {
  local p
  p=$(rand "$MIN_GAP" "$MAX_GAP")
  log "  [rhythm] pause ${p}s (~$((p/60))min)"
  write_status "paused" "$p"
  sleep "$p"
}

log "=== orchestrator start (MIN_GAP=$MIN_GAP MAX_GAP=$MAX_GAP) ==="

# -----------------------------------------------------------------------------
# STAGE 1 — Lamudi list-scrape (2 random slugs, 1-2 pages each)
# -----------------------------------------------------------------------------
log "[stage 1] Lamudi list-scrape (2 random slugs)"
write_status "lamudi_list"

# randomize + take first 2 slugs (scraper itself shuffles internally, but we further limit)
SLUGS=(canggu-1 pererenan seminyak kerobokan kerobokan-kelod)
# simple shuffle using shuf if available
if command -v shuf >/dev/null; then
  SHUFFLED=( $(printf '%s\n' "${SLUGS[@]}" | shuf | head -2) )
else
  SHUFFLED=("${SLUGS[@]:0:2}")
fi
log "  [selected slugs] ${SHUFFLED[*]}"

"$WRAP" python3 "$BASE/scrapers/lamudi/run.py" \
  --slugs "${SHUFFLED[@]}" \
  --max-pages 2 \
  --min-pause 30 --max-pause 80 \
  --limit-new 60 \
  2>&1 | tee -a "$LOG"

NEW_LAMUDI=$(docker exec supabase-db psql -U postgres -d postgres -tAc \
  "SELECT COUNT(*) FROM public.raw_listings WHERE source_name='lamudi_bali' AND detail_fetched_at IS NULL")
log "  [stage 1 done] lamudi pending: $NEW_LAMUDI"

pause_random

# -----------------------------------------------------------------------------
# STAGE 2 — fetch_details for Lamudi (20 items)
# -----------------------------------------------------------------------------
log "[stage 2] fetch_details for Lamudi"
write_status "lamudi_fetch"

"$WRAP" python3 "$BASE/scrapers/rumah123/fetch_details.py" \
  --source-name lamudi_bali \
  --limit 20 \
  --rate-limit 30 \
  2>&1 | tee -a "$LOG"

pause_random

# -----------------------------------------------------------------------------
# STAGE 3 — Rumah123 list-scrape (one path we haven't hammered recently)
# -----------------------------------------------------------------------------
# Rumah123 URL-based bedroom filter doesn't work (probe returned 404).
# We scrape /jual/bali/rumah/ (generic) — new listings appear daily.
log "[stage 3] Rumah123 list-scrape (generic /jual/bali/rumah/ page 2-3 for freshness)"
write_status "rumah123_list"

"$WRAP" python3 "$BASE/scrapers/rumah123/run.py" \
  --list-path /jual/bali/rumah/ \
  --max-pages 2 \
  --rate-limit 10 \
  2>&1 | tee -a "$LOG"

NEW_R123=$(docker exec supabase-db psql -U postgres -d postgres -tAc \
  "SELECT COUNT(*) FROM public.raw_listings WHERE source_name='rumah123_bali' AND detail_fetched_at IS NULL")
log "  [stage 3 done] rumah123 pending: $NEW_R123"

pause_random

# -----------------------------------------------------------------------------
# STAGE 4 — fetch_details for Rumah123 (only if pending > 0)
# -----------------------------------------------------------------------------
if [ "$NEW_R123" -gt 0 ]; then
  log "[stage 4] fetch_details for Rumah123 ($NEW_R123 pending)"
  write_status "rumah123_fetch"
  "$WRAP" python3 "$BASE/scrapers/rumah123/fetch_details.py" \
    --source-name rumah123_bali \
    --limit 20 \
    --rate-limit 30 \
    2>&1 | tee -a "$LOG"
  pause_random
else
  log "[stage 4] skipped: no Rumah123 pending"
fi

# -----------------------------------------------------------------------------
# STAGE 5 — fetch_details for Lamudi (remainder, up to 20 more)
# -----------------------------------------------------------------------------
REMAIN=$(docker exec supabase-db psql -U postgres -d postgres -tAc \
  "SELECT COUNT(*) FROM public.raw_listings WHERE source_name='lamudi_bali' AND detail_fetched_at IS NULL")
if [ "$REMAIN" -gt 0 ]; then
  log "[stage 5] fetch_details for Lamudi remainder ($REMAIN pending)"
  write_status "lamudi_fetch_remainder"
  "$WRAP" python3 "$BASE/scrapers/rumah123/fetch_details.py" \
    --source-name lamudi_bali \
    --limit 20 \
    --rate-limit 30 \
    2>&1 | tee -a "$LOG"
  pause_random
else
  log "[stage 5] skipped: Lamudi all fetched"
fi

# -----------------------------------------------------------------------------
# STAGE 6 — normalize (new pending + refresh recently-updated)
# -----------------------------------------------------------------------------
log "[stage 6] normalize (fresh pending + refresh all with detail)"
write_status "normalize"

"$WRAP" python3 "$BASE/scripts/normalize_listings.py" --all --rate-limit 1 2>&1 | tee -a "$LOG" || true

# refresh only newly-fetched details — keeping spend low (not --all)
"$WRAP" python3 "$BASE/scripts/normalize_listings.py" --refresh --limit 60 --rate-limit 1 2>&1 | tee -a "$LOG" || true

# -----------------------------------------------------------------------------
# STAGE 7 — final report
# -----------------------------------------------------------------------------
log "[stage 7] final report"
write_status "done"

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT source_name, COUNT(*) AS total,
       COUNT(*) FILTER (WHERE detail_status='ok') AS detail_ok,
       COUNT(*) FILTER (WHERE detail_status='blocked') AS blocked,
       COUNT(*) FILTER (WHERE detail_status='not_found') AS not_found,
       COUNT(*) FILTER (WHERE detail_fetched_at IS NULL) AS pending
FROM public.raw_listings
GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | tee -a "$LOG"

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT rental_suitability, COUNT(*) AS total,
       COUNT(*) FILTER (WHERE bedrooms=2) AS br2,
       COUNT(*) FILTER (WHERE bedrooms=2 AND listing_type IN ('villa','rumah')
                              AND (specific_area ILIKE '%berawa%' OR specific_area ILIKE '%canggu%'
                                   OR specific_area ILIKE '%pererenan%' OR specific_area ILIKE '%kerobokan%'
                                   OR specific_area ILIKE '%seminyak%')
                              AND (specific_area NOT ILIKE '%babakan%'
                                   AND specific_area NOT ILIKE '%tumbak%'
                                   AND specific_area NOT ILIKE '%kaba%')) AS br2_in_zone
FROM public.properties
GROUP BY 1 ORDER BY 1;" 2>&1 | tee -a "$LOG"

log "=== orchestrator DONE ==="
echo "Final log: $LOG"
echo "Status: $STATUS"
