import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../services/music_service.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(positionProvider);
    final durationAsync = ref.watch(durationProvider);

    if (currentSong == null) {
      return const Scaffold(body: Center(child: Text('No song playing')));
    }

    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? const Duration(minutes: 3);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('NOW PLAYING'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Album Art
              NeoBox(
                color: AppColors.background,
                padding: EdgeInsets.zero,
                width: MediaQuery.of(context).size.width - 48,
                height: MediaQuery.of(context).size.width - 48,
                child: Image.network(
                  currentSong.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
              
              // Title and Artist
              Column(
                children: [
                  Text(
                    currentSong.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentSong.artist,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              // Progress Bar
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.textPrimary,
                      inactiveTrackColor: AppColors.textSecondary.withOpacity(0.3),
                      thumbColor: AppColors.green,
                      trackHeight: 6.0,
                    ),
                    child: Slider(
                      min: 0,
                      max: duration.inMilliseconds.toDouble(),
                      value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                      onChanged: (value) {
                        ref.read(musicServiceProvider).seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(_formatDuration(duration), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.skip_previous),
                    color: AppColors.textPrimary,
                    onPressed: () {}, // Not implemented for MVP
                  ),
                  GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        ref.read(musicServiceProvider).pause(ref);
                      } else {
                        ref.read(musicServiceProvider).resume(ref);
                      }
                    },
                    child: NeoBox(
                      color: AppColors.yellow,
                      borderRadius: 40,
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 48,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.skip_next),
                    color: AppColors.textPrimary,
                    onPressed: () {}, // Not implemented for MVP
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
