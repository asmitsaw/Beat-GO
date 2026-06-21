-- ══════════════════════════════════════════════════════════════════════════
-- SUPABASE RECOMMENDATIONS SETUP
-- Run this in your Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. User Preferences Table ─────────────────────────────────────────────
-- Stores onboarding choices for each user

CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  languages     TEXT[]    DEFAULT '{}',
  singers       TEXT[]    DEFAULT '{}',
  moods         TEXT[]    DEFAULT '{}',
  onboarding_done BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Users can only read/write their own preferences
CREATE POLICY "Users can view own preferences"
  ON public.user_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON public.user_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON public.user_preferences FOR UPDATE
  USING (auth.uid() = user_id);

-- ── 2. Song Recommendations Table ─────────────────────────────────────────
-- Seeded from production_song_recommendations.json
-- Key format: "song_name||language" (all lowercase)

CREATE TABLE IF NOT EXISTS public.song_recommendations (
  id              BIGSERIAL PRIMARY KEY,
  song_key        TEXT NOT NULL UNIQUE,  -- "song_name||language"
  song_name       TEXT NOT NULL,
  language        TEXT NOT NULL,
  recommendations JSONB NOT NULL DEFAULT '[]',
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_song_recommendations_key
  ON public.song_recommendations (song_key);

CREATE INDEX IF NOT EXISTS idx_song_recommendations_language
  ON public.song_recommendations (language);

-- Enable Row Level Security (public read)
ALTER TABLE public.song_recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read song recommendations"
  ON public.song_recommendations FOR SELECT
  USING (true);

-- ── 3. Supabase Storage Bucket (manual step) ──────────────────────────────
-- 1. Go to Supabase Dashboard → Storage
-- 2. Create a new bucket named: ml-data
-- 3. Set bucket to PUBLIC
-- 4. Upload your production_song_recommendations.json file to this bucket
-- 5. The file URL will be:
--    https://<YOUR_PROJECT_ID>.supabase.co/storage/v1/object/public/ml-data/production_song_recommendations.json

-- ── 4. Seed Script (Python) ───────────────────────────────────────────────
-- Run this Python script ONCE to populate the song_recommendations table
-- from your JSON file. This avoids 114MB HTTP fetches at runtime.

/*
  PYTHON SEED SCRIPT (run once):

  import json
  from supabase import create_client

  url = "https://silfunnzqycdimckeryu.supabase.co"
  key = "<YOUR_SERVICE_ROLE_KEY>"  # Use service role key for seeding
  supabase = create_client(url, key)

  with open("production_song_recommendations.json", "r", encoding="utf-8") as f:
      data = json.load(f)

  batch = []
  for song_key, recs in data.items():
      parts = song_key.split("||")
      song_name = parts[0] if len(parts) > 0 else ""
      language  = parts[1] if len(parts) > 1 else ""
      batch.append({
          "song_key":        song_key,
          "song_name":       song_name,
          "language":        language,
          "recommendations": recs[:20]  # store top 20 only
      })
      if len(batch) >= 100:
          supabase.table("song_recommendations").upsert(batch).execute()
          batch = []
          print(f"Inserted batch...")

  if batch:
      supabase.table("song_recommendations").upsert(batch).execute()
  print("Done! All songs seeded.")
*/

-- ── 5. Updated_at trigger ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_preferences_updated_at
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
