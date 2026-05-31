# PowerDNS Authoritative with PostgreSQL, Lua GeoDNS, MMDB, and Poweradmin

This repository runs an authoritative DNS stack where **all normal records and all GeoDNS records live in PostgreSQL**. GeoDNS is implemented with **PowerDNS Lua records**. The old YAML service-record model is removed.

The `geoip` backend is still loaded, but only because PowerDNS Lua geographical functions need it. The file `geo/lua-bootstrap.yml` is intentionally empty. Do not put production records there.

## What this stack contains

- PowerDNS Authoritative 5.x.
- Generic PostgreSQL backend for normal DNS records and `LUA` records.
- GeoIP backend loaded only as the MMDB lookup provider for Lua functions such as `continent()`, `country()`, `countryCode()`, `continentCode()`, and `pickclosest()`.
- PostgreSQL 17 primary with generated TLS certificates and physical streaming replica support.
- One-shot `db-init` container for roles, schema, grants, Poweradmin schema, and optional seed records.
- Daily MMDB downloader. Default source is DB-IP City Lite through a direct CDN URL and needs no token.
- Poweradmin through the official `poweradmin/poweradmin:stable` line by default.
- Optional Caddy HTTPS overlay for Poweradmin.
- Example PowerDNS API scripts using `curl` and `jq`.

## Important behavior

The startup path is clean:

```bash
docker compose build
docker compose up -d
```

No repair script is required. No manual restart is required after first boot.

`pdns-auth` waits for three things before starting PowerDNS:

- PostgreSQL schema exists.
- PostgreSQL TLS CA is readable, when TLS verification is enabled.
- MMDB file exists.

`mmdb-updater` has its own healthcheck, so PowerDNS does not start while the first MMDB download is still running.

## Repository layout

```text
docker-compose.yml                    Primary stack
docker-compose.https.yml              Optional HTTPS overlay for Poweradmin
docker/postgres-primary/              PostgreSQL primary image, TLS, and replication config
docker/postgres-init/                 Idempotent database and seed initializer
docker/pdns-auth/                     PowerDNS image, Lua/GeoIP config, wait logic, healthcheck
docker/mmdb-updater/                  MMDB downloader image and healthcheck
docker/poweradmin/                    Poweradmin wrapper and healthcheck
geo/lua-bootstrap.yml                 Empty GeoIP backend bootstrap file, not a records file
examples/api/                         curl and jq examples for normal and Lua records
replica/docker-compose.replica.yml    PostgreSQL-only replica node
replica/docker-compose.dns-node.yml   Full DNS node with local replicated PostgreSQL
scripts/bootstrap.sh                  Optional .env generator with random secrets
scripts/check.sh                      Post-start health and DNS checks
scripts/show-replica-bundle.sh        Shows generated replica TLS files
```

## Requirements

Install Docker Engine and the Docker Compose plugin. The modern command is:

```bash
docker compose version
```

The legacy Python command is:

```bash
docker-compose --version
```

The legacy `docker-compose` command can print a `KeyError: 'id'` traceback after a container becomes unhealthy. That traceback is from the old Compose CLI event watcher. Prefer `docker compose` when possible.

Install client tools for checks and API examples:

```bash
apt-get update
apt-get install -y dnsutils curl jq openssl
```

Open only the ports you need:

```text
53/tcp and 53/udp     Authoritative DNS
8081/tcp              PowerDNS API and webserver
8080/tcp              Poweradmin HTTP
5432/tcp              PostgreSQL, only for replica nodes
80/tcp and 443/tcp    Optional Poweradmin HTTPS overlay
```

## Fresh installation

Unpack the repository:

```bash
unzip pdns-geo-postgres-stack-lua.zip
cd pdns-geo-postgres-stack
```

Create `.env`. You can either copy the example manually:

```bash
cp .env.example .env
nano .env
```

Or generate random secrets first:

