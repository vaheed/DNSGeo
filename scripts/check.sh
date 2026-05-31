#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a
  . ./.env
  set +a
fi

: "${PDNS_API_KEY:?PDNS_API_KEY is required. Run from the project directory after creating .env.}"

zone="${DNS_BASE_DOMAIN:-vaheed.net}"
dns_port="${DNS_PORT:-53}"
api_port="${PDNS_API_PORT:-8081}"
poweradmin_port="${POWERADMIN_PORT:-8080}"

printf 'Checking generated PostgreSQL CA...\n'
test -s runtime/postgres-tls/ca.crt
openssl x509 -in runtime/postgres-tls/ca.crt -noout -subject -enddate

printf '\nChecking PowerDNS API...\n'
curl -fsS -H "X-API-Key: ${PDNS_API_KEY}" "http://127.0.0.1:${api_port}/api/v1/servers/localhost" | sed 's/,/,&\n/g'

printf '\nChecking SQL-backed base zone...\n'
dig @127.0.0.1 -p "$dns_port" SOA "$zone" +short

printf '\nChecking Lua GeoDNS examples from PostgreSQL...\n'
dig @127.0.0.1 -p "$dns_port" A "www.lua.${zone}" +short || true
dig @127.0.0.1 -p "$dns_port" A "closest.lua.${zone}" +short || true
dig @127.0.0.1 -p "$dns_port" TXT "country-code.lua.${zone}" +short || true
dig @127.0.0.1 -p "$dns_port" TXT "continent-code.lua.${zone}" +short || true

printf '\nChecking Poweradmin HTTP endpoint...\n'
curl -fsSI "http://127.0.0.1:${poweradmin_port}/" | head -n 1
