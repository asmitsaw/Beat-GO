import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../services/music_service.dart';
import '../../services/auth_service.dart';
import '../../services/playlist_service.dart';
import '../../services/download_service.dart';
import '../../components/neo_box.dart';

// ── Provider: songs list ───────────────────────────────────────────────────
final songsProvider = FutureProvider<List<SongModel>>((ref) async {
  return ref.read(musicServiceProvider).fetchSongs();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync     = ref.watch(songsProvider);
    final likedIds       = ref.watch(likedSongIdsProvider).value ?? {};
    final downloadedIds  = ref.watch(downloadedProvider);
    final downloadingIds = ref.watch(downloadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DISCOVER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: songsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.pink)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (songs) => _SongList(
          songs:          songs,
          likedIds:       likedIds,
          downloadedIds:  downloadedIds,
          downloadingIds: downloadingIds,
        ),
      ),
    );
  }
}

// ── Song list ──────────────────────────────────────────────────────────────

class _SongList extends ConsumerWidget {
  final List<SongModel> songs;
  final Set<String> likedIds;
  final Set<String> downloadedIds;
  final Set<String> downloadingIds;

  const _SongList({
    required this.songs,
    required this.likedIds,
    required this.downloadedIds,
    required this.downloadingIds,
  });

  static const _cardColors = [AppColors.pink, AppColors.cyan, AppColors.yellow, AppColors.green, AppColors.purple];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.pink,
      onRefresh: () async => ref.invalidate(songsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final isLiked       = likedIds.contains(song.id);
          final isDownloaded  = downloadedIds.contains(song.id);
          final isDownloading = downloadingIds.contains(song.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: NeoBox(
              color: _cardColors[index % _cardColors.length],
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                // Album art
                GestureDetector(
                  onTap: () => ref
                      .read(musicServiceProvider)
                      .playQueue(songs, index, ref),
                  child: Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                        imageUrl: song.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ColoredBox(color: Colors.black12),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.music_note),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title + artist
                Expanded(
                  child: GestureDetector(
                    onTap: () => ref
                        .read(musicServiceProvider)
                        .playQueue(songs, index, ref),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(song.artist,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (song.genre.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: Text(song.genre,
                                style: const TextStyle(fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: () async {
                        await ref.read(playlistServiceProvider)
                            .toggleLike(song.id, isLiked);
                        ref.invalidate(likedSongIdsProvider);
                      },
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? AppColors.pink : AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Download button
                    GestureDetector(
                      onTap: isDownloading
                          ? null
                          : () => ref
                              .read(downloadServiceProvider)
                              .downloadSong(song, ref),
                      child: isDownloading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              isDownloaded
                                  ? Icons.download_done
                                  : Icons.download_outlined,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // Play chevron
                GestureDetector(
                  onTap: () => ref
                      .read(musicServiceProvider)
                      .playQueue(songs, index, ref),
                  child: const Icon(Icons.play_arrow,
                      size: 32, color: AppColors.textPrimary),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
