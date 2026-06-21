import 'dart:convert';

// ══════════════════════════════════════════════════════════════════════════════
// UserPreferences — stores the onboarding selections
// ══════════════════════════════════════════════════════════════════════════════

class UserPreferences {
  final List<String> languages;   // e.g. ['Hindi', 'Punjabi', 'Tamil']
  final List<String> singers;     // e.g. ['Arijit Singh', 'Shreya Ghoshal']
  final List<String> moods;       // e.g. ['Energetic', 'Romantic']
  final bool onboardingDone;

  const UserPreferences({
    this.languages     = const [],
    this.singers       = const [],
    this.moods         = const [],
    this.onboardingDone = false,
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return UserPreferences(
      languages:      parseList(map['languages']),
      singers:        parseList(map['singers']),
      moods:          parseList(map['moods']),
      onboardingDone: map['onboarding_done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'languages':      languages,
        'singers':        singers,
        'moods':          moods,
        'onboarding_done': onboardingDone,
      };

  // For SharedPreferences (flat JSON string)
  String toJson() => jsonEncode(toMap());

  factory UserPreferences.fromJson(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      return UserPreferences.fromMap(map);
    } catch (_) {
      return const UserPreferences();
    }
  }

  UserPreferences copyWith({
    List<String>? languages,
    List<String>? singers,
    List<String>? moods,
    bool? onboardingDone,
  }) {
    return UserPreferences(
      languages:      languages      ?? this.languages,
      singers:        singers        ?? this.singers,
      moods:          moods          ?? this.moods,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  bool get isEmpty => languages.isEmpty && singers.isEmpty && moods.isEmpty;
}

// ── Recommendation item returned from the JSON lookup ──────────────────────

class SongRecommendation {
  final String songName;
  final String singer;
  final String language;
  final double score;

  const SongRecommendation({
    required this.songName,
    required this.singer,
    required this.language,
    required this.score,
  });

  factory SongRecommendation.fromMap(Map<String, dynamic> map) {
    return SongRecommendation(
      songName: map['song_name']?.toString() ?? '',
      singer:   map['singer']?.toString()    ?? '',
      language: map['language']?.toString()  ?? '',
      score:    (map['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'song_name': songName,
        'singer':    singer,
        'language':  language,
        'score':     score,
      };
}
