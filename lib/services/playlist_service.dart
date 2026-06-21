import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import 'saavn_service.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final playlistServiceProvider =
    Provider<PlaylistService>((ref) => PlaylistService());

/// Live stream of the current user's playlists.
final userPlaylistsProvider =
    StreamProvider<List<PlaylistModel>>((ref) {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return const Stream.empty();

  return supabase
      .from('playlists')
      .stream(primaryKey: ['id'])
      .eq('owner_id', uid)
      .order('created_at')
      .map((rows) =>
          rows.map((r) => PlaylistModel.fromMap(r)).toList());
});

/// Liked songs for the current user.
class LikedSongsNotifier extends AsyncNotifier<List<SongModel>> {
  @override
  Future<List<SongModel>> build() async {
    return ref.watch(playlistServiceProvider).fetchLikedSongs();
  }

  Future<void> toggleLike(SongModel song) async {
    final likedIds = ref.read(likedSongIdsProvider).value ?? {};
    final isLiked = likedIds.contains(song.id);

    await ref.read(playlistServiceProvider).toggleLike(song, isLiked);

    ref.invalidate(likedSongIdsProvider);
    ref.invalidate(likedSongsProvider);
  }
}

final likedSongsProvider =
    AsyncNotifierProvider<LikedSongsNotifier, List<SongModel>>(
        LikedSongsNotifier.new);

/// Set of liked song IDs for quick lookup in the UI.
final likedSongIdsProvider = FutureProvider<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  final localPrefs = await SharedPreferences.getInstance();
  final localLiked = localPrefs.getStringList('local_liked_songs') ?? [];
  final localSet = localLiked.toSet();

  if (uid == null) return localSet;
  try {
    final rows = await supabase
        .from('liked_songs')
        .select('song_id')
        .eq('uid', uid);
    final dbSet = {for (final r in rows) r['song_id'].toString()};
    return dbSet.union(localSet);
  } catch (e) {
    debugPrint('Error fetching liked song IDs: $e');
    return localSet;
  }
});

// ── Service ────────────────────────────────────────────────────────────────

class PlaylistService {
  // ── Playlists ──
  Future<PlaylistModel> createPlaylist(String title) async {
    final uid = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('playlists')
        .insert({'owner_id': uid, 'title': title})
        .select()
        .single();
    return PlaylistModel.fromMap(row);
  }

  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    await supabase
        .from('playlists')
        .update({'title': newTitle})
        .eq('id', playlistId);
  }

  Future<void> deletePlaylist(String playlistId) async {
    await supabase.from('playlists').delete().eq('id', playlistId);
  }

  // ── Playlist songs ──
  Future<List<SongModel>> fetchPlaylistSongs(String playlistId) async {
    final rows = await supabase
        .from('playlist_songs')
        .select('songs(*)')
        .eq('playlist_id', playlistId)
        .order('position');
    return rows
        .map<SongModel>((r) => SongModel.fromMap(
            Map<String, dynamic>.from(r['songs'] as Map)))
        .toList();
  }

  Future<void> addSongToPlaylist(
      String playlistId, String songId, int position) async {
    await supabase.from('playlist_songs').upsert({
      'playlist_id': playlistId,
      'song_id':     songId,
      'position':    position,
    });
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    await supabase
        .from('playlist_songs')
        .delete()
        .eq('playlist_id', playlistId)
        .eq('song_id', songId);
  }

  // ── Liked songs ──
  Future<void> ensureSongExists(SongModel song) async {
    try {
      await supabase.from('songs').upsert({
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'genre': song.genre,
        'mood': song.mood,
        'audio_url': song.audioUrl,
        'cover_url': song.coverUrl,
        'duration_ms': song.durationMs,
      });
    } catch (e) {
      debugPrint('ensureSongExists error (non-critical if DB not migrated): $e');
    }
  }

  Future<List<SongModel>> fetchLikedSongs() async {
    // 1. Load local liked songs
    final prefs = await SharedPreferences.getInstance();
    final localDetails = prefs.getStringList('local_liked_songs_details') ?? [];
    final List<SongModel> localSongs = localDetails.map((s) {
      try {
        return SongModel.fromMap(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<SongModel>().toList();

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return localSongs;

    try {
      final rows = await supabase
          .from('liked_songs')
          .select('song_id, songs(*)')
          .eq('uid', uid);

      final List<SongModel> dbSongs = [];
      final List<String> saavnIdsToFetch = [];

      for (final r in rows) {
        final songData = r['songs'];
        final songId = r['song_id']?.toString() ?? '';
        if (songData != null) {
          dbSongs.add(SongModel.fromMap(Map<String, dynamic>.from(songData as Map)));
        } else if (songId.isNotEmpty) {
          final matchingLocal = localSongs.firstWhere(
            (s) => s.id == songId,
            orElse: () => const SongModel(id: '', title: '', artist: '', coverUrl: '', audioUrl: ''),
          );
          if (matchingLocal.id.isNotEmpty) {
            dbSongs.add(matchingLocal);
          } else {
            saavnIdsToFetch.add(songId);
          }
        }
      }

      if (saavnIdsToFetch.isNotEmpty) {
        final saavnSongs = await SaavnService().getSongsDetails(saavnIdsToFetch);
        dbSongs.addAll(saavnSongs);
      }

      final merged = <String, SongModel>{};
      for (final s in [...dbSongs, ...localSongs]) {
        if (s.id.isNotEmpty) {
          merged[s.id] = s;
        }
      }
      return merged.values.toList();
    } catch (e) {
      debugPrint('Error fetching liked songs from Supabase: $e');
      return localSongs;
    }
  }

  Future<void> likeSong(SongModel song) async {
    // Save locally first
    final prefs = await SharedPreferences.getInstance();
    final localLiked = prefs.getStringList('local_liked_songs') ?? [];
    if (!localLiked.contains(song.id)) {
      localLiked.add(song.id);
      await prefs.setStringList('local_liked_songs', localLiked);

      final localDetails = prefs.getStringList('local_liked_songs_details') ?? [];
      localDetails.removeWhere((s) {
        try {
          return jsonDecode(s)['id'] == song.id;
        } catch (_) {
          return false;
        }
      });
      localDetails.add(jsonEncode(song.toMap()));
      await prefs.setStringList('local_liked_songs_details', localDetails);
    }

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await ensureSongExists(song);
      await supabase
          .from('liked_songs')
          .upsert({'uid': uid, 'song_id': song.id});
    } catch (e) {
      debugPrint('Failed to upsert liked song to Supabase: $e');
    }
  }

  Future<void> unlikeSong(String songId) async {
    // Remove locally
    final prefs = await SharedPreferences.getInstance();
    final localLiked = prefs.getStringList('local_liked_songs') ?? [];
    localLiked.remove(songId);
    await prefs.setStringList('local_liked_songs', localLiked);

    final localDetails = prefs.getStringList('local_liked_songs_details') ?? [];
    localDetails.removeWhere((s) {
      try {
        return jsonDecode(s)['id'] == songId;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList('local_liked_songs_details', localDetails);

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supabase
          .from('liked_songs')
          .delete()
          .eq('uid', uid)
          .eq('song_id', songId);
    } catch (e) {
      debugPrint('Failed to delete liked song from Supabase: $e');
    }
  }

  Future<void> toggleLike(SongModel song, bool isCurrentlyLiked) async {
    if (isCurrentlyLiked) {
      await unlikeSong(song.id);
    } else {
      await likeSong(song);
    }
  }
}
