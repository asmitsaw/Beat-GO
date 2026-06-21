import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../services/music_service.dart';
import '../../services/playlist_service.dart';

// Provider scoped to each playlist detail page
final _playlistSongsProvider = FutureProvider.family<List<SongModel>, String>((
  ref,
  playlistId,
) async {
  return ref.read(playlistServiceProvider).fetchPlaylistSongs(playlistId);
});

class PlaylistDetailScreen extends ConsumerWidget {
  final PlaylistModel playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(_playlistSongsProvider(playlist.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(playlist.title.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showRenameDialog(context, ref),
          ),
        ],
      ),
      body: songsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.pink),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (songs) => songs.isEmpty
            ? _emptyState()
            : Column(
                children: [
                  // Play all banner
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () => ref
                          .read(musicServiceProvider)
                          .playQueue(songs, 0, ref),
                      child: NeoBox(
                        color: AppColors.yellow,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              'PLAY ALL (${songs.length} songs)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 120,
                      ),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NeoBox(
                            color: index % 2 == 0
                                ? AppColors.cyan
                                : AppColors.purple,
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                // Cover art
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: CachedNetworkImage(
                                      imageUrl: song.coverUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => const ColoredBox(
                                        color: Colors.black12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(musicServiceProvider)
                                        .playQueue(songs, index, ref),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          song.artist,
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Remove from playlist
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.pink,
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(playlistServiceProvider)
                                        .removeSongFromPlaylist(
                                          playlist.id,
                                          song.id,
                                        );
                                    ref.invalidate(
                                      _playlistSongsProvider(playlist.id),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text('🎵', style: TextStyle(fontSize: 56)),
        SizedBox(height: 12),
        Text(
          'This playlist is empty.',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        SizedBox(height: 6),
        Text(
          'Add songs from the Discover tab.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: playlist.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 3),
        ),
        title: const Text(
          'Rename Playlist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await ref
                    .read(playlistServiceProvider)
                    .renamePlaylist(playlist.id, name);
                ref.invalidate(userPlaylistsProvider);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
