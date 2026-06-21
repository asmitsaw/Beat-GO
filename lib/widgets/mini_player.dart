import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../services/music_service.dart';
import '../services/playlist_service.dart';
import '../components/neo_box.dart';
import '../screens/player/player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(positionProvider);
    final durationAsync = ref.watch(durationProvider);
    final likedIds = ref.watch(likedSongIdsProvider).value ?? {};

    if (currentSong == null) return const SizedBox.shrink();

    final isPlaying = isPlayingAsync.value ?? false;
    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final isLiked = likedIds.contains(currentSong.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayerScreen()),
      ),
      // Swipe to skip
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -400) {
          ref.read(musicServiceProvider).seekToNext();
        } else if (v > 400) {
          ref.read(musicServiceProvider).seekToPrevious();
        }
      },
      child: NeoBox(
        color: AppColors.purple,
        padding: EdgeInsets.zero,
        borderRadius: 10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Progress bar at top edge ────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.black26,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.yellow,
                ),
                minHeight: 4,
              ),
            ),

            // ── Main row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Album art
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                        imageUrl: currentSong.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: Colors.black12),
                        errorWidget: (_, _, _) => const Icon(Icons.music_note),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSong.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentSong.artist,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Like button
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.pink : AppColors.textPrimary,
                      size: 22,
                    ),
                    onPressed: () async {
                      await ref
                          .read(playlistServiceProvider)
                          .toggleLike(currentSong.id, isLiked);
                      ref.invalidate(likedSongIdsProvider);
                    },
                  ),

                  // Play / Pause
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.textPrimary,
                      size: 32,
                    ),
                    onPressed: () => isPlaying
                        ? ref.read(musicServiceProvider).pause()
                        : ref.read(musicServiceProvider).resume(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
