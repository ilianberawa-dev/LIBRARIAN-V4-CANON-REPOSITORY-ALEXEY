#!/usr/bin/env bash
# run_with_env.sh — load /opt/realty-portal/.env then exec the given command.
# Canon: 6_single_secret_vault (единое хранилище) + 5_minimal_clear_commands (fail-loud).
#
# Usage:
#   ./scripts/run_with_env.sh python3 scripts/normalize_listings.py --all
#   ./scripts/run_with_env.sh python3 scrapers/rumah123/fetch_details.py --all
#   REALTY_ENV_FILE=/path/to/other.env ./scripts/run_with_env.sh <cmd>
set -euo pipefail

ENV_FILE="${REALTY_ENV_FILE:-/opt/realty-portal/.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "FATAL: env file not found: $ENV_FILE" >&2
    exit 1
fi

if [ "$#" -eq 0 ]; then
    echo "FATAL: no command supplied. usage: $0 <cmd> [args...]" >&2
    exit 2
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for var in REALTY_DB_DSN LITELLM_MASTER_KEY; do
    if [ -z "${!var:-}" ]; then
        echo "FATAL: required env var $var is empty after sourcing $ENV_FILE" >&2
        exit 3
    fi
done

exec "$@"
