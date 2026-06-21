import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../services/music_service.dart';
import '../../services/recently_played_service.dart';

class RecentlyPlayedScreen extends ConsumerWidget {
  const RecentlyPlayedScreen({super.key});

  static const _colors = [
    AppColors.cyan,
    AppColors.green,
    AppColors.yellow,
    AppColors.purple,
    AppColors.pink,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentlyPlayedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('RECENTLY PLAYED'),
        actions: [
          recentAsync.when(
            data: (songs) => songs.isNotEmpty
                ? TextButton(
                    onPressed: () => _confirmClear(context, ref),
                    child: const Text(
                      'CLEAR ALL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: AppColors.pink,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: recentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.pink),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading history: $err',
            style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.bold),
          ),
        ),
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('📻', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 16),
                  Text(
                    'No recently played tracks.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Songs you play will show up here.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: songs.length,
            itemBuilder: (_, i) {
              final song = songs[i];
              final color = _colors[i % _colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    ref.read(musicServiceProvider).playQueue(songs, i, ref);
                  },
                  child: NeoBox(
                    color: color,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Cover
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: CachedNetworkImage(
                              imageUrl: song.coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const Icon(Icons.music_note),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title & Artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
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

                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 32,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 3),
        ),
        title: const Text(
          'Clear history?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('This will remove all recently played songs from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pink),
            onPressed: () async {
              await ref.read(recentlyPlayedServiceProvider).clearRecentlyPlayed();
              ref.invalidate(recentlyPlayedProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
