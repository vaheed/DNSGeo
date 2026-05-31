
\set ON_ERROR_STOP on

WITH d AS (
  INSERT INTO domains (name, type, account)
  VALUES (LOWER(:'zone'), 'NATIVE', 'bootstrap')
  ON CONFLICT (name) DO UPDATE SET type = EXCLUDED.type
  RETURNING id
), lua_meta AS (
  INSERT INTO domainmetadata (domain_id, kind, content)
  SELECT id, 'ENABLE-LUA-RECORDS', '1' FROM d
  WHERE NOT EXISTS (
    SELECT 1 FROM domainmetadata dm
    WHERE dm.domain_id = d.id
      AND dm.kind = 'ENABLE-LUA-RECORDS'
      AND dm.content = '1'
  )
), records_to_upsert AS (
  SELECT id AS domain_id, LOWER(:'zone') AS name, 'SOA'::varchar(10) AS type, :'soa_content'::varchar(65535) AS content, 300::int AS ttl, NULL::int AS prio, false AS disabled, true AS auth FROM d
  UNION ALL SELECT id, LOWER(:'zone'), 'NS', :'ns1', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'zone'), 'NS', :'ns2', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'zone'), 'NS', :'ns3', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'ns1'), 'A', :'ns1_ipv4', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'ns2'), 'A', :'ns2_ipv4', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'ns3'), 'A', :'ns3_ipv4', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'ns1'), 'AAAA', :'ns1_ipv6', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'ns2'), 'AAAA', :'ns2_ipv6', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER(:'ns3'), 'AAAA', :'ns3_ipv6', 300, NULL, false, true FROM d
  UNION ALL SELECT id, LOWER('www.lua.' || :'zone'), 'LUA', :'lua_www', 60, NULL, false, true FROM d WHERE LOWER(:'seed_lua_examples') IN ('true','1','yes','on')
  UNION ALL SELECT id, LOWER('country.lua.' || :'zone'), 'LUA', :'lua_country', 60, NULL, false, true FROM d WHERE LOWER(:'seed_lua_examples') IN ('true','1','yes','on')
  UNION ALL SELECT id, LOWER('closest.lua.' || :'zone'), 'LUA', :'lua_closest', 60, NULL, false, true FROM d WHERE LOWER(:'seed_lua_examples') IN ('true','1','yes','on')
  UNION ALL SELECT id, LOWER('ha.lua.' || :'zone'), 'LUA', :'lua_ha', 60, NULL, false, true FROM d WHERE LOWER(:'seed_lua_examples') IN ('true','1','yes','on')
  UNION ALL SELECT id, LOWER('country-code.lua.' || :'zone'), 'LUA', :'lua_country_code', 60, NULL, false, true FROM d WHERE LOWER(:'seed_lua_examples') IN ('true','1','yes','on')
  UNION ALL SELECT id, LOWER('continent-code.lua.' || :'zone'), 'LUA', :'lua_continent_code', 60, NULL, false, true FROM d WHERE LOWER(:'seed_lua_examples') IN ('true','1','yes','on')
)
INSERT INTO records (domain_id, name, type, content, ttl, prio, disabled, auth)
SELECT domain_id, name, type, content, ttl, prio, disabled, auth
FROM records_to_upsert r
WHERE NULLIF(BTRIM(r.content), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM records existing
    WHERE existing.domain_id = r.domain_id
      AND existing.name = r.name
      AND existing.type = r.type
      AND existing.content = r.content
  );
