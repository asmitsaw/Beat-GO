import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import 'package:just_audio_background/just_audio_background.dart';

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService();
});

class CurrentSongNotifier extends Notifier<SongModel?> {
  @override
  SongModel? build() => null;
  void updateSong(SongModel? song) => state = song;
}
final currentSongProvider = NotifierProvider<CurrentSongNotifier, SongModel?>(CurrentSongNotifier.new);

class IsPlayingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void updatePlaying(bool isP) => state = isP;
}
final isPlayingProvider = NotifierProvider<IsPlayingNotifier, bool>(IsPlayingNotifier.new);
final positionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(musicServiceProvider).player.positionStream;
});
final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(musicServiceProvider).player.durationStream;
});

class MusicService {
  final AudioPlayer player = AudioPlayer();

  Future<void> playSong(SongModel song, WidgetRef ref) async {
    ref.read(currentSongProvider.notifier).updateSong(song);
    
    try {
      final audioSource = AudioSource.uri(
        Uri.parse(song.audioUrl),
        tag: MediaItem(
          id: song.id,
          album: "Retro Beats",
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.coverUrl),
        ),
      );
      
      await player.setAudioSource(audioSource);
      await player.play();
      ref.read(isPlayingProvider.notifier).updatePlaying(true);
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  Future<void> pause(WidgetRef ref) async {
    await player.pause();
    ref.read(isPlayingProvider.notifier).updatePlaying(false);
  }

  Future<void> resume(WidgetRef ref) async {
    await player.play();
    ref.read(isPlayingProvider.notifier).updatePlaying(true);
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  // Mock data for initial testing without Firebase populated
  Future<List<SongModel>> getMockSongs() async {
    return [
      SongModel(
        id: '1',
        title: 'Synthwave Neon',
        artist: 'The Midnight Rider',
        coverUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=600&auto=format&fit=crop', // Retro car/grid
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      ),
      SongModel(
        id: '2',
        title: 'Cyberpunk Drive',
        artist: 'Vapor Wave',
        coverUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=600&auto=format&fit=crop', // Cyberpunk street
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      ),
      SongModel(
        id: '3',
        title: 'Arcade Dreams',
        artist: 'Pixel Pop',
        coverUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=600&auto=format&fit=crop', // Arcade cabinet
        audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
      ),
    ];
  }
}
