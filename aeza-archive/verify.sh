#!/bin/bash
# Integrity verification for tg-export.
# Run manually or via cron weekly.
# Detects: missing files, size mismatches, orphans, stale temp, broken transcripts.

set -u
BASE=/opt/tg-export
OUT_LOG="$BASE/verify.log"

log() {
  echo "[$(date -u +%FT%TZ)] $*" | tee -a "$OUT_LOG"
}

log "=== VERIFY START ==="

python3 - <<'PYEOF' 2>&1 | tee -a "$OUT_LOG"
import json, os, sys

BASE = "/opt/tg-export"
issues = []

# 1. Manifest vs disk
try:
    manifest = json.load(open(f"{BASE}/media/_manifest.json"))
except Exception as e:
    print(f"[ERR] cannot read manifest: {e}")
    sys.exit(1)

for f in manifest.get("files", []):
    path = f.get("path", "")
    expected = f.get("size", 0)
    if not path:
        continue
    if not os.path.exists(path):
        # Check if transcript exists (legitimate delete)
        fname = os.path.basename(path)
        sanitized = fname.replace(" ", "_")
        t1 = f"{BASE}/transcripts/{sanitized}.transcript.txt"
        t2 = f"{BASE}/transcripts/{fname}.transcript.txt"
        if os.path.exists(t1) or os.path.exists(t2):
            pass
        else:
            issues.append(f"MISSING: {path} (expected {expected} bytes, no transcript)")
    else:
        actual = os.path.getsize(path)
        if expected > 0 and actual != expected:
            issues.append(f"SIZE MISMATCH: {path} expected={expected} actual={actual}")
        elif actual == 0:
            issues.append(f"ZERO-BYTE: {path}")

# 2. Orphan files in media/ (not in manifest, not starting with _)
manifest_paths = {f["path"] for f in manifest.get("files", []) if f.get("path")}
for fn in os.listdir(f"{BASE}/media/"):
    if fn.startswith("_"):
        continue
    full = f"{BASE}/media/{fn}"
    if full not in manifest_paths:
        size = os.path.getsize(full)
        issues.append(f"ORPHAN: {full} ({size}B)")

# 3. Transcripts sanity: pair of .json + .txt per file
tx_dir = f"{BASE}/transcripts"
jsons = set()
txts = set()
for fn in os.listdir(tx_dir):
    if fn.startswith("_"):
        continue
    if "_part" in fn:
        issues.append(f"LEFTOVER_PART: {tx_dir}/{fn}")
        continue
    if fn.endswith(".transcript.json"):
        jsons.add(fn[:-len(".transcript.json")])
    elif fn.endswith(".transcript.txt"):
        txts.add(fn[:-len(".transcript.txt")])

missing_txt = jsons - txts
missing_json = txts - jsons
for base in missing_txt:
    issues.append(f"TRANSCRIPT_NO_TXT: {base}")
for base in missing_json:
    issues.append(f"TRANSCRIPT_NO_JSON: {base}")

# 4. Broken JSONs (try parse each)
for fn in os.listdir(tx_dir):
    if fn.endswith(".transcript.json") and "_part" not in fn:
        try:
            d = json.load(open(f"{tx_dir}/{fn}", encoding="utf-8"))
            if not d.get("text"):
                issues.append(f"EMPTY_TRANSCRIPT_TEXT: {fn}")
            if d.get("duration", 0) == 0:
                issues.append(f"ZERO_DURATION: {fn}")
        except Exception as e:
            issues.append(f"BROKEN_JSON: {fn}: {e}")

# 5. Stale temp
chunks = f"{BASE}/_chunks"
if os.path.isdir(chunks):
    leftover = [f for f in os.listdir(chunks) if not f.startswith(".")]
    if leftover:
        issues.append(f"STALE_CHUNKS: {len(leftover)} files in _chunks/")

# Print results
print(f"\n=== SUMMARY ===")
print(f"manifest files: {len(manifest.get('files', []))}")
print(f"on-disk media: {sum(1 for fn in os.listdir(f'{BASE}/media/') if not fn.startswith('_'))}")
print(f"transcripts (json+txt pairs): {len(jsons & txts)}")
print(f"issues found: {len(issues)}")
for i, iss in enumerate(issues):
    print(f"  {i+1}. {iss}")

if issues:
    sys.exit(1)
else:
    print("ALL CLEAN ✓")
PYEOF
VERIFY_RC=$?

log "=== VERIFY END (rc=$VERIFY_RC) ==="
exit $VERIFY_RC
