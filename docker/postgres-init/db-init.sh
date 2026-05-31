#!/usr/bin/env bash
set -euo pipefail

: "${POSTGRES_SUPERUSER_PASSWORD:?POSTGRES_SUPERUSER_PASSWORD is required}"
: "${PDNS_DB_PASSWORD:?PDNS_DB_PASSWORD is required}"
: "${POWERADMIN_DB_PASSWORD:?POWERADMIN_DB_PASSWORD is required}"
: "${REPLICATION_PASSWORD:?REPLICATION_PASSWORD is required}"

POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
PG_TLS_CA_FILE="${PG_TLS_CA_FILE:-/certs/postgres/ca.crt}"
PG_SSLMODE="${PG_SSLMODE:-verify-ca}"
DB_INIT_TIMEOUT_SECONDS="${DB_INIT_TIMEOUT_SECONDS:-300}"

DNS_BASE_DOMAIN="${DNS_BASE_DOMAIN:-vaheed.net}"
DNS_NS1="${DNS_NS1:-nsg-01.vaheed.net}"
DNS_NS2="${DNS_NS2:-nsg-02.vaheed.net}"
DNS_NS3="${DNS_NS3:-nsg-03.vaheed.net}"
DNS_HOSTMASTER="${DNS_HOSTMASTER:-hostmaster.vaheed.net}"
DNS_DEFAULT_SERIAL="${DNS_DEFAULT_SERIAL:-2026052601}"
SEED_BASE_ZONE="${SEED_BASE_ZONE:-true}"
SEED_LUA_EXAMPLES="${SEED_LUA_EXAMPLES:-true}"
NS1_IPV4="${NS1_IPV4:-203.0.113.11}"
NS2_IPV4="${NS2_IPV4:-203.0.113.12}"
NS3_IPV4="${NS3_IPV4:-203.0.113.13}"
NS1_IPV6="${NS1_IPV6:-}"
NS2_IPV6="${NS2_IPV6:-}"
NS3_IPV6="${NS3_IPV6:-}"

LUA_GEO_DEFAULT_IPV4="${LUA_GEO_DEFAULT_IPV4:-203.0.113.10}"
LUA_GEO_EU_IPV4="${LUA_GEO_EU_IPV4:-203.0.113.40}"
LUA_GEO_NA_IPV4="${LUA_GEO_NA_IPV4:-203.0.113.50}"
LUA_GEO_AS_IPV4="${LUA_GEO_AS_IPV4:-203.0.113.30}"
LUA_GEO_HEALTH_PORT="${LUA_GEO_HEALTH_PORT:-443}"

log() {
  printf '[%s] [db-init] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

base_conn="host=${POSTGRES_HOST} port=${POSTGRES_PORT} user=${POSTGRES_USER} dbname=${POSTGRES_DB} sslmode=${PG_SSLMODE} sslrootcert=${PG_TLS_CA_FILE}"
pdns_conn="host=${POSTGRES_HOST} port=${POSTGRES_PORT} user=${POSTGRES_USER} dbname=pdns sslmode=${PG_SSLMODE} sslrootcert=${PG_TLS_CA_FILE}"

export PGPASSWORD="$POSTGRES_SUPERUSER_PASSWORD"

log "waiting for PostgreSQL TLS CA at ${PG_TLS_CA_FILE}"
for _ in $(seq 1 "$DB_INIT_TIMEOUT_SECONDS"); do
  [ -s "$PG_TLS_CA_FILE" ] && break
  sleep 1
done

if [ ! -s "$PG_TLS_CA_FILE" ]; then
  log "PostgreSQL CA file is missing or unreadable: ${PG_TLS_CA_FILE}"
  exit 1
fi

log "waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}"
for _ in $(seq 1 "$DB_INIT_TIMEOUT_SECONDS"); do
  if psql "$base_conn" -v ON_ERROR_STOP=1 -qAt -c 'SELECT 1' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

psql "$base_conn" -v ON_ERROR_STOP=1 -qAt -c 'SELECT 1' >/dev/null

log "ensuring roles and pdns database"
psql "$base_conn" -v ON_ERROR_STOP=1 \
  -v pdns_password="$PDNS_DB_PASSWORD" \
  -v poweradmin_password="$POWERADMIN_DB_PASSWORD" \
  -v replication_password="$REPLICATION_PASSWORD" \
  -f /sql/10-roles-and-database.sql

log "ensuring PowerDNS schema"
psql "$pdns_conn" -v ON_ERROR_STOP=1 -f /sql/20-pdns-schema.sql

log "ensuring Poweradmin schema"
psql "$pdns_conn" -v ON_ERROR_STOP=1 -f /sql/30-poweradmin-schema.sql

case "${SEED_BASE_ZONE,,}" in
  true|1|yes|on)
    soa_content="${DNS_NS1} ${DNS_HOSTMASTER} ${DNS_DEFAULT_SERIAL} 3600 900 1209600 300"
    lua_www="A \";if continent('EU') then return '${LUA_GEO_EU_IPV4}' elseif continent('NA') then return '${LUA_GEO_NA_IPV4}' elseif continent('AS') then return '${LUA_GEO_AS_IPV4}' else return '${LUA_GEO_DEFAULT_IPV4}' end\""
    lua_country="A \";if country({'NL','DE','FR','GB'}) then return '${LUA_GEO_EU_IPV4}' elseif country({'US','CA'}) then return '${LUA_GEO_NA_IPV4}' else return '${LUA_GEO_DEFAULT_IPV4}' end\""
    lua_closest="A \"pickclosest({'${LUA_GEO_EU_IPV4}','${LUA_GEO_NA_IPV4}','${LUA_GEO_AS_IPV4}','${LUA_GEO_DEFAULT_IPV4}'})\""
    lua_ha="A \"ifportup(${LUA_GEO_HEALTH_PORT}, {{'${LUA_GEO_EU_IPV4}','${LUA_GEO_NA_IPV4}'}, {'${LUA_GEO_DEFAULT_IPV4}'}}, {selector='pickclosest'})\""
    lua_country_code='TXT "countryCode()"'
    lua_continent_code='TXT "continentCode()"'

    log "ensuring base SQL zone ${DNS_BASE_DOMAIN} and optional Lua examples"
    psql "$pdns_conn" -v ON_ERROR_STOP=1 \
      -v zone="$DNS_BASE_DOMAIN" \
      -v soa_content="$soa_content" \
      -v ns1="$DNS_NS1" \
      -v ns2="$DNS_NS2" \
      -v ns3="$DNS_NS3" \
      -v ns1_ipv4="$NS1_IPV4" \
      -v ns2_ipv4="$NS2_IPV4" \
      -v ns3_ipv4="$NS3_IPV4" \
      -v ns1_ipv6="$NS1_IPV6" \
      -v ns2_ipv6="$NS2_IPV6" \
      -v ns3_ipv6="$NS3_IPV6" \
      -v seed_lua_examples="$SEED_LUA_EXAMPLES" \
      -v lua_www="$lua_www" \
      -v lua_country="$lua_country" \
      -v lua_closest="$lua_closest" \
      -v lua_ha="$lua_ha" \
      -v lua_country_code="$lua_country_code" \
      -v lua_continent_code="$lua_continent_code" \
      -f /sql/40-seed-base-zone.sql
    ;;
  *)
    log "base SQL zone seeding disabled"
    ;;
esac

log "database initialization completed"
