#!/usr/bin/env bash
# migrate.sh <user@new-host> [remote_path]
#
# Переносит realty-portal на новый сервер одной командой:
#   1. backup.sh на текущем сервере (все 4 compose-проекта)
#   2. rsync кода + дампов на новый сервер (БЕЗ локального .env)
#   3. restore.sh на новом сервере через ssh
#
# .env копируется отдельно через scp (а не rsync), с проверкой
# что chmod 600 сохранён и владелец root:root.
#
# Пример: ./scripts/migrate.sh root@new.server.com

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/.."

TARGET="${1:?Usage: $0 user@host [remote_path]}"
REMOTE_PATH="${2:-/opt/realty-portal}"

echo "→ (1/4) Снимаю backup..."
./scripts/backup.sh

LAST_BACKUP=$(ls -1dt backups/*/ | head -n1)
LAST_BACKUP="${LAST_BACKUP%/}"
echo "→ Последний backup: ${LAST_BACKUP}"

echo "→ (2/4) Копирую код на ${TARGET}:${REMOTE_PATH}..."
ssh "${TARGET}" "mkdir -p ${REMOTE_PATH}"
rsync -avz --delete \
  --exclude 'backups/' \
  --exclude '.env' \
  --exclude 'supabase/upstream/' \
  --exclude 'node_modules/' \
  --exclude '__pycache__/' \
  ./ "${TARGET}:${REMOTE_PATH}/"

echo "→ (2a/4) Копирую backup dump..."
rsync -avz "${LAST_BACKUP}/" "${TARGET}:${REMOTE_PATH}/${LAST_BACKUP}/"

echo "→ (2b/4) Копирую .env отдельно (chmod 600 forced)..."
scp "${LAST_BACKUP}/.env" "${TARGET}:${REMOTE_PATH}/.env"
ssh "${TARGET}" "chmod 600 ${REMOTE_PATH}/.env && chown root:root ${REMOTE_PATH}/.env"

echo "→ (3/4) Клонирую Supabase sparse + применяю override..."
ssh "${TARGET}" "bash -s" <<'REMOTE'
set -euo pipefail
cd /opt/realty-portal
if [[ ! -d supabase/upstream/docker ]]; then
  git clone --depth=1 --filter=blob:none --sparse \
    https://github.com/supabase/supabase supabase/upstream
  (cd supabase/upstream && git sparse-checkout set docker)
fi
# Наш override лежит в git как supabase/docker-compose.override.yml
# — копируем в upstream/docker чтобы compose его автоматически подхватил.
cp supabase/docker-compose.override.yml supabase/upstream/docker/docker-compose.override.yml
REMOTE

echo "→ (4/4) Запускаю restore..."
ssh "${TARGET}" "cd ${REMOTE_PATH} && ./scripts/restore.sh ${LAST_BACKUP}"

echo "✓ Миграция завершена. Проверяй:"
echo "    ssh ${TARGET} 'cd ${REMOTE_PATH} && ./scripts/doctor.sh'"
