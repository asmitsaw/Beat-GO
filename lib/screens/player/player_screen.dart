import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../services/music_service.dart';
import '../../services/playlist_service.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong    = ref.watch(currentSongProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync  = ref.watch(positionProvider);
    final durationAsync  = ref.watch(durationProvider);
    final shuffleAsync   = ref.watch(shuffleProvider);
    final loopAsync      = ref.watch(loopModeProvider);
    final likedIds       = ref.watch(likedSongIdsProvider).value ?? {};

    if (currentSong == null) {
      return const Scaffold(
          body: Center(child: Text('No song playing')));
    }

    final isPlaying = isPlayingAsync.value ?? false;
    final position  = positionAsync.value  ?? Duration.zero;
    final duration  = durationAsync.value  ?? const Duration(minutes: 3);
    final shuffle   = shuffleAsync.value   ?? false;
    final loop      = loopAsync.value      ?? LoopMode.off;
    final isLiked   = likedIds.contains(currentSong.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('NOW PLAYING'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Like from player screen
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? AppColors.pink : AppColors.textPrimary,
            ),
            onPressed: () async {
              await ref.read(playlistServiceProvider)
                  .toggleLike(currentSong.id, isLiked);
              ref.invalidate(likedSongIdsProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ── Album Art ────────────────────────────────────────────────
              NeoBox(
                color: AppColors.background,
                padding: EdgeInsets.zero,
                width:  MediaQuery.of(context).size.width - 48,
                height: MediaQuery.of(context).size.width - 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: CachedNetworkImage(
                    imageUrl: currentSong.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.purple),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.music_note, size: 64),
                  ),
                ),
              ),

              // ── Title & Artist ───────────────────────────────────────────
              Column(children: [
                Text(currentSong.title,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(currentSong.artist,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                if (currentSong.album.isNotEmpty)
                  Text(currentSong.album,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
              ]),

              // ── Progress Bar ─────────────────────────────────────────────
              Column(children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor:   AppColors.textPrimary,
                    inactiveTrackColor: AppColors.textSecondary.withOpacity(0.3),
                    thumbColor:         AppColors.green,
                    overlayColor:       AppColors.green.withOpacity(0.2),
                    trackHeight:        6,
                  ),
                  child: Slider(
                    min: 0,
                    max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    value: position.inMilliseconds
                        .toDouble()
                        .clamp(0, duration.inMilliseconds.toDouble()),
                    onChanged: (v) => ref
                        .read(musicServiceProvider)
                        .seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(_fmt(duration),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ]),

              // ── Controls ─────────────────────────────────────────────────
              Column(children: [
                // Shuffle + Repeat row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(Icons.shuffle,
                          color: shuffle ? AppColors.green : AppColors.textSecondary),
                      onPressed: () =>
                          ref.read(musicServiceProvider).toggleShuffle(),
                    ),
                    const SizedBox(width: 16),
                    // Repeat
                    IconButton(
                      icon: Icon(
                        loop == LoopMode.one
                            ? Icons.repeat_one
                            : Icons.repeat,
                        color: loop != LoopMode.off
                            ? AppColors.green
                            : AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          ref.read(musicServiceProvider).cycleRepeatMode(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Prev / Play / Next
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 44,
                      icon: const Icon(Icons.skip_previous),
                      color: AppColors.textPrimary,
                      onPressed: () =>
                          ref.read(musicServiceProvider).seekToPrevious(),
                    ),
                    GestureDetector(
                      onTap: () => isPlaying
                          ? ref.read(musicServiceProvider).pause()
                          : ref.read(musicServiceProvider).resume(),
                      child: NeoBox(
                        color:        AppColors.yellow,
                        borderRadius: 40,
                        padding:      const EdgeInsets.all(16),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size:  48,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 44,
                      icon: const Icon(Icons.skip_next),
                      color: AppColors.textPrimary,
                      onPressed: () =>
                          ref.read(musicServiceProvider).seekToNext(),
                    ),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
