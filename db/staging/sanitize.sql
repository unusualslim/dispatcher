-- Run by bin/staging-refresh right after production is restored into the staging database.
-- Staging has no PDI/Samsara/Twilio/SendGrid/DigitalOcean keys, so nothing can leave it anyway; this keeps the
-- copy quiet and usable on its own.

-- No automated processes run on staging (it has no scheduler), but turn every schedule off in case one is added.
UPDATE automated_process_configs SET schedule = '';

-- Uploaded files stay in production's DigitalOcean Space; staging reads and writes its own local disk instead,
-- so old attachments show as missing rather than erroring.
UPDATE active_storage_blobs SET service_name = 'local';

-- When this copy was taken (shown in the staging banner).
INSERT INTO app_settings (key, value, created_at, updated_at)
VALUES ('staging_refreshed_at', to_char(now() AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH24:MI'), now(), now())
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
