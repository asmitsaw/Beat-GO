import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../core/supabase_client.dart';
import 'saavn_service.dart';
import 'recently_played_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

final musicServiceProvider = Provider<MusicService>((ref) => MusicService());

// ── Queue ──────────────────────────────────────────────────────────────────
class QueueNotifier extends Notifier<List<SongModel>> {
  @override
  List<SongModel> build() => [];
  void setQueue(List<SongModel> songs) => state = songs;
  void clear() => state = [];
}
final queueProvider =
    NotifierProvider<QueueNotifier, List<SongModel>>(QueueNotifier.new);

// ── Current index (from just_audio stream) ─────────────────────────────────
final currentIndexProvider = StreamProvider<int?>((ref) {
  return ref.watch(musicServiceProvider).player.currentIndexStream;
});

// ── Derived current song ────────────────────────────────────────────────────
final currentSongProvider = Provider<SongModel?>((ref) {
  final queue      = ref.watch(queueProvider);
  final indexAsync = ref.watch(currentIndexProvider);
  return indexAsync.whenOrNull(data: (index) {
    if (index == null || queue.isEmpty || index >= queue.length) return null;
    return queue[index];
  });
});

// ── Playback state (derived from player stream — no manual notifier needed) ─
final isPlayingProvider = StreamProvider<bool>((ref) {
  return ref.watch(musicServiceProvider).player.playingStream;
});

// ── Position & Duration ─────────────────────────────────────────────────────
final positionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(musicServiceProvider).player.positionStream;
});
final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(musicServiceProvider).player.durationStream;
});

// ── Shuffle & Repeat ────────────────────────────────────────────────────────
final shuffleProvider = StreamProvider<bool>((ref) {
  return ref.watch(musicServiceProvider).player.shuffleModeEnabledStream;
});
final loopModeProvider = StreamProvider<LoopMode>((ref) {
  return ref.watch(musicServiceProvider).player.loopModeStream;
});

