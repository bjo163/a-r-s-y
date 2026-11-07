CREATE TABLE IF NOT EXISTS arsy_users (
  id BIGSERIAL PRIMARY KEY,
  display_name VARCHAR(100) NOT NULL,
  email VARCHAR(254) NOT NULL,
  password_hash TEXT NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'superadmin',
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS arsy_users_email_lower_uq
  ON arsy_users (LOWER(email));

CREATE UNIQUE INDEX IF NOT EXISTS arsy_users_single_superadmin_uq
  ON arsy_users (role) WHERE role = 'superadmin' AND status = 'active';

CREATE TABLE IF NOT EXISTS arsy_sessions (
  token_hash CHAR(64) PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES arsy_users(id) ON DELETE CASCADE,
  csrf_token VARCHAR(128) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);

ALTER TABLE arsy_sessions ALTER COLUMN csrf_token TYPE VARCHAR(128);

CREATE INDEX IF NOT EXISTS arsy_sessions_expiry_idx
  ON arsy_sessions (expires_at);

CREATE TABLE IF NOT EXISTS arsy_settings (
  key VARCHAR(100) PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO arsy_settings (key, value)
VALUES ('setup_completed', 'false')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS arsy_audit_events (
  id BIGSERIAL PRIMARY KEY,
  actor_user_id BIGINT REFERENCES arsy_users(id) ON DELETE SET NULL,
  event_type VARCHAR(100) NOT NULL,
  source_ip INET,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS arsy_audit_events_created_idx
  ON arsy_audit_events (created_at DESC);
