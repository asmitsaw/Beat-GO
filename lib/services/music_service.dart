import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import '../core/supabase_client.dart';

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
  final AudioPlayer player = AudioPlayer();

  // ── Fetch songs from Supabase (with mock fallback) ──────────────────────
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
      return list.map((r) => SongModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('fetchSongs error: $e — using mock data');
      return _mockSongs();
    }
  }

  Future<List<SongModel>> fetchTrending({int limit = 10}) async {
    try {
      final rows = await supabase
          .from('songs')
          .select()
          .order('play_count', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows as List)
          .map((r) => SongModel.fromMap(r))
          .toList();
    } catch (e) {
      return _mockSongs();
    }
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
    }).then((_) {}).catchError((e) => debugPrint('listen_event log error: $e'));
  }

  void _incrementPlayCount(String songId) {
    supabase.rpc('increment_play_count', params: {'song_id': songId})
        .then((_) {})
        .catchError((_) {}); // non-critical
  }

  // ── Mock fallback (used when Supabase table is empty / not yet seeded) ────
  static List<SongModel> _mockSongs() => [
        const SongModel(
          id:       '1',
          title:    'Synthwave Neon',
          artist:   'The Midnight Rider',
          album:    'Neon Dreams',
          genre:    'Electronic',
          mood:     'chill',
          coverUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=600&auto=format&fit=crop',
          audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          durationMs: 180000,
        ),
        const SongModel(
          id:       '2',
          title:    'Cyberpunk Drive',
          artist:   'Vapor Wave',
          album:    'City Lights',
          genre:    'Electronic',
          mood:     'hype',
          coverUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=600&auto=format&fit=crop',
          audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
          durationMs: 210000,
        ),
        const SongModel(
          id:       '3',
          title:    'Arcade Dreams',
          artist:   'Pixel Pop',
          album:    '8-Bit Fantasies',
          genre:    'Electronic',
          mood:     'hype',
          coverUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=600&auto=format&fit=crop',
          audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
          durationMs: 195000,
        ),
      ];
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);
