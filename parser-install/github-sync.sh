#!/bin/bash
# GitHub sync for Telegram parser
# Syncs library_index.json + transcripts to GitHub repo
# Run via cron every hour

set -eu

REPO_DIR="${REPO_DIR:-/opt/librarian}"
PARSER_DIR="${PARSER_DIR:-/opt/tg-export}"
LOG="$PARSER_DIR/github-sync.log"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG"
}

# Check env
if [ ! -d "$REPO_DIR/.git" ]; then
  log "[error] REPO_DIR not a git repo: $REPO_DIR"
  exit 1
fi

if [ ! -f "$PARSER_DIR/library_index.json" ]; then
  log "[error] library_index.json not found in $PARSER_DIR"
  exit 1
fi

cd "$REPO_DIR"

# Fetch + hard reset to avoid merge conflicts
log "[sync] fetching origin/main"
git fetch origin main
git reset --hard origin/main

# Create directories if needed
mkdir -p alexey-materials/metadata alexey-materials/transcripts

# Copy library index
cp "$PARSER_DIR/library_index.json" alexey-materials/metadata/
log "[copy] library_index.json"

# Sync transcripts (only .json and .txt, skip temp files)
if [ -d "$PARSER_DIR/transcripts" ]; then
  rsync -av --delete-after \
    --include='*.transcript.json' \
    --include='*.transcript.txt' \
    --exclude='*' \
    "$PARSER_DIR/transcripts/" alexey-materials/transcripts/
  log "[sync] transcripts (rsync)"
fi

# Check if anything changed
git add alexey-materials/
if git diff --cached --quiet; then
  log "[skip] no changes to commit"
  exit 0
fi

# Get post count for commit message
POSTS=$(jq -r '.total_posts // .posts | length' alexey-materials/metadata/library_index.json 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Commit + push
git commit -m "sync: $POSTS posts + transcripts ($TIMESTAMP)"
log "[commit] $POSTS posts"

# Push with GitHub token from env
if [ -z "${GITHUB_TOKEN:-}" ]; then
  log "[error] GITHUB_TOKEN not set, cannot push"
  exit 1
fi

GIT_ASKPASS=true git push https://x-access-token:$GITHUB_TOKEN@github.com/$(git remote get-url origin | sed 's|https://github.com/||' | sed 's|\.git$||').git HEAD:main
log "[push] success"
