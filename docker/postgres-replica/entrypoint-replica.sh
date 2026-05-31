#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "postgres" ] || [ "${1:-}" = "" ] || [ "${1:0:1}" = "-" ]; then
  : "${PGDATA:?PGDATA is required}"
  : "${PRIMARY_HOST:?PRIMARY_HOST is required}"
  : "${REPLICATION_PASSWORD:?REPLICATION_PASSWORD is required}"

  PRIMARY_PORT="${PRIMARY_PORT:-5432}"
  REPLICATION_USER="${REPLICATION_USER:-replicator}"
  REPLICATION_SLOT_NAME="${REPLICATION_SLOT_NAME:-replica_$(hostname | tr '-' '_')}"
  REPLICA_CREATE_SLOT="${REPLICA_CREATE_SLOT:-true}"
  REPLICATION_SSLMODE="${REPLICATION_SSLMODE:-verify-ca}"
  TLS_DIR="${TLS_DIR:-/tls}"
  EFFECTIVE_TLS_DIR="/tmp/replica-tls"

  configure_replica_server() {
    mkdir -p "$PGDATA/conf.d"
    cat > "$PGDATA/conf.d/99-pdns-replica-local.conf" <<'EOF_CONF'
# Local settings for a read-only PostgreSQL replica serving local PowerDNS nodes.
# Streaming from the primary still uses TLS through primary_conninfo.
listen_addresses = '*'
hot_standby = on
ssl = off
EOF_CONF

    cat > "$PGDATA/pg_hba.conf" <<'EOF_HBA'
# Local administrative access inside the replica container.
local   all             all                                     trust

# Application access to this read-only replica. Restrict port 5432 with a firewall.
host    all             all             0.0.0.0/0               scram-sha-256
host    all             all             ::/0                    scram-sha-256
EOF_HBA

    chown -R postgres:postgres "$PGDATA/conf.d" "$PGDATA/pg_hba.conf" "$PGDATA/postgresql.conf"
  }

  if [ ! -s "$TLS_DIR/ca.crt" ] || [ ! -s "$TLS_DIR/replicator.crt" ] || [ ! -s "$TLS_DIR/replicator.key" ]; then
    echo "[postgres-replica] TLS bundle is incomplete in ${TLS_DIR}" >&2
    exit 1
  fi

  rm -rf "$EFFECTIVE_TLS_DIR"
  mkdir -p "$EFFECTIVE_TLS_DIR"
  cp "$TLS_DIR/ca.crt" "$TLS_DIR/replicator.crt" "$TLS_DIR/replicator.key" "$EFFECTIVE_TLS_DIR/"
  chown -R postgres:postgres "$EFFECTIVE_TLS_DIR"
  chmod 700 "$EFFECTIVE_TLS_DIR"
  chmod 644 "$EFFECTIVE_TLS_DIR/ca.crt" "$EFFECTIVE_TLS_DIR/replicator.crt"
  chmod 600 "$EFFECTIVE_TLS_DIR/replicator.key"

  if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "[postgres-replica] initializing read-only replica from ${PRIMARY_HOST}:${PRIMARY_PORT}"
    rm -rf "$PGDATA"/*
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"

    conninfo="host=${PRIMARY_HOST} port=${PRIMARY_PORT} user=${REPLICATION_USER} sslmode=${REPLICATION_SSLMODE} sslrootcert=${EFFECTIVE_TLS_DIR}/ca.crt sslcert=${EFFECTIVE_TLS_DIR}/replicator.crt sslkey=${EFFECTIVE_TLS_DIR}/replicator.key"
    export PGPASSWORD="$REPLICATION_PASSWORD"

    until gosu postgres pg_isready -d "$conninfo" >/dev/null 2>&1; do
      echo "[postgres-replica] waiting for primary"
      sleep 5
    done

    basebackup_args=(
      -D "$PGDATA"
      -Fp
      -Xs
      -P
      -R
      -d "$conninfo"
    )

    case "${REPLICA_CREATE_SLOT,,}" in
      true|1|yes|on)
        basebackup_args+=(-C -S "$REPLICATION_SLOT_NAME")
        ;;
    esac

    gosu postgres pg_basebackup "${basebackup_args[@]}"
  fi

  configure_replica_server
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
