#!/usr/bin/env bash
# Creates the administrators listed in SPARKFAKTORY_ADMIN_EMAILS (from .env, or overridden on the
# command line) and prints their one-time temporary passwords. RESET=true issues new ones.
set -euo pipefail
cd "$(dirname "$0")/.."
args=(-e RESET="${RESET:-false}")
[ -n "${SPARKFAKTORY_ADMIN_EMAILS:-}" ] && args+=(-e SPARKFAKTORY_ADMIN_EMAILS="$SPARKFAKTORY_ADMIN_EMAILS")
docker compose exec -T "${args[@]}" web bundle exec rake sparkfaktory:create_admins
