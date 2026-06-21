import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_preferences_model.dart';
import '../models/song_model.dart';
import '../services/recommendations_service.dart';
import '../services/music_service.dart';
// ══════════════════════════════════════════════════════════════════════════════
// Onboarding Status
// ══════════════════════════════════════════════════════════════════════════════

/// True if the user has completed the music preferences onboarding
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(recommendationsServiceProvider);
  return service.isOnboardingDone();
});

// ══════════════════════════════════════════════════════════════════════════════
// User Preferences — AsyncNotifier for full CRUD
// ══════════════════════════════════════════════════════════════════════════════

class UserPreferencesNotifier extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() async {
    final service = ref.read(recommendationsServiceProvider);
    return service.getUserPreferences();
  }

  Future<void> savePreferences(UserPreferences prefs) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(recommendationsServiceProvider);
      await service.saveUserPreferences(prefs);
      state = AsyncData(prefs);
      // Invalidate onboarding flag
      ref.invalidate(onboardingDoneProvider);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final service = ref.read(recommendationsServiceProvider);
    state = AsyncData(await service.getUserPreferences());
  }
}

final userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesNotifier, UserPreferences>(
        UserPreferencesNotifier.new);

// ══════════════════════════════════════════════════════════════════════════════
// "For You" Recommendations Feed
// ══════════════════════════════════════════════════════════════════════════════

final forYouRecommendationsProvider =
    FutureProvider<List<SongModel>>((ref) async {
  final service = ref.read(recommendationsServiceProvider);
  // Re-run when preferences change
  ref.watch(userPreferencesProvider);
  return service.getProperSaavnRecommendations(limit: 20);
});

// ══════════════════════════════════════════════════════════════════════════════
// Per-Language Recommendations
// ══════════════════════════════════════════════════════════════════════════════

final languageRecommendationsProvider =
    FutureProvider.family<List<SongModel>, String>((ref, language) async {
  final service = ref.read(recommendationsServiceProvider);
  return service.getLanguageSaavnRecommendations(language, limit: 10);
});


// ══════════════════════════════════════════════════════════════════════════════
// Because You Liked — recommendations based on a specific song
// ══════════════════════════════════════════════════════════════════════════════

final songRecommendationsProvider =
    FutureProvider.family<List<SongModel>, String>((ref, songId) async {
  final service = ref.read(musicServiceProvider);
  return service.fetchSuggestions(songId);
});
