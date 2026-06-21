import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/supabase_client.dart';
import '../models/user_preferences_model.dart';
import '../models/song_model.dart';
import 'saavn_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// RecommendationsService
// Handles:
//   1. Saving / loading user music preferences (Supabase + SharedPrefs cache)
//   2. Querying the ML recommendation lookup (Supabase Storage JSON)
// ══════════════════════════════════════════════════════════════════════════════

class RecommendationsService {
  static const _kPrefsKey       = 'user_music_preferences';
  static const _kOnboardingKey  = 'onboarding_done';

  // ── Shared Preferences ────────────────────────────────────────────────────

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingKey) ?? false;
  }

  Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
  }

  // ── User Preferences CRUD ─────────────────────────────────────────────────

  /// Load preferences: try Supabase first, fall back to SharedPrefs cache
  Future<UserPreferences> getUserPreferences() async {
    // 1. Try local cache
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kPrefsKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        return UserPreferences.fromJson(cached);
      } catch (_) {}
    }

    // 2. Try Supabase
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        final rows = await supabase
            .from('user_preferences')
            .select()
            .eq('user_id', uid)
            .limit(1);
        final list = rows as List;
        if (list.isNotEmpty) {
          final up = UserPreferences.fromMap(list.first as Map<String, dynamic>);
          // Cache locally
          await prefs.setString(_kPrefsKey, up.toJson());
          return up;
        }
      }
    } catch (_) {}

    return const UserPreferences();
  }

  /// Save preferences to both Supabase and SharedPrefs
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    // 1. SharedPrefs cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, preferences.toJson());
    await prefs.setBool(_kOnboardingKey, preferences.onboardingDone);

    // 2. Supabase upsert
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        final data = {
          'user_id': uid,
          ...preferences.toMap(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        await supabase.from('user_preferences').upsert(data,
            onConflict: 'user_id');
      }
    } catch (e) {
      // Non-critical: local cache is the source of truth
    }
  }

  /// Clear all preferences (for sign-out or reset)
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
    await prefs.remove(_kOnboardingKey);
  }

  // ── ML Recommendation Lookup ───────────────────────────────────────────────

  /// Look up recommendations for a specific song by name and language.
  /// Returns top [limit] recommendations sorted by score descending.
  ///
  /// Strategy:
  /// 1. Try Supabase `song_recommendations` table (seeded from JSON)
  /// 2. Fall back to fetching a single entry from Supabase Storage JSON
  Future<List<SongRecommendation>> getRecommendationsForSong({
    required String songName,
    required String language,
    int limit = 10,
  }) async {
    final key = '${songName.toLowerCase()}||${language.toLowerCase()}';

    // 1. Try Supabase table first (fastest)
    try {
      final rows = await supabase
          .from('song_recommendations')
          .select()
          .eq('song_key', key)
          .limit(1);
      final list = rows as List;
      if (list.isNotEmpty) {
        final rec = list.first as Map<String, dynamic>;
        final dynamic rawRecs = rec['recommendations'];
        final List<dynamic> recommendations = rawRecs is String
            ? jsonDecode(rawRecs) as List
            : (rawRecs as List? ?? []);
        return recommendations
            .take(limit)
            .map((e) => SongRecommendation.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // 2. No DB row found — return empty (JSON is 114MB, not practical to fetch fully)
    return [];
  }

  /// Generate a "For You" recommendations feed based on user preferences.
  /// Uses the user's preferred languages and singer names to compose a list
  /// of representative songs from the dataset.
  Future<List<SongRecommendation>> getForYouRecommendations({
    int limit = 20,
  }) async {
    final prefs = await getUserPreferences();

    // Try Supabase table for preference-based recommendations
    try {
      final langs = prefs.languages.map((l) => l.toLowerCase()).toList();
      if (langs.isEmpty) {
        // No preferences set — return popular songs
        final rows = await supabase
            .from('song_recommendations')
            .select()
            .limit(limit);
        final list = rows as List;
        if (list.isNotEmpty) {
          return _extractRecsFromRows(list, limit);
        }
        return [];
      }

      // Fetch from preferred languages
      final results = <SongRecommendation>[];
      for (final lang in langs.take(3)) {
        final rows = await supabase
            .from('song_recommendations')
            .select()
            .ilike('song_key', '%||$lang')
            .limit((limit ~/ langs.length.clamp(1, 3)) + 2);
        final list = rows as List;
        results.addAll(_extractRecsFromRows(list, limit ~/ langs.length.clamp(1, 3)));
        if (results.length >= limit) break;
      }
      return results.take(limit).toList();
    } catch (_) {}

    return [];
  }

  List<SongRecommendation> _extractRecsFromRows(
      List<dynamic> rows, int limit) {
    final results = <SongRecommendation>[];
    for (final row in rows) {
      final rec = row as Map<String, dynamic>;
      final dynamic rawRecs = rec['recommendations'];
      final List<dynamic> recommendations = rawRecs is String
          ? jsonDecode(rawRecs) as List
          : (rawRecs as List? ?? []);
      if (recommendations.isNotEmpty) {
        results.add(SongRecommendation.fromMap(
            recommendations.first as Map<String, dynamic>));
      }
      if (results.length >= limit) break;
    }
    return results;
  }

  /// Get songs from the same language as the user's preferences
  Future<List<SongRecommendation>> getLanguageBasedRecommendations(
      String language, {int limit = 10}) async {
    try {
      final rows = await supabase
          .from('song_recommendations')
          .select()
          .ilike('song_key', '%||${language.toLowerCase()}')
          .limit(limit * 2);
      final list = rows as List;
      if (list.isNotEmpty) {
        return _extractRecsFromRows(list, limit);
      }
    } catch (_) {}
    return [];
  }

  /// Fetch proper recommendations from JioSaavn based on user preferences.
  /// Returns a list of playable [SongModel] objects.
  Future<List<SongModel>> getProperSaavnRecommendations({int limit = 20}) async {
    final prefs = await getUserPreferences();
    final saavn = SaavnService();

    final results = <SongModel>[];
    final seenIds = <String>{};

    // 1. Preferred singers
    if (prefs.singers.isNotEmpty) {
      for (final singer in prefs.singers.take(3)) {
        try {
          final songs = await saavn.searchSongs(singer, limit: 6);
          for (final s in songs) {
            if (seenIds.add(s.id)) {
              results.add(s);
            }
          }
        } catch (_) {}
      }
    }

    // 2. Preferred languages
    if (prefs.languages.isNotEmpty) {
      for (final lang in prefs.languages.take(3)) {
        try {
          final songs = await saavn.searchSongs('top $lang songs 2025', limit: 6);
          for (final s in songs) {
            if (seenIds.add(s.id)) {
              results.add(s);
            }
          }
        } catch (_) {}
      }
    }

    // 3. Fallback: trending songs
    if (results.isEmpty) {
      try {
        final trending = await saavn.getTrendingSongs(limit: limit);
        results.addAll(trending);
      } catch (_) {}
    }

    results.shuffle();
    return results.take(limit).toList();
  }

  /// Fetch trending songs for a specific language from JioSaavn.
  Future<List<SongModel>> getLanguageSaavnRecommendations(String language, {int limit = 10}) async {
    try {
      final saavn = SaavnService();
      final songs = await saavn.searchSongs('trending $language', limit: limit);
      return songs;
    } catch (_) {
      return [];
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final recommendationsServiceProvider =
    Provider<RecommendationsService>((_) => RecommendationsService());
