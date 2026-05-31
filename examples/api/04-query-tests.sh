#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
. ./00-env.sh

server="${DNS_SERVER:-127.0.0.1}"
port="${DNS_PORT:-53}"

for name in "www.${ZONE}" "www.lua.${ZONE}" "country.lua.${ZONE}" "closest.lua.${ZONE}" "ha.lua.${ZONE}"; do
  echo "# A $name"
  dig @"$server" -p "$port" "$name" A +short
  echo
done

for name in "country-code.lua.${ZONE}" "continent-code.lua.${ZONE}"; do
  echo "# TXT $name"
  dig @"$server" -p "$port" "$name" TXT +short
  echo
done
