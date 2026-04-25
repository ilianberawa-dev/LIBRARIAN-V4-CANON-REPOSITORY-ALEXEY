#!/usr/bin/env bash
# stack-lib.sh — shared helpers: список compose-проектов и функции
# down/up в правильном порядке.
#
# Порядок down: outer→inner (openclaw → lightrag → supabase → main).
# Порядок up:   inner→outer (main сеть → supabase БД → lightrag → openclaw).
#
# Source: `source "$(dirname "$0")/stack-lib.sh"`

set -euo pipefail

# Путь к корню проекта (скрипты лежат в scripts/)
if [[ -z "${REALTY_ROOT:-}" ]]; then
  REALTY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
ENV_FILE="${REALTY_ROOT}/.env"

# Ordered from "most dependent" to "least dependent" (для down).
# Формат: "<relative_path>" — compose запускается `(cd <path> && docker compose ...)`.
# Supabase autoloads docker-compose.override.yml если лежит рядом.
STACK_DIRS_DOWN=(
  "openclaw"
  "lightrag"
  "supabase/upstream/docker"
  "."                      # main compose (сеть realty_net + placeholder)
)

# Reverse для up.
STACK_DIRS_UP=(
  "."
  "supabase/upstream/docker"
  "lightrag"
  "openclaw"
)

_compose() {
  # Общий wrapper, гарантирует --env-file на единый сейф.
  # Supabase compose сам также читает /opt/realty-portal/.env через env_file в сервисах.
  local dir="$1"; shift
  (cd "${REALTY_ROOT}/${dir}" && docker compose --env-file "${ENV_FILE}" "$@")
}

# Супабазовский upstream/ — sparse-clone, в .gitignore. Наш override живёт
# в git как supabase/docker-compose.override.yml — sync-им его в upstream.
sync_supabase_override() {
  local src="${REALTY_ROOT}/supabase/docker-compose.override.yml"
  local dst="${REALTY_ROOT}/supabase/upstream/docker/docker-compose.override.yml"
  if [[ -f "${src}" && -d "${REALTY_ROOT}/supabase/upstream/docker" ]]; then
    cp "${src}" "${dst}"
  fi
}

# Ждём пока Postgres действительно принимает соединения (после up).
wait_postgres_ready() {
  local tries=30
  while (( tries-- > 0 )); do
    if docker exec supabase-db pg_isready -U postgres -q 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "  ⚠ supabase-db не стал ready за 60s" >&2
  return 1
}

# Применяем наши SQL-миграции (идемпотентно — если таблицы есть, skip).
apply_migrations() {
  local migrations_dir="${REALTY_ROOT}/supabase/migrations"
  [[ -d "${migrations_dir}" ]] || return 0
  wait_postgres_ready || return 1
  local exists
  exists=$(docker exec supabase-db psql -U postgres -d postgres -tAc \
    "SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename='raw_listings'" 2>/dev/null || echo "0")
  if [[ "${exists}" == "1" ]]; then
    echo "  ✓ canonical tables exist — migrations skipped"
    return 0
  fi
  echo "  → applying migrations from ${migrations_dir}"
  for sql in "${migrations_dir}"/*.sql; do
    [[ -f "${sql}" ]] || continue
    echo "     • $(basename "${sql}")"
    docker exec -i supabase-db psql -U postgres -d postgres < "${sql}"
  done
}

stack_down() {
  for dir in "${STACK_DIRS_DOWN[@]}"; do
    local cf="${REALTY_ROOT}/${dir}/docker-compose.yml"
    if [[ -f "${cf}" ]]; then
      echo "→ down: ${dir}"
      _compose "${dir}" down "$@" || true
    fi
  done
}

stack_up() {
  for dir in "${STACK_DIRS_UP[@]}"; do
    local cf="${REALTY_ROOT}/${dir}/docker-compose.yml"
    if [[ -f "${cf}" ]]; then
      echo "→ up:   ${dir}"
      _compose "${dir}" up -d "$@" || true
    fi
  done
}

stack_ps() {
  echo "→ all realty_ containers:"
  docker ps -a --filter name=realty_ --format 'table {{.Names}}\t{{.Status}}' || true
  echo "→ all supabase-* containers (supabase compose uses non-realty prefix):"
  docker ps -a --filter name=supabase- --format 'table {{.Names}}\t{{.Status}}' || true
}