// ══════════════════════════════════════════════════════════════════════════════
// SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class MusicService {
  final AndroidEqualizer equalizer = AndroidEqualizer();
  late final AudioPlayer player;

  MusicService() {
    final pipeline = AudioPipeline(androidAudioEffects: [equalizer]);
    player = AudioPlayer(audioPipeline: pipeline);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex, WidgetRef ref) async {
    final queue = ref.read(queueProvider);
    if (oldIndex < 0 || oldIndex >= queue.length || newIndex < 0 || newIndex > queue.length) return;

    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }

    final newQueue = List<SongModel>.from(queue);
    final song = newQueue.removeAt(oldIndex);
    newQueue.insert(targetIndex, song);
    ref.read(queueProvider.notifier).setQueue(newQueue);

    if (player.audioSource is ConcatenatingAudioSource) {
      final source = player.audioSource as ConcatenatingAudioSource;
      try {
        await source.move(oldIndex, targetIndex);
      } catch (e) {
        debugPrint('Error reordering just_audio playlist: $e');
      }
    }
  }

  // ── Fetch songs from Supabase → fall through to JioSaavn if empty ────────
  Future<List<SongModel>> fetchSongs({String? genre, String? query}) async {
    try {
      var q = supabase.from('songs').select();

      if (genre != null && genre.isNotEmpty) {
        q = q.eq('genre', genre) as dynamic;
      }
      if (query != null && query.isNotEmpty) {
        q = q.textSearch('fts', query, config: 'english') as dynamic;
      }

      final rows = await q.order('play_count', ascending: false);
      final list = List<Map<String, dynamic>>.from(rows as List);
      final songs = list.map((r) => SongModel.fromMap(r)).toList();
      if (songs.isNotEmpty) return songs;
    } catch (_) {}
    // Supabase empty or unavailable — use JioSaavn
    final saavn = SaavnService();
    if (query != null && query.isNotEmpty) {
      return saavn.searchSongs(query);
    }
    return saavn.getTrendingSongs();
  }

  Future<List<SongModel>> fetchTrending({int limit = 10}) async {
    try {
      final rows = await supabase
          .from('songs')
          .select()
          .order('play_count', ascending: false)
          .limit(limit);
      final songs = List<Map<String, dynamic>>.from(rows as List)
          .map((r) => SongModel.fromMap(r))
          .toList();
      if (songs.isNotEmpty) return songs;
    } catch (_) {}
    return SaavnService().getTrendingSongs(limit: limit);
  }

  /// Fetch song suggestions from JioSaavn (for radio-mode queue extension).
  Future<List<SongModel>> fetchSuggestions(String songId) async {
    return SaavnService().getSongSuggestions(songId, limit: 10);
  }

  // ── Queue-based playback ──────────────────────────────────────────────────
  Future<void> playQueue(
      List<SongModel> songs, int startIndex, WidgetRef ref) async {
    if (songs.isEmpty) return;

    ref.read(queueProvider.notifier).setQueue(songs);

    final sources = songs
        .map((s) => AudioSource.uri(
              Uri.parse(s.audioUrl),
              tag: MediaItem(
                id:      s.id,
                title:   s.title,
                artist:  s.artist,
                album:   s.album.isEmpty ? 'Retro Beats' : s.album,
                artUri:  Uri.tryParse(s.coverUrl),
              ),
            ))
        .toList();

    final playlist = ConcatenatingAudioSource(children: sources);

    try {
      await player.setAudioSource(playlist,
          initialIndex: startIndex.clamp(0, songs.length - 1));
      await player.play();
      _logListenEvent(songs[startIndex].id);
      _incrementPlayCount(songs[startIndex].id);
      // Track in recently played
      RecentlyPlayedService().addSong(songs[startIndex]).catchError((_) {});
      ref.invalidate(recentlyPlayedProvider);
    } catch (e) {
      debugPrint('playQueue error: $e');
    }
  }

  // ── Playback controls ─────────────────────────────────────────────────────
  Future<void> pause()          async => player.pause();
  Future<void> resume()         async => player.play();
  Future<void> seek(Duration p) async => player.seek(p);

  Future<void> seekToNext() async {
    await player.seekToNext();
    _logCurrentSong();
  }

  Future<void> seekToPrevious() async {
    await player.seekToPrevious();
    _logCurrentSong();
  }

  Future<void> toggleShuffle() async {
    await player.setShuffleModeEnabled(!player.shuffleModeEnabled);
  }

  Future<void> cycleRepeatMode() async {
    switch (player.loopMode) {
      case LoopMode.off:  await player.setLoopMode(LoopMode.all);  break;
      case LoopMode.all:  await player.setLoopMode(LoopMode.one);  break;
      case LoopMode.one:  await player.setLoopMode(LoopMode.off);  break;
    }
  }

  // ── Supabase side-effects ─────────────────────────────────────────────────
  void _logCurrentSong() {
    final idx = player.currentIndex;
    // Can't easily get the queue here without WidgetRef; 
    // caller should call _logListenEvent when needed
    debugPrint('Index changed to $idx');
  }

  void _logListenEvent(String songId) {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    supabase.from('listen_events').insert({
      'uid':        uid,
      'song_id':    songId,
      'listened_at': DateTime.now().toUtc().toIso8601String(),
    }).then((_) {}).catchError((e) { debugPrint('listen_event log error: $e'); return null; });
  }

  void _incrementPlayCount(String songId) {
    supabase.rpc('increment_play_count', params: {'song_id': songId})
        .then((_) {})
        .catchError((_) {}); // non-critical
  }


}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);

// ── Autoplay / Continuous Play Mode ──────────────────────────────────────────
final autoplayProvider = Provider<void>((ref) {
  final indexAsync = ref.watch(currentIndexProvider);
  final queue = ref.watch(queueProvider);

  indexAsync.whenData((index) async {
    if (index == null || queue.isEmpty) return;

    // Trigger suggestions fetch when we play the last song in the queue
    if (index == queue.length - 1) {
      final lastSong = queue[index];
      debugPrint('Autoplay: Reached last song in queue: ${lastSong.title}. Fetching suggestions...');

      try {
        final suggestions = await ref.read(musicServiceProvider).fetchSuggestions(lastSong.id);
        
        final currentQueue = ref.read(queueProvider);
        if (suggestions.isNotEmpty && 
            currentQueue.length == queue.length && 
            currentQueue.last.id == lastSong.id) {
          
          // 1. Update Riverpod queue state
          final updatedQueue = [...currentQueue, ...suggestions];
          ref.read(queueProvider.notifier).setQueue(updatedQueue);

          // 2. Append to just_audio's ConcatenatingAudioSource
          final player = ref.read(musicServiceProvider).player;
          if (player.audioSource is ConcatenatingAudioSource) {
            final source = player.audioSource as ConcatenatingAudioSource;
            final newSources = suggestions.map((s) => AudioSource.uri(
              Uri.parse(s.audioUrl),
              tag: MediaItem(
                id:      s.id,
                title:   s.title,
                artist:  s.artist,
                album:   s.album.isEmpty ? 'Retro Beats' : s.album,
                artUri:  Uri.tryParse(s.coverUrl),
              ),
            )).toList();

            await source.addAll(newSources);
            debugPrint('Autoplay: Successfully appended ${suggestions.length} songs.');
          }
        }
      } catch (e) {
        debugPrint('Autoplay error: $e');
      }
    }
  });
});
