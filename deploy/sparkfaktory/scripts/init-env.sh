#!/usr/bin/env bash
# Creates .env from .env.example with fresh random secrets. Never prints them.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -e .env ]; then
  echo ".env already exists; refusing to overwrite." >&2
  exit 1
fi

umask 077
cp .env.example .env
set_value() { sed -i "s|^$1=.*|$1=$2|" .env; }
set_value POSTGRES_PASSWORD "$(openssl rand -hex 24)"
set_value SECRET_KEY_BASE "$(openssl rand -hex 64)"
set_value OPENPROJECT_SEED__ADMIN__USER__PASSWORD "$(openssl rand -base64 24 | tr -d '/+=')Aa1!"
[ -n "${SF_IMAGE:-}" ] && set_value SF_IMAGE "$SF_IMAGE"
[ -n "${SPARKFAKTORY_ADMIN_EMAILS:-}" ] && set_value SPARKFAKTORY_ADMIN_EMAILS "$SPARKFAKTORY_ADMIN_EMAILS"
chmod 600 .env
echo "Created .env (mode 600). Review SF_IMAGE, SPARKFAKTORY_ADMIN_EMAILS and the SMTP block."
