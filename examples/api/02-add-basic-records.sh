#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
. ./00-env.sh

SOA="${NS1} ${HOSTMASTER} 2026052701 3600 900 1209600 300"

curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg zone "$ZONE" \
    --arg ns1 "$NS1" \
    --arg ns2 "$NS2" \
    --arg soa "$SOA" \
    --arg origin "$ORIGIN_IPV4" \
    '{rrsets:[
      {name:$zone,type:"SOA",ttl:300,changetype:"REPLACE",records:[{content:$soa,disabled:false}]},
      {name:$zone,type:"NS",ttl:300,changetype:"REPLACE",records:[{content:$ns1,disabled:false},{content:$ns2,disabled:false}]},
      {name:("www."+$zone),type:"A",ttl:300,changetype:"REPLACE",records:[{content:$origin,disabled:false}]}
    ]}')" | jq .
