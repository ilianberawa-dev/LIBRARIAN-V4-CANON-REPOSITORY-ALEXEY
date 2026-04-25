#!/usr/bin/env bash
# doctor.sh — smoke-test всего стека (compose health + MCP stdio).
#
# Запускать на сервере после `up`, после миграции, после изменений
# в .env. Не пишет ничего, не меняет состояние — только диагностика.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/stack-lib.sh"

PASS=0
FAIL=0
WARN=0
check() {
  local name="$1" cmd="$2" expect="$3"
  local out
  if out=$(eval "${cmd}" 2>&1); then
    if [[ -z "${expect}" || "${out}" == *"${expect}"* ]]; then
      echo "  ✓ ${name}"
      PASS=$((PASS+1))
      return 0
    fi
  fi
  echo "  ✗ ${name} — ${out:0:200}"
  FAIL=$((FAIL+1))
  return 1
}
warn() {
  echo "  ⚠ $1"
  WARN=$((WARN+1))
}

echo "=== 1. Containers (12 core + 4 heavy) ==="
for c in supabase-db supabase-kong supabase-rest supabase-auth supabase-storage \
         supabase-meta supabase-studio supabase-imgproxy \
         realty_lightrag realty_litellm realty_ollama realty_openclaw; do
  check "${c} running" "docker ps --filter name=^${c}$ --format '{{.Names}}'" "${c}"
done
# Heavy (not strictly required for MVP, but should be running on 8GB+)
for c in supabase-analytics supabase-pooler supabase-edge-functions supabase-vector; do
  if docker ps --filter name=^${c}$ --format '{{.Names}}' | grep -qx "${c}"; then
    echo "  ✓ ${c} running (heavy)"
    PASS=$((PASS+1))
  else
    warn "${c} not running (heavy — opt out if RAM <8GB)"
  fi
done

echo
echo "=== 2. Network + volumes ==="
check "realty_net exists" "docker network ls --filter name=realty_net --format '{{.Name}}'" "realty_net"
check "volumes prefixed realty_" "docker volume ls --filter name=realty_ --format '{{.Name}}' | wc -l" ""

# Detect the common EACCES trap: npm-cache volume owned by root instead of uid 1000
if docker volume ls --format '{{.Name}}' | grep -qx realty_openclaw_npm_cache; then
  npm_owner=$(docker run --rm -v realty_openclaw_npm_cache:/data alpine:3.20 stat -c '%u:%g' /data 2>/dev/null || echo "?")
  if [[ "${npm_owner}" == "1000:1000" || "${npm_owner}" == "0:0" && "$(docker run --rm -v realty_openclaw_npm_cache:/data alpine:3.20 ls /data | wc -l)" == "0" ]]; then
    echo "  ✓ npm-cache volume ownership OK (${npm_owner})"
    PASS=$((PASS+1))
  else
    warn "npm-cache volume owned by ${npm_owner}, should be 1000:1000 — fix: docker run --rm -v realty_openclaw_npm_cache:/data alpine chown -R 1000:1000 /data"
  fi
fi

echo
echo "=== 3. Single secret vault ==="
if [[ -f /opt/realty-portal/.env ]]; then
  perms=$(stat -c '%a' /opt/realty-portal/.env 2>/dev/null || echo "?")
  [[ "${perms}" == "600" ]] && echo "  ✓ /opt/realty-portal/.env chmod 600" || warn "/opt/realty-portal/.env chmod is ${perms}, expected 600"
else
  warn "/opt/realty-portal/.env not found (running outside server?)"
fi
for v in ANON_KEY SERVICE_ROLE_KEY LIGHTRAG_API_KEY MCP_API_KEY JWT_SECRET POSTGRES_PASSWORD; do
  if [[ -f /opt/realty-portal/.env ]] && grep -qE "^${v}=." /opt/realty-portal/.env; then
    echo "  ✓ ${v} set in .env"
  else
    warn "${v} missing or empty in .env"
  fi
done

echo
echo "=== 4. 4 canonical tables present ==="
tables=$(docker exec supabase-db psql -U postgres -d postgres -tAc \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY 1" 2>/dev/null || echo "")
for t in market_snapshots properties raw_listings sources; do
  echo "${tables}" | grep -qx "${t}" && echo "  ✓ table public.${t}" || echo "  ✗ table public.${t} missing"
done

echo
echo "=== 5. MCP stdio (supabase + lightrag) ==="
init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"doctor","version":"0"}}}'

sup_cmd=$(docker exec realty_openclaw cat /home/node/.openclaw/openclaw.json 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["mcp"]["servers"]["supabase"]["args"][1])' 2>/dev/null || echo "")
if [[ -n "${sup_cmd}" ]]; then
  out=$(echo "${init}" | docker exec -i realty_openclaw sh -c "${sup_cmd}" 2>&1 | head -20 || true)
  echo "${out}" | grep -q '"protocolVersion":"2024-11-05"' && echo "  ✓ supabase MCP stdio initialize OK" || echo "  ✗ supabase MCP stdio initialize failed (see logs)"
else
  warn "supabase MCP command not in openclaw.json"
fi

lr_cmd=$(docker exec realty_openclaw cat /home/node/.openclaw/openclaw.json 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["mcp"]["servers"]["lightrag"]["args"][1])' 2>/dev/null || echo "")
if [[ -n "${lr_cmd}" ]]; then
  out=$(echo "${init}" | docker exec -i realty_openclaw sh -c "${lr_cmd}" 2>&1 | head -20 || true)
  echo "${out}" | grep -q '"protocolVersion":"2024-11-05"' && echo "  ✓ lightrag MCP stdio initialize OK" || echo "  ✗ lightrag MCP stdio initialize failed (see logs)"
else
  warn "lightrag MCP command not in openclaw.json"
fi

echo
echo "=== Summary: ${PASS} passed, ${FAIL} failed, ${WARN} warnings ==="
[[ "${FAIL}" -eq 0 ]] || exit 1
