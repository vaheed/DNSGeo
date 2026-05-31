# Replica nodes

This directory contains two replica deployment modes.

## PostgreSQL-only replica

Use `docker-compose.replica.yml` when you only need a physical streaming PostgreSQL replica.

```bash
cd /opt/pdns-postgres-replica
cp .env.example .env
nano .env
docker compose -f docker-compose.replica.yml build
docker compose -f docker-compose.replica.yml up -d
```

If this directory is copied without the full repository, adjust the build context in the compose file.

The primary PostgreSQL server generates the files needed for TLS replication:

```text
runtime/postgres-tls/ca.crt
runtime/postgres-tls/replicator/replicator.crt
runtime/postgres-tls/replicator/replicator.key
```

Copy them into `replica/tls` on the replica node:

```text
replica/tls/ca.crt
replica/tls/replicator.crt
replica/tls/replicator.key
```

Use a unique replication slot per replica:

```env
REPLICATION_SLOT_NAME=nsg_02_replica
```

## Full DNS node with local PostgreSQL replica

Use `docker-compose.dns-node.yml` when the node should answer authoritative DNS from a local replicated PostgreSQL database.

```bash
cd /opt/pdns-geo-postgres-stack/replica
cp .env.example .env
nano .env
mkdir -p tls runtime/mmdb
# copy ca.crt, replicator.crt, and replicator.key into ./tls
docker compose -f docker-compose.dns-node.yml build
docker compose -f docker-compose.dns-node.yml up -d
```

The DNS node runs the same Lua-capable PowerDNS image as the primary. It loads:

```conf
launch=gpgsql,geoip
enable-lua-records=yes
geoip-zones-file=/etc/powerdns/geo/lua-bootstrap.yml
```

The GeoIP YAML file is empty. Lua records are replicated through PostgreSQL because they are stored in the `records` table as type `LUA`.

Write DNS changes only on the primary node through primary Poweradmin or the primary PowerDNS API. Replica DNS nodes use PostgreSQL hot standby and are read-only.
