#!/usr/bin/env bash
# Usage: scripts/restore.sh <backup_dir> <timestamp>
# Replaces the current database and attachments with the given backup.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

dir="${1:?backup dir}"; stamp="${2:?timestamp}"
db_dump="$dir/$stamp-db.dump"; assets="$dir/$stamp-assets.tar.gz"
[ -f "$db_dump" ] && [ -f "$assets" ] || { echo "Backup files not found" >&2; exit 1; }

read -r -p "This overwrites the current data of ${SF_VOLUME_PREFIX:-sparkfaktory_proyectos}. Type RESTORE: " answer
[ "$answer" = "RESTORE" ] || exit 1

docker compose stop web worker cron
docker compose up -d db
docker compose exec -T db pg_restore -U "${POSTGRES_USER:-sparkfaktory}" -d "${POSTGRES_DB:-sparkfaktory_proyectos}" \
  --clean --if-exists --no-owner < "$db_dump"
docker run --rm -v "${SF_VOLUME_PREFIX:-sparkfaktory_proyectos}_assets:/data" -v "$(cd "$dir" && pwd):/backup:ro" \
  alpine:3 sh -c "find /data -mindepth 1 -delete && tar -xzf /backup/$stamp-assets.tar.gz -C /data && chown -R 1000:1000 /data"
docker compose up -d
echo "Restore finished; check: docker compose ps"
