#!/usr/bin/env bash
# Usage: scripts/backup.sh [target_dir]   (default: ./backups)
# Produces <timestamp>-db.dump (pg_dump custom format) and <timestamp>-assets.tar.gz.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

target="${1:-./backups}"
stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$target"
umask 077

docker compose exec -T db pg_dump -U "${POSTGRES_USER:-sparkfaktory}" -d "${POSTGRES_DB:-sparkfaktory_proyectos}" -Fc \
  > "$target/$stamp-db.dump"
docker run --rm -v "${SF_VOLUME_PREFIX:-sparkfaktory_proyectos}_assets:/data:ro" -v "$(cd "$target" && pwd):/backup" \
  alpine:3 tar -czf "/backup/$stamp-assets.tar.gz" -C /data .
echo "$stamp" > "$target/LATEST"
echo "Backup written: $target/$stamp-db.dump, $target/$stamp-assets.tar.gz"