```bash
chmod +x scripts/*.sh examples/api/*.sh
./scripts/bootstrap.sh
nano .env
```

Change every production secret and every public address. At minimum, edit:

```env
POSTGRES_SUPERUSER_PASSWORD=change-this
PDNS_DB_PASSWORD=change-this
POWERADMIN_DB_PASSWORD=change-this
REPLICATION_PASSWORD=change-this
PDNS_API_KEY=change-this
PDNS_WEBSERVER_PASSWORD=change-this
PA_ADMIN_PASSWORD=change-this
PA_SESSION_KEY=change-this

DNS_BASE_DOMAIN=example.com
DNS_NS1=ns1.example.com
DNS_NS2=ns2.example.com
DNS_NS3=ns3.example.com
DNS_HOSTMASTER=hostmaster.example.com

NS1_IPV4=YOUR_NS1_IPV4
NS2_IPV4=YOUR_NS2_IPV4
NS3_IPV4=YOUR_NS3_IPV4
NS1_IPV6=
NS2_IPV6=
NS3_IPV6=
```

Set the default Lua example targets if you keep `SEED_LUA_EXAMPLES=true`:

```env
SEED_LUA_EXAMPLES=true
LUA_GEO_DEFAULT_IPV4=YOUR_DEFAULT_ORIGIN_IPV4
LUA_GEO_EU_IPV4=YOUR_EU_ORIGIN_IPV4
LUA_GEO_NA_IPV4=YOUR_NA_ORIGIN_IPV4
LUA_GEO_AS_IPV4=YOUR_ASIA_ORIGIN_IPV4
LUA_GEO_HEALTH_PORT=443
```

If you do not want example Lua records seeded on first boot:

```env
SEED_LUA_EXAMPLES=false
```

If PostgreSQL replica nodes will connect to this primary, include the primary server IP or DNS name in `PG_TLS_SAN` before first boot. PostgreSQL certificates are generated only when the TLS files do not already exist.

```env
PG_TLS_SAN=DNS:postgres,DNS:pdns-postgres-primary,DNS:ns1.example.com,DNS:ns2.example.com,DNS:ns3.example.com,IP:127.0.0.1,IP:YOUR_PRIMARY_SERVER_IP
```

Build and start:

```bash
docker compose build
docker compose up -d
```

With legacy Compose:

```bash
docker-compose build
docker-compose up -d
```

Check status:

```bash
docker compose ps
```

Expected result:

- `pdns-postgres-primary` is healthy.
- `pdns-mmdb-updater` is healthy.
- `pdns-auth` is healthy.
- `poweradmin` is healthy.
- `pdns-db-init` exited with code `0`. This is normal because it is a one-shot initializer.

Run the included checks:

```bash
./scripts/check.sh
```

## Access endpoints

Poweradmin:

```text
http://SERVER-IP:8080
```

PowerDNS API:

```text
http://SERVER-IP:8081/api/v1/servers/localhost
```

Authoritative DNS:

```bash
dig @SERVER-IP example.com SOA +short
dig @SERVER-IP www.lua.example.com A +short
dig @SERVER-IP country-code.lua.example.com TXT +short
```

## How Lua GeoDNS works in this repository

PowerDNS stores a Lua record as DNS type `LUA`. The content starts with the DNS type that will be synthesized.

Example database content:

```text
A ";if continent('EU') then return '203.0.113.40' else return '203.0.113.10' end"
```

A query for `A www.lua.example.com` does not return the Lua source. It returns the synthesized `A` answer.

The stack enables Lua records globally with:

```conf
enable-lua-records=yes
```

The seed zone also gets this metadata:

```text
ENABLE-LUA-RECORDS = 1
```

Keep the PowerDNS API private. Lua records execute server-side logic. Do not expose the API to untrusted users.

## Seeded Lua records

When `SEED_BASE_ZONE=true` and `SEED_LUA_EXAMPLES=true`, the initializer creates these records under `DNS_BASE_DOMAIN`:

