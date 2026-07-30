-- KarmaX Avatar System Supabase Setup

-- Table: avatars
-- Static table containing all available avatar archetypes
CREATE TABLE IF NOT EXISTS avatars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  archetype TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  default_stat TEXT NOT NULL,
  color_hex TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Table: user_avatar_progress
-- Dynamic table tracking each user's avatar selection and progress
CREATE TABLE IF NOT EXISTS user_avatar_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  selected_avatar_id UUID NOT NULL REFERENCES avatars(id),
  current_level INTEGER NOT NULL DEFAULT 1,
  dominant_stat TEXT NOT NULL DEFAULT 'health',
  equipped_badges TEXT[] DEFAULT ARRAY[]::TEXT[],
  last_updated TIMESTAMP NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Seed avatar data
INSERT INTO avatars (name, archetype, description, default_stat, color_hex) VALUES
  ('Noble Knight', 'knight', 'A steadfast warrior, strong in discipline and honor.', 'discipline', '#FFD54F'),
  ('Mystic Sage', 'sage', 'A seeker of knowledge, mastering the arcane arts.', 'knowledge', '#5B7FFF'),
  ('Swift Rogue', 'rogue', 'Quick and cunning, balanced in all aspects.', 'social', '#4ECDC4'),
  ('Steadfast Guardian', 'guardian', 'Protector of wellness, radiating vitality.', 'health', '#FF6B4A'),
  ('Arcane Mage', 'mage', 'Master of mystical forces and transformation.', 'knowledge', '#9D5FFF'),
  ('Natural Druid', 'druid', 'Harmonious with nature, balanced and resilient.', 'health', '#52C977')
ON CONFLICT (archetype) DO NOTHING;

-- Create indexes
CREATE INDEX idx_user_avatar_progress_user_id ON user_avatar_progress(user_id);
CREATE INDEX idx_user_avatar_progress_selected_avatar_id ON user_avatar_progress(selected_avatar_id);
CREATE INDEX idx_avatars_archetype ON avatars(archetype);

-- Enable RLS for security
ALTER TABLE avatars ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_avatar_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Avatars: readable by all authenticated users
CREATE POLICY "avatars_readable_by_authenticated" ON avatars
  FOR SELECT
  TO authenticated
  USING (TRUE);

-- user_avatar_progress: users can only see/edit their own
CREATE POLICY "user_avatar_progress_readable_by_owner" ON user_avatar_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_avatar_progress_writable_by_owner" ON user_avatar_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_avatar_progress_insertable_by_authenticated" ON user_avatar_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Cleanup old records (optional)
-- ALTER TABLE user_avatar_progress
-- ADD CONSTRAINT one_avatar_per_user UNIQUE (user_id);

-- ═══════════════════════════════════════════════════════════════════════
--  KarmaX Core Onboarding & Quest Persistence Tables
-- ═══════════════════════════════════════════════════════════════════════

-- Table: user_state
CREATE TABLE IF NOT EXISTS user_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sleep_hours NUMERIC NOT NULL DEFAULT 7.0,
  study_hours NUMERIC NOT NULL DEFAULT 4.0,
  screen_time_hours NUMERIC NOT NULL DEFAULT 5.0,
  stress_level INTEGER NOT NULL DEFAULT 3,
  physical_activity_hours NUMERIC NOT NULL DEFAULT 1.0,
  social_hours NUMERIC NOT NULL DEFAULT 2.0,
  gpa NUMERIC NOT NULL DEFAULT 3.0,
  emotion TEXT NOT NULL DEFAULT 'Neutral',
  source TEXT NOT NULL DEFAULT 'onboarding',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table: ai_generations
CREATE TABLE IF NOT EXISTS ai_generations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_state_id UUID REFERENCES user_state(id) ON DELETE SET NULL,
  primary_problem TEXT NOT NULL,
  root_cause TEXT NOT NULL,
  reasoning TEXT NOT NULL,
  model_version TEXT NOT NULL DEFAULT 'gemini-3.1-flash-lite',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table: quests
CREATE TABLE IF NOT EXISTS quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  generation_id UUID REFERENCES ai_generations(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  xp_reward INTEGER NOT NULL DEFAULT 10,
  category TEXT NOT NULL DEFAULT 'discipline',
  why TEXT NOT NULL DEFAULT '',
  quest_type TEXT NOT NULL CHECK (quest_type IN ('daily', 'weekly')),
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_state_user_id ON user_state(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_generations_user_id ON ai_generations(user_id);
CREATE INDEX IF NOT EXISTS idx_quests_user_id ON quests(user_id);
CREATE INDEX IF NOT EXISTS idx_quests_generation_id ON quests(generation_id);

-- Enable RLS
ALTER TABLE user_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_generations ENABLE ROW LEVEL SECURITY;
ALTER TABLE quests ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_state, ai_generations, quests
CREATE POLICY "user_state_owner_access" ON user_state
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "ai_generations_owner_access" ON ai_generations
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "quests_owner_access" ON quests
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════
--  KarmaX Persistent AI Cache Table (Shared RAM + DB Hybrid Cache)
-- ═══════════════════════════════════════════════════════════════════════

-- Table: ai_cache
-- Persists generated problem analyses, quizzes, and quests across server restarts.
CREATE TABLE IF NOT EXISTS ai_cache (
  key TEXT PRIMARY KEY,
  payload JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_cache_expires_at ON ai_cache(expires_at);

-- Disable RLS for global shared cache (read-through server cache)
ALTER TABLE ai_cache DISABLE ROW LEVEL SECURITY;
