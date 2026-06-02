import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';

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
final likedSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  return ref.read(playlistServiceProvider).fetchLikedSongs();
});

/// Set of liked song IDs for quick lookup in the UI.
final likedSongIdsProvider = FutureProvider<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final rows = await supabase
      .from('liked_songs')
      .select('song_id')
      .eq('uid', uid);
  return {for (final r in rows) r['song_id'].toString()};
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
  Future<List<SongModel>> fetchLikedSongs() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase
        .from('liked_songs')
        .select('songs(*)')
        .eq('uid', uid)
        .order('liked_at', ascending: false);
    return rows
        .map<SongModel>((r) => SongModel.fromMap(
            Map<String, dynamic>.from(r['songs'] as Map)))
        .toList();
  }

  Future<void> likeSong(String songId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('liked_songs')
        .upsert({'uid': uid, 'song_id': songId});
  }

  Future<void> unlikeSong(String songId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('liked_songs')
        .delete()
        .eq('uid', uid)
        .eq('song_id', songId);
  }

  Future<void> toggleLike(String songId, bool isCurrentlyLiked) async {
    if (isCurrentlyLiked) {
      await unlikeSong(songId);
    } else {
      await likeSong(songId);
    }
  }
}
