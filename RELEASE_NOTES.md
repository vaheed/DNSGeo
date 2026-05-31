# Release notes

## 2026-05-27 Lua GeoDNS release

- Converted GeoDNS from YAML service records to PostgreSQL-backed PowerDNS `LUA` records.
- Kept the `geoip` backend only as the MMDB geolocation provider required by Lua functions such as `continent()`, `country()`, and `pickclosest()`.
- Replaced `geo/geo.yml` with `geo/lua-bootstrap.yml`, an intentionally empty GeoIP backend bootstrap file.
- Added `enable-lua-records=yes` to the rendered PowerDNS config.
- Added Lua runtime controls through `.env`: `PDNS_LUA_RECORDS_EXEC_LIMIT`, `PDNS_LUA_HEALTH_CHECKS_INTERVAL`, and `PDNS_LUA_HEALTH_CHECKS_EXPIRE_DELAY`.
- Added optional seeded Lua examples under `www.lua.DOMAIN`, `country.lua.DOMAIN`, `closest.lua.DOMAIN`, `ha.lua.DOMAIN`, `country-code.lua.DOMAIN`, and `continent-code.lua.DOMAIN`.
- Added PowerDNS API examples using `curl` and `jq` under `examples/api`.
- Updated `scripts/check.sh` to test PostgreSQL-backed Lua GeoDNS records.
- Updated primary and replica compose files to use the Lua image name `virak/pdns-auth-50-lua-pgsql:local`.
- Fixed optional IPv6 seed behavior so blank `NS*_IPV6` values do not create empty AAAA records.
- Rewrote `README.md` around Lua records, PowerDNS API operations, day-to-day checks, and replicated PostgreSQL DNS nodes.

## 2026-05-27 clean first-boot release

- Removed the repair helper. The stack is intended to start from normal `docker compose build` and `docker compose up -d` commands.
- Added an MMDB healthcheck and changed PowerDNS startup ordering so `pdns-auth` starts only after the MMDB file exists.
- Added dedicated PowerDNS and Poweradmin healthcheck scripts with longer startup windows.
- Kept Docker Compose v1 compatibility by avoiding `service_completed_successfully`; service containers still include their own wait loops.
- Fixed optional IPv6 Compose warnings by using empty defaults for `NS1_IPV6`, `NS2_IPV6`, and `NS3_IPV6`.
- Fixed PostgreSQL 17 sequence ownership handling in the Poweradmin schema initializer.
- Switched Poweradmin image selection to `POWERADMIN_TAG`, defaulting to `stable`.
- Fixed PostgreSQL replica first boot by overriding copied primary TLS server settings on replica nodes. Streaming from primary still uses TLS; inbound replica PostgreSQL service defaults to local plaintext and must be firewall-restricted.
- Added `replica/docker-compose.dns-node.yml` for full additional DNS nodes backed by local PostgreSQL streaming replicas.

## Earlier fixed release

- Moved database schema management out of first-run-only PostgreSQL init scripts into an idempotent `db-init` service.
- Added TLS directory permission corrections so client containers can read `ca.crt` while private keys remain restricted.
- Added MMDB extraction support for direct `.mmdb`, `.mmdb.gz`, `.tar.gz`, `.tgz`, and `.zip` artifacts.
- Added MMDB file replacement detection for PowerDNS restarts.
