-- ═══════════════════════════════════════════════════════════════════════
--  KarmaX HCI Study Instrumentation
--  Run this AFTER SUPABASE_SETUP.sql. Adds the tables needed to log the
--  A/B (baseline vs Gestalt) quiz study: condition assignment, per-question
--  timing/revision events, SUS score, and quest-relevance rating.
-- ═══════════════════════════════════════════════════════════════════════

-- Table: hci_sessions
-- One row per quiz attempt ("session"). Created the moment a participant
-- lands on the quiz screen; updated as they finish the SUS survey and rate
-- their generated quests.
CREATE TABLE IF NOT EXISTS hci_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  condition TEXT NOT NULL CHECK (condition IN ('A', 'B')),
  problem_title TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sus_score NUMERIC,
  sus_raw_answers INTEGER[],
  quest_rating INTEGER CHECK (quest_rating BETWEEN 1 AND 5),
  completed_at TIMESTAMPTZ
);

-- Table: hci_question_events
-- One row per (session, question). Tracks when the question was shown,
-- when it was first answered, and how many times the answer was changed
-- (revision count) before moving on.
CREATE TABLE IF NOT EXISTS hci_question_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES hci_sessions(id) ON DELETE CASCADE,
  question_index INTEGER NOT NULL,
  shown_at TIMESTAMPTZ NOT NULL,
  answered_at TIMESTAMPTZ,
  revision_count INTEGER NOT NULL DEFAULT 0,
  UNIQUE (session_id, question_index)
);

CREATE INDEX IF NOT EXISTS idx_hci_sessions_user_id ON hci_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_hci_sessions_condition ON hci_sessions(condition);
CREATE INDEX IF NOT EXISTS idx_hci_question_events_session ON hci_question_events(session_id);

-- Enable RLS
ALTER TABLE hci_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE hci_question_events ENABLE ROW LEVEL SECURITY;

-- ── hci_sessions policies ──────────────────────────────────────────────
-- Participants (any authenticated user) can insert their own session,
-- and read/update only rows tied to their own user_id.
CREATE POLICY "hci_sessions_insert_own" ON hci_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "hci_sessions_select_own" ON hci_sessions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "hci_sessions_update_own" ON hci_sessions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR user_id IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- ── hci_question_events policies ───────────────────────────────────────
-- Access is scoped through the parent session's ownership.
CREATE POLICY "hci_question_events_insert" ON hci_question_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM hci_sessions s
      WHERE s.id = session_id AND (s.user_id = auth.uid() OR s.user_id IS NULL)
    )
  );

CREATE POLICY "hci_question_events_select" ON hci_question_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM hci_sessions s
      WHERE s.id = session_id AND (s.user_id = auth.uid() OR s.user_id IS NULL)
    )
  );

CREATE POLICY "hci_question_events_update" ON hci_question_events
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM hci_sessions s
      WHERE s.id = session_id AND (s.user_id = auth.uid() OR s.user_id IS NULL)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM hci_sessions s
      WHERE s.id = session_id AND (s.user_id = auth.uid() OR s.user_id IS NULL)
    )
  );

-- ── Handy analysis views (optional, for pulling results into a paper) ──
-- Per-session summary: total time on quiz, total revisions, question count.
-- ═══════════════════════════════════════════════════════════════════════
--  MIGRATION 2 — richer per-question data for the research paper
--  Run this block even if you already ran the section above; every
--  statement here is additive/idempotent (ADD COLUMN IF NOT EXISTS,
--  CREATE OR REPLACE VIEW), so it's safe on both a fresh and an existing
--  database.
-- ═══════════════════════════════════════════════════════════════════════

-- Per-question: which answer was actually chosen, when it was last
-- changed, and how many times the participant navigated BACK to this
-- question after having moved past it ("backtracking").
ALTER TABLE hci_question_events
  ADD COLUMN IF NOT EXISTS selected_option_index INTEGER,
  ADD COLUMN IF NOT EXISTS answer_text TEXT,
  ADD COLUMN IF NOT EXISTS last_modified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS backtrack_count INTEGER NOT NULL DEFAULT 0;

-- Session-level: when the quiz portion itself finished (before the SUS
-- survey), so quiz duration can be computed independently of how long
-- someone takes on the survey afterwards.
ALTER TABLE hci_sessions
  ADD COLUMN IF NOT EXISTS quiz_finished_at TIMESTAMPTZ;

-- ── Formulas this view computes (cite these directly in the paper) ────────
--   decision latency (question i)  = answered_at_i − shown_at_i        (s)
--   active time on question (i)    = last_modified_at_i − shown_at_i   (s)
--   revision rate (session)        = Σ revision_count  / n_questions
--   backtrack rate (session)       = Σ backtrack_count / n_questions
--   quiz duration (session)        = quiz_finished_at − started_at     (s)
--   SUS score                      = standard Brooke (1996) formula,
--                                     computed client-side and stored in
--                                     hci_sessions.sus_score directly
CREATE OR REPLACE VIEW hci_session_summary AS
SELECT
  s.id AS session_id,
  s.condition,
  s.problem_title,
  s.sus_score,
  s.quest_rating,
  COUNT(e.id) AS questions_logged,
  SUM(e.revision_count) AS total_revisions,
  SUM(e.backtrack_count) AS total_backtracks,
  SUM(e.revision_count)::NUMERIC / NULLIF(COUNT(e.id), 0)
    AS revision_rate,
  SUM(e.backtrack_count)::NUMERIC / NULLIF(COUNT(e.id), 0)
    AS backtrack_rate,
  AVG(EXTRACT(EPOCH FROM (e.answered_at - e.shown_at)))
    FILTER (WHERE e.answered_at IS NOT NULL)
    AS avg_decision_latency_seconds,
  AVG(EXTRACT(EPOCH FROM (e.last_modified_at - e.shown_at)))
    FILTER (WHERE e.last_modified_at IS NOT NULL)
    AS avg_active_time_seconds,
  EXTRACT(EPOCH FROM (s.quiz_finished_at - s.started_at))
    AS quiz_duration_seconds,
  s.started_at,
  s.quiz_finished_at,
  s.completed_at
FROM hci_sessions s
LEFT JOIN hci_question_events e ON e.session_id = s.id
GROUP BY s.id;

-- Per-question detail view — handy for auditing individual answers/timings
-- or for a qualitative walkthrough of a specific participant's attempt.
CREATE OR REPLACE VIEW hci_question_detail AS
SELECT
  e.session_id,
  s.condition,
  e.question_index,
  e.selected_option_index,
  e.answer_text,
  e.shown_at,
  e.answered_at,
  e.last_modified_at,
  EXTRACT(EPOCH FROM (e.answered_at - e.shown_at)) AS decision_latency_seconds,
  EXTRACT(EPOCH FROM (e.last_modified_at - e.shown_at)) AS active_time_seconds,
  e.revision_count,
  e.backtrack_count
FROM hci_question_events e
JOIN hci_sessions s ON s.id = e.session_id
ORDER BY e.session_id, e.question_index;

