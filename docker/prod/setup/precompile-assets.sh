#!/bin/bash
set -euxo pipefail

DOCKER=${DOCKER:-0}

if [ -f config/frontend_assets.manifest.json ]; then
  echo "Assets have already been precompiled. Reusing."
else
  echo "Assets need to be compiled"
  JOBS=8 npm install

  export SECRET_KEY_BASE="$(openssl rand -hex 64)" RAILS_ENV=production DATABASE_URL=nulldb://db

  # Angular runs without a Rails process alive next to it so the build fits in
  # memory-capped builders on shared hosts.
  bin/rails openproject:plugins:register_frontend assets:export_locales
  (cd frontend && npm run build)
  bin/rails assets:rebuild_manifest
  RECOMPILE_RAILS_ASSETS=true bin/rails assets:precompile

  if [ "$DOCKER" = "1" ]; then
    rm -rf /tmp/nulldb
    # Remove sprockets cache
    rm -rf "$APP_PATH/tmp/cache/assets"
    # Remove node_modules and entire frontend
    rm -rf "$APP_PATH/node_modules/" "$APP_PATH/frontend/node_modules/"
    # Remove angular cache
    rm -rf "$APP_PATH/frontend/.angular"
    # Clean cache in root
    rm -rf /root/.npm
    rm -f "$APP_PATH/log/production.log"
  fi
fi