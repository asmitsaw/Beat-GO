# Product Requirements Document (PRD): Music Streaming App

## 1. Objective
Build a robust, scalable, and cross-platform music streaming application using **Flutter** for the frontend and **Firebase** for the backend infrastructure. The app aims to provide a seamless audio listening experience with modern aesthetics, playlist management, and social/sharing features.

## 2. Target Audience
- **Casual Listeners:** Users looking for a free or subscription-based app to listen to their favorite tracks, discover new music, and curate personal playlists.
- **Audiophiles:** Users who want high-quality streaming and offline capabilities.

## 3. Technology Stack
### Frontend
- **Framework:** Flutter (Dart) for iOS and Android support from a single codebase.
- **State Management:** Riverpod or BLoC (Recommended for scalability).
- **Audio Engine:** `just_audio` (for advanced audio playback, caching, and background audio) and `audio_service` (for OS-level media notifications/controls).
- **Local Storage:** `shared_preferences` or `hive` (for offline caching and user preferences).

### Backend (Firebase)
- **Authentication:** Firebase Authentication (Email/Password, Google Sign-In, Apple Sign-In).
- **Database:** Cloud Firestore (NoSQL) for storing user profiles, song metadata, playlists, and user preferences.
- **Storage:** Firebase Cloud Storage for hosting raw audio files (`.mp3` or `.aac`) and album art (`.jpg`/`.png`).
- **Push Notifications:** Firebase Cloud Messaging (FCM) to notify users of new releases or app updates.
- **Analytics & Crashlytics:** Firebase Analytics and Crashlytics for usage tracking and stability monitoring.

---

## 4. Core Features & Requirements

### 4.1. User Onboarding & Authentication
- **Sign Up / Log In:** Users can authenticate via Email/Password, Google, or Apple.
- **Profile Creation:** Users can set a username, select preferred genres, and upload a profile picture.
- **Guest Mode:** Allow limited access to browse the catalog without playing full tracks.

### 4.2. Home Dashboard (Discover)
- **Personalized Greeting:** E.g., "Good Morning, [Name]".
- **Recently Played:** Carousel of recently played songs, albums, or playlists.
- **Curated Sections:** 
  - "Top Charts"
  - "New Releases"
  - "Made for You" (based on listening history).

### 4.3. Search & Explore
- **Global Search:** Search by Song Title, Artist Name, Album, or Genre.
- **Browse Categories:** Explore by mood, activity (e.g., Workout, Chill), or genre.

### 4.4. Audio Player
- **Full-Screen Player:** Displays big album art, song title, artist name, and a seek bar.
- **Playback Controls:** Play, Pause, Next, Previous, Shuffle, and Repeat (One/All).
- **Mini-Player:** A persistent player pinned at the bottom of the screen while navigating the app.
- **Background Playback:** Audio continues playing when the app is minimized or the screen is locked.
- **Lock Screen Controls:** Native OS media controls on the lock screen using `audio_service`.

### 4.5. Library & Playlist Management
- **Liked Songs:** A default playlist of tracks the user has "hearted".
- **Custom Playlists:** Users can create, rename, and delete custom playlists.
- **Add to Playlist:** Option to add any track to an existing or new playlist from the player or list view.
- **Offline Downloads:** Users can download tracks or playlists for offline listening (audio files cached securely locally).

### 4.6. Settings & Profile
- **Account Settings:** Manage subscription, change password, or delete account.
- **Audio Quality:** Toggle between streaming qualities (Data Saver vs. High Quality).
- **Storage Management:** View and clear downloaded cache.
- **Dark/Light Mode:** Toggle or inherit from system theme.

---

## 5. Database Schema (Firestore Structure)

### `users` (Collection)
- `uid` (Document ID)
- `email` (String)
- `displayName` (String)
- `photoUrl` (String)
- `likedSongs` (Array of Song IDs)
- `createdAt` (Timestamp)

### `songs` (Collection)
- `songId` (Document ID)
- `title` (String)
- `artist` (String)
- `album` (String)
- `durationMs` (Number)
- `audioUrl` (String - Firebase Storage Link)
- `coverArtUrl` (String - Firebase Storage Link)
- `genre` (String)
- `playCount` (Number)

### `playlists` (Collection)
- `playlistId` (Document ID)
- `ownerId` (String - User ID)
- `title` (String)
- `coverUrl` (String)
- `songs` (Array of Song IDs)
- `isPublic` (Boolean)

---

## 6. Milestones & Implementation Plan

### Phase 1: Foundation (Weeks 1-2)
1. Initialize Flutter app and integrate Firebase base SDKs.
2. Set up Firebase Authentication (UI + Logic).
3. Design and model the Firestore database schema.
4. Upload dummy MP3s and cover art to Firebase Storage and metadata to Firestore.

### Phase 2: Core App & Player (Weeks 3-4)
1. Build the Home screen and fetch/display songs from Firestore.
2. Implement the `just_audio` package for streaming audio from Firebase URIs.
3. Build the Mini Player and Full-Screen Player UI.
4. Integrate `audio_service` for background play and lock-screen controls.

### Phase 3: Features & Polish (Weeks 5-6)
1. Implement Search and filtering functionality.
2. Implement Library / Playlist creation and "Liked Songs".
3. Add offline caching/downloads using `just_audio_background` caching or custom local storage logic.
4. Polish UI/UX, animations, state handling (loading/error states).

## 7. Future Enhancements (Post-MVP)
- **Lyrics Integration:** Syncing lyrics to the current timestamp of the song.
- **Social Sharing:** Share songs/playlists via deep links to WhatsApp/Insta, etc.
- **Podcast Section:** Support for longer form audio and saving playback position.
- **Artist Profiles:** Allow users to view all albums/songs by a specific artist.
