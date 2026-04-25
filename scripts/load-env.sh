#!/bin/bash
# load-env.sh — pull env vars from Aeza and export for current session

SSH_KEY="$HOME/.ssh/aeza_ed25519"
AEZA_HOST="root@193.233.128.21"

echo "→ Pulling env from Aeza..." >&2

# Pull from both env files
ENV_FILES="/opt/mcp_agent_mail/.env /opt/realty-portal/.env"

for file in $ENV_FILES; do
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$AEZA_HOST" "cat $file 2>/dev/null" | \
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

        # Remove quotes from value
        value="${value%\"}"
        value="${value#\"}"

        # Export variable
        export "$key=$value"
        echo "export $key='$value'"
    done
done
