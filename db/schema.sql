-- PostgreSQL migration draft for MVP
-- Scope: User, Venue, Group, Event, Membership, Notification

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'social_provider') THEN
    CREATE TYPE social_provider AS ENUM ('kakao', 'naver', 'google');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'skill_level') THEN
    CREATE TYPE skill_level AS ENUM ('beginner', 'intermediate', 'advanced');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('member', 'host', 'admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'group_status') THEN
    CREATE TYPE group_status AS ENUM ('recruiting', 'closed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'membership_role') THEN
    CREATE TYPE membership_role AS ENUM ('member', 'manager');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'membership_status') THEN
    CREATE TYPE membership_status AS ENUM ('applied', 'approved', 'rejected', 'expired');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
    CREATE TYPE notification_type AS ENUM (
      'membership_approved',
      'membership_rejected',
      'membership_expired',
      'event_updated'
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'favorite_target_type') THEN
    CREATE TYPE favorite_target_type AS ENUM ('venue', 'group');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'review_target_type') THEN
    CREATE TYPE review_target_type AS ENUM ('venue', 'group');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lightning_status') THEN
    CREATE TYPE lightning_status AS ENUM ('open', 'full', 'closed');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  nickname TEXT NOT NULL,
  photo_url TEXT,
  skill_level skill_level NOT NULL DEFAULT 'beginner',
  preferred_area TEXT,
  preferred_time_slots JSONB,
  role user_role NOT NULL DEFAULT 'member',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url TEXT;

CREATE TABLE IF NOT EXISTS social_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider social_provider NOT NULL,
  provider_user_id TEXT NOT NULL,
  email TEXT,
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (provider, provider_user_id)
);

CREATE TABLE IF NOT EXISTS account_merge_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES users(id),
  to_user_id UUID NOT NULL REFERENCES users(id),
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (from_user_id <> to_user_id)
);

CREATE TABLE IF NOT EXISTS venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  court_count INT NOT NULL DEFAULT 1 CHECK (court_count > 0),
  open_hours JSONB,
  amenities JSONB,
  rating_avg NUMERIC(3, 2) NOT NULL DEFAULT 0.00 CHECK (rating_avg >= 0 AND rating_avg <= 5),
  review_count INT NOT NULL DEFAULT 0 CHECK (review_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  host_user_id UUID NOT NULL REFERENCES users(id),
  home_venue_id UUID REFERENCES venues(id),
  photo_url TEXT,
  description TEXT,
  level_min skill_level NOT NULL DEFAULT 'beginner',
  level_max skill_level NOT NULL DEFAULT 'advanced',
  max_members INT NOT NULL CHECK (max_members > 0),
  requires_approval BOOLEAN NOT NULL DEFAULT TRUE,
  membership_policy JSONB,
  status group_status NOT NULL DEFAULT 'recruiting',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (
    (level_min = 'beginner' AND level_max IN ('beginner', 'intermediate', 'advanced'))
    OR (level_min = 'intermediate' AND level_max IN ('intermediate', 'advanced'))
    OR (level_min = 'advanced' AND level_max = 'advanced')
  )
);

ALTER TABLE groups ADD COLUMN IF NOT EXISTS photo_url TEXT;

CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  venue_id UUID NOT NULL REFERENCES venues(id),
  title TEXT NOT NULL,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  fee INT NOT NULL DEFAULT 0 CHECK (fee >= 0),
  capacity INT NOT NULL CHECK (capacity > 0),
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (end_at > start_at)
);

CREATE TABLE IF NOT EXISTS memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  role membership_role NOT NULL DEFAULT 'member',
  status membership_status NOT NULL,
  request_message TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  decided_at TIMESTAMPTZ,
  decided_by UUID REFERENCES users(id),
  UNIQUE (user_id, group_id)
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type notification_type NOT NULL,
  payload JSONB NOT NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type favorite_target_type NOT NULL,
  target_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, target_type, target_id)
);

CREATE TABLE IF NOT EXISTS lightning_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_user_id UUID NOT NULL REFERENCES users(id),
  venue_id UUID NOT NULL REFERENCES venues(id),
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  capacity INT NOT NULL CHECK (capacity >= 2),
  level skill_level NOT NULL,
  note TEXT,
  status lightning_status NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (end_at > start_at)
);

CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_user_id UUID NOT NULL REFERENCES users(id),
  target_type review_target_type NOT NULL,
  target_id UUID NOT NULL,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_venues_geo ON venues (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_groups_home_venue ON groups (home_venue_id);
CREATE INDEX IF NOT EXISTS idx_groups_status ON groups (status);
CREATE INDEX IF NOT EXISTS idx_events_group_start ON events (group_id, start_at);
CREATE INDEX IF NOT EXISTS idx_memberships_group_status ON memberships (group_id, status);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_social_accounts_user_id ON social_accounts (user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lightning_venue_start ON lightning_matches (venue_id, start_at);
CREATE INDEX IF NOT EXISTS idx_reviews_target ON reviews (target_type, target_id, created_at DESC);

-- Optional helper view for current group member counts
CREATE OR REPLACE VIEW group_member_counts AS
SELECT
  group_id,
  COUNT(*) FILTER (WHERE status = 'approved')::INT AS approved_member_count
FROM memberships
GROUP BY group_id;
