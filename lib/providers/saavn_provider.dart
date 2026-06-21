import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../models/album_model.dart';
import '../services/saavn_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Singleton service provider
// ══════════════════════════════════════════════════════════════════════════════

final saavnServiceProvider = Provider<SaavnService>((_) => SaavnService());

// ══════════════════════════════════════════════════════════════════════════════
// Trending & New Releases (home screen)
// ══════════════════════════════════════════════════════════════════════════════

final saavnTrendingProvider = FutureProvider<List<SongModel>>((ref) async {
  return ref.read(saavnServiceProvider).getTrendingSongs(limit: 20);
});

final saavnNewReleasesProvider = FutureProvider<List<SongModel>>((ref) async {
  return ref.read(saavnServiceProvider).getNewReleases(limit: 15);
});

// ══════════════════════════════════════════════════════════════════════════════
// Song Search
// ══════════════════════════════════════════════════════════════════════════════

/// Family provider — keyed by (query, page).
final saavnSongSearchProvider =
    FutureProvider.family<List<SongModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.read(saavnServiceProvider).searchSongs(query, limit: 25);
});

// ══════════════════════════════════════════════════════════════════════════════
// Album Search
// ══════════════════════════════════════════════════════════════════════════════

final saavnAlbumSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.read(saavnServiceProvider).searchAlbums(query, limit: 20);
});

// ══════════════════════════════════════════════════════════════════════════════
// Artist Search
// ══════════════════════════════════════════════════════════════════════════════

final saavnArtistSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.read(saavnServiceProvider).searchArtists(query, limit: 20);
});

// ══════════════════════════════════════════════════════════════════════════════
// Album Detail
// ══════════════════════════════════════════════════════════════════════════════

final saavnAlbumDetailProvider =
    FutureProvider.family<AlbumModel, String>((ref, albumId) async {
  return ref.read(saavnServiceProvider).getAlbum(albumId);
});

// ══════════════════════════════════════════════════════════════════════════════
// Song Suggestions
// ══════════════════════════════════════════════════════════════════════════════

final saavnSuggestionsProvider =
    FutureProvider.family<List<SongModel>, String>((ref, songId) async {
  return ref.read(saavnServiceProvider).getSongSuggestions(songId, limit: 10);
});