```text
www.lua.DOMAIN              LUA A using continent() routing
country.lua.DOMAIN          LUA A using country() routing
closest.lua.DOMAIN          LUA A using pickclosest()
ha.lua.DOMAIN               LUA A using ifportup() with pickclosest selector
country-code.lua.DOMAIN     LUA TXT returning countryCode()
continent-code.lua.DOMAIN   LUA TXT returning continentCode()
```

Query examples:

```bash
dig @127.0.0.1 www.lua.example.com A +short
dig @127.0.0.1 country.lua.example.com A +short
dig @127.0.0.1 closest.lua.example.com A +short
dig @127.0.0.1 ha.lua.example.com A +short
dig @127.0.0.1 country-code.lua.example.com TXT +short
dig @127.0.0.1 continent-code.lua.example.com TXT +short
```

Geo decisions are based on the recursive resolver IP unless EDNS Client Subnet is present and accepted. This repository sets:

```conf
edns-subnet-processing=yes
```

For controlled tests, use a resolver or query path that sends ECS. Plain local `dig @127.0.0.1` normally geolocates as localhost or the resolver address, not the end user.

## PowerDNS API examples with curl and jq

The examples below assume:

```bash
export PDNS_API_BASE="http://127.0.0.1:8081/api/v1/servers/localhost"
export PDNS_API_KEY="$(grep '^PDNS_API_KEY=' .env | cut -d= -f2-)"
export ZONE="example.com."
```

### Create a zone

```bash
curl -fsS -X POST "${PDNS_API_BASE}/zones" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "$ZONE" \
    '{name:$name, kind:"Native", nameservers:["ns1.example.com.","ns2.example.com."]}')" | jq .
```

### Add a basic A record

```bash
curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "www.${ZONE}" \
    --arg ip "203.0.113.10" \
    '{rrsets:[{name:$name,type:"A",ttl:300,changetype:"REPLACE",records:[{content:$ip,disabled:false}]}]}')"
```

### Add a continent-based Lua A record

```bash
LUA='A ";if continent('\''EU'\'') then return '\''203.0.113.40'\'' elseif continent('\''NA'\'') then return '\''203.0.113.50'\'' else return '\''203.0.113.10'\'' end"'

curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "www.lua.${ZONE}" \
    --arg lua "$LUA" \
    '{rrsets:[{name:$name,type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua,disabled:false}]}]}')"
```

### Add a country-based Lua A record

```bash
LUA='A ";if country({'\''NL'\'','\''DE'\'','\''FR'\'','\''GB'\''}) then return '\''203.0.113.40'\'' elseif country({'\''US'\'','\''CA'\''}) then return '\''203.0.113.50'\'' else return '\''203.0.113.10'\'' end"'

curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "country.lua.${ZONE}" \
    --arg lua "$LUA" \
    '{rrsets:[{name:$name,type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua,disabled:false}]}]}')"
```

### Add a closest-node Lua record

```bash
LUA='A "pickclosest({'\''203.0.113.40'\'','\''203.0.113.50'\'','\''203.0.113.30'\'','\''203.0.113.10'\''})"'

curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "closest.lua.${ZONE}" \
    --arg lua "$LUA" \
    '{rrsets:[{name:$name,type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua,disabled:false}]}]}')"
```

### Add health-checked failover with closest selection

```bash
LUA='A "ifportup(443, {{'\''203.0.113.40'\'','\''203.0.113.50'\''}, {'\''203.0.113.10'\''}}, {selector='\''pickclosest'\''})"'

curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "ha.lua.${ZONE}" \
    --arg lua "$LUA" \
    '{rrsets:[{name:$name,type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua,disabled:false}]}]}')"
```

The first query that hits an `ifportup()` or `ifurlup()` record may use fallback behavior because PowerDNS performs health checks in the background.

