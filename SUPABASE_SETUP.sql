-- ═══════════════════════════════════════════════════════════
-- RETRO BEATS — Supabase Database Setup
-- Run all of these in the Supabase SQL Editor (supabase.com/dashboard)
-- Project: silfunnzqycdimckeryu
-- ═══════════════════════════════════════════════════════════

-- ── 1. SONGS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.songs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT NOT NULL,
  artist       TEXT NOT NULL,
  album        TEXT,
  genre        TEXT,
  mood         TEXT,       -- 'chill' | 'hype' | 'sad' | 'focus'
  audio_url    TEXT NOT NULL,
  cover_url    TEXT NOT NULL,
  duration_ms  INT  DEFAULT 0,
  play_count   INT  DEFAULT 0,
  bpm          INT,
  energy       FLOAT,      -- 0.0 to 1.0
  lyrics_lrc   TEXT,       -- LRC format for synced lyrics (Phase 3)
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Full-text search index
ALTER TABLE public.songs
  ADD COLUMN IF NOT EXISTS fts TSVECTOR
    GENERATED ALWAYS AS (
      to_tsvector('english',
        coalesce(title,'') || ' ' ||
        coalesce(artist,'') || ' ' ||
        coalesce(album,'') || ' ' ||
        coalesce(genre,'')
      )
    ) STORED;

CREATE INDEX IF NOT EXISTS songs_fts_idx ON public.songs USING GIN (fts);

-- Allow anyone to read songs (public catalog)
ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Songs are publicly readable" ON public.songs
  FOR SELECT USING (true);


-- ── 2. PROFILES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username     TEXT UNIQUE,
  display_name TEXT,
  avatar_url   TEXT,
  bio          TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles are publicly readable" ON public.profiles
  FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);


-- Auto-create profile on sign-up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ── 3. PLAYLISTS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.playlists (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title      TEXT NOT NULL,
  cover_url  TEXT,
  is_public  BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.playlists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own playlists" ON public.playlists
  USING (auth.uid() = owner_id);
CREATE POLICY "Public playlists are readable" ON public.playlists
  FOR SELECT USING (is_public = true);


-- ── 4. PLAYLIST SONGS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.playlist_songs (
  playlist_id UUID REFERENCES public.playlists(id) ON DELETE CASCADE,
  song_id     UUID REFERENCES public.songs(id) ON DELETE CASCADE,
  position    INT DEFAULT 0,
  added_at    TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (playlist_id, song_id)
);

ALTER TABLE public.playlist_songs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Playlist songs follow playlist access" ON public.playlist_songs
  USING (
    EXISTS (
      SELECT 1 FROM public.playlists p
      WHERE p.id = playlist_id AND (p.owner_id = auth.uid() OR p.is_public = true)
    )
  );


-- ── 5. LIKED SONGS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.liked_songs (
  uid      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  song_id  UUID REFERENCES public.songs(id) ON DELETE CASCADE,
  liked_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (uid, song_id)
);

ALTER TABLE public.liked_songs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own liked songs" ON public.liked_songs
  USING (auth.uid() = uid);


-- ── 6. LISTEN EVENTS (ML training data — log from Day 1!) ──
CREATE TABLE IF NOT EXISTS public.listen_events (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid                 UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  song_id             UUID REFERENCES public.songs(id) ON DELETE CASCADE,
  duration_listened_ms INT DEFAULT 0,
  listened_at         TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.listen_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own listen events" ON public.listen_events
  USING (auth.uid() = uid);


-- ── 7. SEED DATA (3 mock songs for testing) ───────────────
INSERT INTO public.songs (title, artist, album, genre, mood, audio_url, cover_url, duration_ms)
VALUES
  (
    'Synthwave Neon',
    'The Midnight Rider',
    'Neon Dreams',
    'Electronic',
    'chill',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=600&auto=format&fit=crop',
    180000
  ),
  (
    'Cyberpunk Drive',
    'Vapor Wave',
    'City Lights',
    'Electronic',
    'hype',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=600&auto=format&fit=crop',
    210000
  ),
  (
    'Arcade Dreams',
    'Pixel Pop',
    '8-Bit Fantasies',
    'Electronic',
    'hype',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
    'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=600&auto=format&fit=crop',
    195000
  )
ON CONFLICT DO NOTHING;


-- ── 8. SYNC GROUPS (Multi-device synchronized music party) ──
CREATE TABLE IF NOT EXISTS public.sync_groups (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT UNIQUE NOT NULL,
  host_id               UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  host_name             TEXT NOT NULL,
  current_song          JSONB,
  is_playing            BOOLEAN DEFAULT false,
  position_ms           INT DEFAULT 0,
  playback_timestamp_ms BIGINT DEFAULT 0,
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sync_groups_code_idx ON public.sync_groups(code);

ALTER TABLE public.sync_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sync groups are readable by authenticated users" ON public.sync_groups
  FOR SELECT USING (true);
CREATE POLICY "Host can insert sync groups" ON public.sync_groups
  FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "Host can update own sync groups" ON public.sync_groups
  FOR UPDATE USING (true);
CREATE POLICY "Host can delete own sync groups" ON public.sync_groups
  FOR DELETE USING (auth.uid() = host_id);


-- ── 9. SYNC GROUP QUEUE (Shared Queue) ────────────────────────
CREATE TABLE IF NOT EXISTS public.sync_group_queue (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id      UUID REFERENCES public.sync_groups(id) ON DELETE CASCADE NOT NULL,
  song          JSONB NOT NULL,
  added_by_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  added_by_name TEXT NOT NULL,
  position      INT DEFAULT 0,
  added_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sync_group_queue_group_idx ON public.sync_group_queue(group_id, position);

ALTER TABLE public.sync_group_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sync group queue is readable by all" ON public.sync_group_queue
  FOR SELECT USING (true);
CREATE POLICY "Group members can insert to queue" ON public.sync_group_queue
  FOR INSERT WITH CHECK (true);
CREATE POLICY "Group members can delete from queue" ON public.sync_group_queue
  FOR DELETE USING (true);

