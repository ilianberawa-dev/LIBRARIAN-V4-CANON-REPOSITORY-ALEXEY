#!/usr/bin/env bash
# backup.sh — консистентный snapshot всех томов realty_* + supabase_*.
#
# Останавливает все 4 compose-проекта (realty, realty_supabase,
# realty_lightrag, realty_openclaw) в правильном порядке ДО tar,
# чтобы Postgres/LightRAG не писали во время snapshot.
# После — поднимает всё обратно.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/stack-lib.sh"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${REALTY_ROOT}/backups/${STAMP}"
mkdir -p "${BACKUP_DIR}"

echo "→ Останавливаю все 4 compose-проекта (безопасный snapshot)..."
stack_down

echo "→ Snapshot всех realty_* томов..."
for vol in $(docker volume ls --filter name=realty_ --format '{{.Name}}'); do
  echo "  • ${vol}"
  docker run --rm \
    -v "${vol}:/source:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine:3.20 \
    tar czf "/backup/${vol}.tar.gz" -C /source .
done

echo "→ Snapshot bind-mounted Supabase volumes (supabase/upstream/docker/volumes/)..."
if [[ -d "${REALTY_ROOT}/supabase/upstream/docker/volumes" ]]; then
  tar czf "${BACKUP_DIR}/supabase-bind-volumes.tar.gz" \
    -C "${REALTY_ROOT}/supabase/upstream/docker" volumes
fi

echo "→ Копирую .env + SQL-миграции + SKILL.md-файлы..."
if [[ -f "${ENV_FILE}" ]]; then
  cp "${ENV_FILE}" "${BACKUP_DIR}/.env"
  chmod 600 "${BACKUP_DIR}/.env"
fi
if [[ -d "${REALTY_ROOT}/supabase/migrations" ]]; then
  cp -r "${REALTY_ROOT}/supabase/migrations" "${BACKUP_DIR}/migrations"
fi
if [[ -d "${REALTY_ROOT}/skills" ]]; then
  cp -r "${REALTY_ROOT}/skills" "${BACKUP_DIR}/skills"
fi

echo "→ Поднимаю стек обратно..."
stack_up

echo "→ Финальная сверка:"
stack_ps

echo "✓ Backup готов: ${BACKUP_DIR}"
du -sh "${BACKUP_DIR}"
