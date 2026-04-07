-- Supabase / PostgreSQL 확장: 인메모리 store 전체를 DB로 옮김 (기존 schema.sql 이후 실행)

-- notification_type 확장
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'play_session_start';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'play_session_spot_open';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'play_session_promoted_from_waitlist';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'lesson_booking_confirmed';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'lesson_booking_request';

-- 즐겨찾기: 사용자 대상
ALTER TYPE favorite_target_type ADD VALUE IF NOT EXISTS 'user';

-- 후기 이미지
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS image_url TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lesson_booking_status') THEN
    CREATE TYPE lesson_booking_status AS ENUM ('pending', 'confirmed', 'cancelled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS user_follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);

CREATE TABLE IF NOT EXISTS direct_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
       text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dm_thread ON direct_messages (from_user_id, to_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  text TEXT NOT NULL,
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_group ON chat_messages (group_id, created_at);

CREATE TABLE IF NOT EXISTS chat_polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  options JSONB NOT NULL,
  votes JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS play_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  host_user_id UUID NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  venue_id UUID NOT NULL REFERENCES venues(id),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  court_count INT NOT NULL CHECK (court_count >= 1 AND court_count <= 20),
  level_min skill_level NOT NULL,
  level_max skill_level NOT NULL,
  max_participants INT NOT NULL CHECK (max_participants >= 2 AND max_participants <= 64),
  participant_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  waitlist_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  default_matching_mode TEXT NOT NULL DEFAULT 'balanced' CHECK (default_matching_mode IN ('random', 'balanced')),
  current_round INT NOT NULL DEFAULT 0,
  rounds JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_play_sessions_group ON play_sessions (group_id, starts_at);
CREATE INDEX IF NOT EXISTS idx_play_sessions_starts ON play_sessions (starts_at);

CREATE TABLE IF NOT EXISTS coach_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  bio TEXT NOT NULL,
  hourly_rate_won INT NOT NULL CHECK (hourly_rate_won >= 0),
  preferred_venue_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lesson_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_user_id UUID NOT NULL REFERENCES users(id),
  student_user_id UUID NOT NULL REFERENCES users(id),
  starts_at TIMESTAMPTZ NOT NULL,
  venue_id UUID REFERENCES venues(id),
  note TEXT,
  status lesson_booking_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (coach_user_id <> student_user_id)
);

CREATE INDEX IF NOT EXISTS idx_lesson_bookings_coach ON lesson_bookings (coach_user_id);
CREATE INDEX IF NOT EXISTS idx_lesson_bookings_student ON lesson_bookings (student_user_id);
