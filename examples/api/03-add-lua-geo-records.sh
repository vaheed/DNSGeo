#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
. ./00-env.sh

# API record type is LUA. The content begins with the synthesized DNS type.
LUA_CONTINENT="A \";if continent('EU') then return '${EU_IPV4}' elseif continent('NA') then return '${NA_IPV4}' elseif continent('AS') then return '${AS_IPV4}' else return '${ORIGIN_IPV4}' end\""
LUA_COUNTRY="A \";if country({'NL','DE','FR','GB'}) then return '${EU_IPV4}' elseif country({'US','CA'}) then return '${NA_IPV4}' else return '${ORIGIN_IPV4}' end\""
LUA_CLOSEST="A \"pickclosest({'${EU_IPV4}','${NA_IPV4}','${AS_IPV4}','${ORIGIN_IPV4}'})\""
LUA_HEALTH="A \"ifportup(443, {{'${EU_IPV4}','${NA_IPV4}'}, {'${ORIGIN_IPV4}'}}, {selector='pickclosest'})\""
LUA_COUNTRY_CODE='TXT "countryCode()"'
LUA_CONTINENT_CODE='TXT "continentCode()"'

curl -fsS -X PATCH "${PDNS_API_BASE}/zones/${ZONE}" \
  -H "X-API-Key: ${PDNS_API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg zone "$ZONE" \
    --arg lua_continent "$LUA_CONTINENT" \
    --arg lua_country "$LUA_COUNTRY" \
    --arg lua_closest "$LUA_CLOSEST" \
    --arg lua_health "$LUA_HEALTH" \
    --arg lua_country_code "$LUA_COUNTRY_CODE" \
    --arg lua_continent_code "$LUA_CONTINENT_CODE" \
    '{rrsets:[
      {name:("www.lua."+$zone),type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua_continent,disabled:false}]},
      {name:("country.lua."+$zone),type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua_country,disabled:false}]},
      {name:("closest.lua."+$zone),type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua_closest,disabled:false}]},
      {name:("ha.lua."+$zone),type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua_health,disabled:false}]},
      {name:("country-code.lua."+$zone),type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua_country_code,disabled:false}]},
      {name:("continent-code.lua."+$zone),type:"LUA",ttl:60,changetype:"REPLACE",records:[{content:$lua_continent_code,disabled:false}]}
    ]}')" | jq .
