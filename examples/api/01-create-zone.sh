#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
. ./00-env.sh

curl -fsS -X POST "${PDNS_API_BASE}/zones" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg name "$ZONE" \
    --arg ns1 "$NS1" \
    --arg ns2 "$NS2" \
    '{name:$name, kind:"Native", nameservers:[$ns1,$ns2]}')" | jq .
