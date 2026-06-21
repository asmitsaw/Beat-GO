class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String mood;
  final String coverUrl;
  final String audioUrl;
  final int durationMs;
  final int playCount;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.genre = '',
    this.mood = '',
    required this.coverUrl,
    required this.audioUrl,
    this.durationMs = 0,
    this.playCount = 0,
  });

  /// Parses a row from the Supabase `songs` table (snake_case keys).
  factory SongModel.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    return SongModel(
      id:         map['id']?.toString() ?? fallbackId ?? '',
      title:      map['title'] ?? 'Unknown Title',
      artist:     map['artist'] ?? 'Unknown Artist',
      album:      map['album'] ?? '',
      genre:      map['genre'] ?? '',
      mood:       map['mood'] ?? '',
      coverUrl:   map['cover_url'] ?? map['coverUrl'] ?? '',
      audioUrl:   map['audio_url'] ?? map['audioUrl'] ?? '',
      durationMs: map['duration_ms'] ?? map['durationMs'] ?? 0,
      playCount:  map['play_count'] ?? map['playCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id':          id,
        'title':       title,
        'artist':      artist,
        'album':       album,
        'genre':       genre,
        'mood':        mood,
        'cover_url':   coverUrl,
        'audio_url':   audioUrl,
        'duration_ms': durationMs,
        'play_count':  playCount,
      };

  SongModel copyWith({
    String? id, String? title, String? artist, String? album,
    String? genre, String? mood, String? coverUrl, String? audioUrl,
    int? durationMs, int? playCount,
  }) {
    return SongModel(
      id:         id ?? this.id,
      title:      title ?? this.title,
      artist:     artist ?? this.artist,
      album:      album ?? this.album,
      genre:      genre ?? this.genre,
      mood:       mood ?? this.mood,
      coverUrl:   coverUrl ?? this.coverUrl,
      audioUrl:   audioUrl ?? this.audioUrl,
      durationMs: durationMs ?? this.durationMs,
      playCount:  playCount ?? this.playCount,
    );
  }
}