### Delete a record

```bash
curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "ha.lua.${ZONE}" \
    '{rrsets:[{name:$name,type:"LUA",changetype:"DELETE"}]}')"
```

## Using the included API example scripts

```bash
cd examples/api
cp 00-env.sh.example 00-env.sh
nano 00-env.sh
./01-create-zone.sh
./02-add-basic-records.sh
./03-add-lua-geo-records.sh
./04-query-tests.sh
```

## Poweradmin and Lua records

Poweradmin is useful for ordinary records and zone administration. For Lua records, use the PowerDNS API examples above. Some Poweradmin versions may show `LUA` records, but API control is more predictable because the content contains nested quoting.

## MMDB operation

The default `.env` uses:

```env
MMDB_PROVIDER=dbip-jsdelivr
MMDB_TARGET_FILE=GeoLite2-City.mmdb
```

The downloader stores the file at:

```text
runtime/mmdb/GeoLite2-City.mmdb
```

PowerDNS reads it as:

```text
/var/lib/powerdns/mmdb/GeoLite2-City.mmdb
```

When the MMDB file changes, `pdns-auth` exits cleanly and Docker restarts it. This makes PowerDNS reopen the memory-mapped database.

Supported providers in this repo:

```text
dbip-jsdelivr    Default, no token
dbip-official    DB-IP monthly URL, no token
generic          Use MMDB_DOWNLOAD_URL
ip66             Country/continent/ASN MMDB, no token
ip2location      Legacy token mode
```

## Day-to-day operations

Show containers:

```bash
docker compose ps
```

Follow logs:

```bash
docker compose logs -f postgres
docker compose logs -f db-init
docker compose logs -f mmdb-updater
docker compose logs -f pdns-auth
docker compose logs -f poweradmin
```

Restart one service:

```bash
docker compose restart pdns-auth
docker compose restart poweradmin
```

Rebuild after changing Dockerfiles or entrypoints:

```bash
docker compose build
docker compose up -d
```

Check the PowerDNS API:

```bash
curl -fsS -H "X-API-Key: ${PDNS_API_KEY}" \
  "http://127.0.0.1:${PDNS_API_PORT:-8081}/api/v1/servers/localhost" | jq .
```

List zones:

```bash
curl -fsS -H "X-API-Key: ${PDNS_API_KEY}" \
  "http://127.0.0.1:${PDNS_API_PORT:-8081}/api/v1/servers/localhost/zones" | jq '.[].name'
```

Inspect generated PowerDNS config:

```bash
docker compose exec pdns-auth cat /etc/powerdns/pdns.d/00-local.conf
```

## Backups

Create a database backup:

```bash
mkdir -p backups
docker compose exec -T postgres pg_dump -U postgres -d pdns > backups/pdns-$(date -u +%Y%m%dT%H%M%SZ).sql
```

Restore into a new empty stack only after stopping services that write to the database:

```bash
docker compose stop poweradmin pdns-auth db-init
cat backups/pdns.sql | docker compose exec -T postgres psql -U postgres -d pdns
docker compose up -d
```

Back up TLS material for replicas:

```bash
tar -czf backups/postgres-tls-$(date -u +%Y%m%dT%H%M%SZ).tar.gz runtime/postgres-tls
```

## PostgreSQL replica nodes

Replica nodes use physical streaming replication from the primary PostgreSQL server. DNS nodes should read from their local replica.

On the primary node, first boot must already have generated TLS files:

```bash
ls runtime/postgres-tls
```

Show the files needed by replica nodes:

```bash
./scripts/show-replica-bundle.sh
```

Copy these files to the replica node under `replica/tls`:

```text
ca.crt
replicator.crt
replicator.key
```

On each replica node:

```bash
cd replica
cp .env.example .env
nano .env
mkdir -p tls runtime/mmdb
# copy ca.crt, replicator.crt, and replicator.key into ./tls
docker compose -f docker-compose.dns-node.yml build
docker compose -f docker-compose.dns-node.yml up -d
```

