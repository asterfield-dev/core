-- After 022 vido 3 can queue group and inline jobs, fence workers by token
-- and create its own tables on a clean install.

SELECT count(*) = 1 AS lease_token_exists
  FROM information_schema.columns
 WHERE table_schema = 'vido' AND table_name = 'bridge_jobs'
   AND column_name = 'lease_token' AND data_type = 'uuid' AND is_nullable = 'YES'
\gset
\if :lease_token_exists
\else
  DO $$ BEGIN RAISE EXCEPTION 'contract failed: 022_vido_3.sql: expected lease_token_exists to be true'; END $$;
\endif

SELECT pg_get_constraintdef(oid) LIKE '%vido_group%' AND pg_get_constraintdef(oid) LIKE '%vido_inline%'
  AS surfaces_widened
  FROM pg_constraint WHERE conname = 'download_intents_source_surface_check'
\gset
\if :surfaces_widened
\else
  DO $$ BEGIN RAISE EXCEPTION 'contract failed: 022_vido_3.sql: expected surfaces_widened to be true'; END $$;
\endif

SELECT pg_get_constraintdef(oid) LIKE '%vido_group%' AND pg_get_constraintdef(oid) LIKE '%vido_inline%'
       AND pg_get_constraintdef(oid) LIKE '%vido_dm%'
  AS modes_widened
  FROM pg_constraint WHERE conname = 'download_intents_delivery_mode_check'
\gset
\if :modes_widened
\else
  DO $$ BEGIN RAISE EXCEPTION 'contract failed: 022_vido_3.sql: expected modes_widened to be true'; END $$;
\endif

SELECT pg_get_constraintdef(oid) LIKE '%animation%' AND pg_get_constraintdef(oid) LIKE '%live_photo%'
  AS operation_types_widened
  FROM pg_constraint WHERE conname = 'delivery_operations_operation_type_check'
\gset
\if :operation_types_widened
\else
  DO $$ BEGIN RAISE EXCEPTION 'contract failed: 022_vido_3.sql: expected operation_types_widened to be true'; END $$;
\endif

SELECT has_schema_privilege('vido_core', 'vido', 'CREATE')
   AND has_table_privilege('vido_core', 'core.person', 'REFERENCES')
   AND has_table_privilege('vido_core', 'core.chat', 'REFERENCES')
   AND NOT has_table_privilege('vido_core', 'core.person', 'INSERT')
  AS vido_grants
\gset
\if :vido_grants
\else
  DO $$ BEGIN RAISE EXCEPTION 'contract failed: 022_vido_3.sql: expected vido_grants to be true'; END $$;
\endif

SELECT count(*) = 1 AS downloads_kind_exists
  FROM information_schema.columns
 WHERE table_schema = 'vido' AND table_name = 'downloads'
   AND column_name = 'kind' AND data_type = 'text' AND is_nullable = 'YES'
\gset
\if :downloads_kind_exists
\else
  DO $$ BEGIN RAISE EXCEPTION 'contract failed: 022_vido_3.sql: expected downloads_kind_exists to be true'; END $$;
\endif
