#!/usr/bin/env bash
# restore.sh <backup_dir> — накатывает snapshot обратно.
#
# Останавливает стек, восстанавливает все realty_* тома + Supabase
# bind-mounts, копирует .env и SQL-миграции, поднимает стек.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/stack-lib.sh"

BACKUP_DIR="${1:?Usage: $0 <backup_dir>}"
# Поддержка относительных и абсолютных путей
if [[ "${BACKUP_DIR}" != /* ]]; then
  BACKUP_DIR="${REALTY_ROOT}/${BACKUP_DIR}"
fi
if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo "✗ Не найдена папка ${BACKUP_DIR}" >&2
  exit 1
fi

echo "→ Останавливаю стек..."
stack_down

echo "→ Восстанавливаю realty_* тома из ${BACKUP_DIR}..."
shopt -s nullglob
for tar in "${BACKUP_DIR}"/realty_*.tar.gz; do
  vol=$(basename "${tar}" .tar.gz)
  tar_name=$(basename "${tar}")
  echo "  • ${vol}"
  docker volume create "${vol}" >/dev/null
  docker run --rm \
    -v "${vol}:/target" \
    -v "${BACKUP_DIR}:/backup:ro" \
    alpine:3.20 \
    sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null; tar xzf \"/backup/${tar_name}\" -C /target"
done

echo "→ Восстанавливаю Supabase bind-mounts..."
if [[ -f "${BACKUP_DIR}/supabase-bind-volumes.tar.gz" ]]; then
  tar xzf "${BACKUP_DIR}/supabase-bind-volumes.tar.gz" \
    -C "${REALTY_ROOT}/supabase/upstream/docker"
fi

echo "→ Восстанавливаю .env (только если отсутствует — не перетираю новый)..."
if [[ -f "${BACKUP_DIR}/.env" && ! -f "${ENV_FILE}" ]]; then
  cp "${BACKUP_DIR}/.env" "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"
fi

echo "→ Фиксую ownership npm-cache volume (docker создаёт новые тома root-owned)..."
# Создаём явно (если уже есть — no-op), затем chown до 1000:1000 ДО стартa openclaw.
# Без этого первый npx в container падает с EACCES на /home/node/.npm.
docker volume create realty_openclaw_npm_cache >/dev/null
docker run --rm -v realty_openclaw_npm_cache:/data alpine:3.20 chown -R 1000:1000 /data

echo "→ Sync supabase override (upstream/ в .gitignore, нужна копия рядом с compose-файлом)..."
sync_supabase_override

echo "→ Поднимаю стек..."
stack_up

echo "→ Применяю SQL-миграции канона (idempotent: skip если таблицы есть)..."
apply_migrations

echo "→ Финальная сверка:"
stack_ps

echo "✓ Restore завершён."