Use a unique replication slot per node:

```env
REPLICATION_SLOT_NAME=nsg_02_replica
```

For another node:

```env
REPLICATION_SLOT_NAME=nsg_03_replica
```

Write DNS changes only on the primary node through primary Poweradmin or the primary PowerDNS API. Replica PostgreSQL nodes are hot standby replicas. The local PowerDNS service on a replica node is read-only because its database is read-only.

## PostgreSQL-only replica

For a database replica without DNS service:

```bash
cd replica
cp .env.example .env
nano .env
docker compose -f docker-compose.replica.yml build
docker compose -f docker-compose.replica.yml up -d
```

## Optional HTTPS for Poweradmin

Set a real FQDN and email:

```env
POWERADMIN_FQDN=dns.example.com
ACME_EMAIL=admin@example.com
```

Make sure the FQDN points to this server and ports 80/tcp and 443/tcp are open.

Start with the HTTPS overlay:

```bash
docker compose -f docker-compose.yml -f docker-compose.https.yml build
docker compose -f docker-compose.yml -f docker-compose.https.yml up -d
```

Poweradmin will be available at:

```text
https://dns.example.com
```

## Troubleshooting

Check first-boot logs:

```bash
docker compose logs db-init
docker compose logs mmdb-updater
docker compose logs pdns-auth
docker compose logs poweradmin
```

If `pdns-auth` waits for MMDB, check:

```bash
docker compose logs mmdb-updater
ls -lh runtime/mmdb
```

If `pdns-auth` waits for PostgreSQL schema, check:

```bash
docker compose logs db-init
docker compose exec postgres psql -U postgres -d pdns -c '\dt'
```

If Lua answers do not vary by location, remember that authoritative DNS usually sees the recursive resolver IP. Use EDNS Client Subnet or test from resolvers in different networks.

If Lua records return no answer, inspect the stored record:

```bash
curl -fsS -H "X-API-Key: ${PDNS_API_KEY}" \
  "http://127.0.0.1:${PDNS_API_PORT:-8081}/api/v1/servers/localhost/zones/${DNS_BASE_DOMAIN}." | jq '.rrsets[] | select(.type=="LUA")'
```

Check PowerDNS runtime config:

```bash
docker compose exec pdns-auth grep -E 'launch=|enable-lua-records|geoip|edns-subnet' /etc/powerdns/pdns.d/00-local.conf
```

Expected lines include:

```conf
launch=gpgsql,geoip
enable-lua-records=yes
geoip-database-files=mmdb:/var/lib/powerdns/mmdb/GeoLite2-City.mmdb
geoip-zones-file=/etc/powerdns/geo/lua-bootstrap.yml
edns-subnet-processing=yes
```

## Notes on API and Lua security

Do not expose port 8081 publicly unless it is behind a strict firewall or VPN. Anyone with the API key can change records. With Lua records enabled, that means they can also change server-side Lua logic.

For production, set:

```env
PDNS_WEBSERVER_ALLOW_FROM=127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,YOUR_ADMIN_IP/32
```

Also firewall port `8081/tcp` at the host or cloud firewall layer.

## Upgrading

Pull or copy the new repository, keep your existing `.env`, then run:

```bash
docker compose build
docker compose up -d
./scripts/check.sh
```

Do not run `docker compose down -v` unless you intentionally want to delete the PostgreSQL data volume.

## References

PowerDNS Lua records:

```text
https://doc.powerdns.com/authoritative/lua-records/
```

PowerDNS Lua functions:

```text
https://doc.powerdns.com/authoritative/lua-records/functions.html
```

PowerDNS HTTP zone API:

```text
https://doc.powerdns.com/authoritative/http-api/zone.html
```

PowerDNS authoritative settings:

```text
https://doc.powerdns.com/authoritative/settings.html
```
