#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/runtime/postgres-tls/replicator"

if [ ! -s "$bundle_dir/ca.crt" ] || [ ! -s "$bundle_dir/replicator.crt" ] || [ ! -s "$bundle_dir/replicator.key" ]; then
  echo "Replication TLS bundle not found. Start the primary stack first."
  exit 1
fi

echo "Replication TLS bundle: $bundle_dir"
ls -l "$bundle_dir"
