-- core :: 022 - Vido 3: groups and inline in the bridge queue, lease token, grants
-- The central migrator owns the transaction; do not add BEGIN/COMMIT here.
--
-- Written with vido 3 (its deploy/core/ held the draft). vido 3.0.0 refuses
-- to start on a core older than this (internal/db.MinCoreVersion).
--
-- Additive only: Python vido 2.6.0 and searchy run unchanged on top of it, so
-- rolling vido back stays one line.
--
-- 1. Every download of vido 3 goes through vido.bridge_jobs: private chats as
--    before, now also groups and vido's own inline mode. The intents those
--    jobs consume name their surface and delivery mode; the CHECKs learn the
--    two new values of each.
-- 2. bridge_jobs.lease_token: a fresh token per claim. Every write of the
--    worker that holds the job checks it, so a worker whose lease expired
--    cannot overwrite the one that took the job over. Python fenced on
--    lease_owner, which is the same string for every claim by one process.
-- 3. delivery_operations.operation_type learns animation (a GIF sent as an
--    animation) and live_photo.
-- 4. Grants a clean install needs and production already has by hand:
--    CREATE on schema vido (vido's own migrations make tables there) and
--    REFERENCES on core.person and core.chat (their foreign keys). vido_test,
--    the role of the test stack, gets the same in its own database, vido_test,
--    and nothing in core; there it also gets SELECT on core.schema_migrations,
--    which vido reads at start (vido_core reads it through core 002).
-- 5. The status panel role ws04web_ro reads every vido table today; tables
--    vido_core creates from now on (media_refs, job_notices) get the same by
--    default.
-- 6. downloads.kind: 'audio' for a delivery of sound. The audio of a video
--    counts against the video's row in vido.videos, so the anchor cannot say
--    it; /stats counted those through vido.audio_requests, which only the old
--    group button wrote. NULL for every row before vido 3 and for any other
--    delivery.
--
-- There is no "notified" column: vido keeps notices in its own table
-- (vido.job_notices, vido migration 011), written in the transaction that
-- ends the job. The trigger of 008 clears the URL a notice needs, and every
-- terminal row Python left would read as not notified.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- 1. Surfaces and delivery modes -------------------------------------------

ALTER TABLE vido.download_intents
  DROP CONSTRAINT IF EXISTS download_intents_source_surface_check,
  ADD CONSTRAINT download_intents_source_surface_check CHECK (source_surface = ANY (ARRAY[
    'searchy_inline'::text, 'searchy_chat'::text, 'searchy_shared'::text, 'searchy_audio'::text,
    'vido_bridge_audio'::text, 'vido_direct'::text, 'vido_group'::text, 'vido_inline'::text
  ]));

ALTER TABLE vido.download_intents
  DROP CONSTRAINT IF EXISTS download_intents_delivery_mode_check,
  ADD CONSTRAINT download_intents_delivery_mode_check CHECK (delivery_mode = ANY (ARRAY[
    'searchy_chat'::text, 'vido_dm'::text, 'vido_group'::text, 'vido_inline'::text
  ]));

-- 2. Lease token -------------------------------------------------------------

ALTER TABLE vido.bridge_jobs ADD COLUMN IF NOT EXISTS lease_token uuid;

COMMENT ON COLUMN vido.bridge_jobs.lease_token IS
  'Token of the current claim; every worker write checks it. NULL when no worker holds the job';

-- 3. Operation types ---------------------------------------------------------

ALTER TABLE vido.delivery_operations
  DROP CONSTRAINT IF EXISTS delivery_operations_operation_type_check,
  ADD CONSTRAINT delivery_operations_operation_type_check CHECK (operation_type = ANY (ARRAY[
    'video'::text, 'photo'::text, 'audio'::text, 'document'::text, 'animation'::text,
    'live_photo'::text, 'media_group'::text, 'text'::text
  ]));

-- 4. Grants for a clean install ---------------------------------------------

GRANT CREATE ON SCHEMA vido TO vido_core;
GRANT REFERENCES ON core.person, core.chat TO vido_core;

DO $$
BEGIN
  IF current_database() = 'vido_test' AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vido_test') THEN
    GRANT CREATE ON SCHEMA vido TO vido_test;
    GRANT REFERENCES ON core.person, core.chat TO vido_test;
    GRANT SELECT ON core.schema_migrations TO vido_test;
  END IF;
END $$;

-- 5. The status panel reads what vido creates -------------------------------

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ws04web_ro') THEN
    GRANT USAGE ON SCHEMA vido TO ws04web_ro;
    ALTER DEFAULT PRIVILEGES FOR ROLE vido_core IN SCHEMA vido GRANT SELECT ON TABLES TO ws04web_ro;
  END IF;
END $$;

-- 6. What a delivery was -----------------------------------------------------

ALTER TABLE vido.downloads ADD COLUMN IF NOT EXISTS kind text;

ALTER TABLE vido.downloads
  DROP CONSTRAINT IF EXISTS downloads_kind_check,
  ADD CONSTRAINT downloads_kind_check CHECK (kind IS NULL OR kind = 'audio');

COMMENT ON COLUMN vido.downloads.kind IS
  '''audio'' for a delivery of sound, also the audio of a video; NULL otherwise and before vido 3';
