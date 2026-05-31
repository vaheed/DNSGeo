#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -f .env ]; then
  echo ".env already exists; refusing to overwrite."
  exit 1
fi

cp .env.example .env

replace_secret() {
  local key="$1"
  local value="$2"
  sed -i "s|^${key}=.*|${key}=${value}|" .env
}

replace_secret POSTGRES_SUPERUSER_PASSWORD "$(openssl rand -base64 36 | tr -d '\n')"
replace_secret PDNS_DB_PASSWORD "$(openssl rand -base64 36 | tr -d '\n')"
replace_secret POWERADMIN_DB_PASSWORD "$(openssl rand -base64 36 | tr -d '\n')"
replace_secret REPLICATION_PASSWORD "$(openssl rand -base64 36 | tr -d '\n')"
replace_secret PDNS_API_KEY "$(openssl rand -hex 32)"
replace_secret PDNS_WEBSERVER_PASSWORD "$(openssl rand -base64 36 | tr -d '\n')"
replace_secret PA_ADMIN_PASSWORD "$(openssl rand -base64 24 | tr -d '\n')"
replace_secret PA_SESSION_KEY "$(openssl rand -hex 32)"

mkdir -p runtime/postgres-tls runtime/mmdb
chmod 755 runtime/postgres-tls
chmod 755 runtime/mmdb

echo "Created .env with generated secrets. Edit DNS IPs and PG_TLS_SAN before starting. No MMDB token is required by default."
