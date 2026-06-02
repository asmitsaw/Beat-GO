import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../components/neo_button.dart';
import '../../services/music_service.dart';
import '../../services/playlist_service.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(userPlaylistsProvider);
    final likedAsync     = ref.watch(likedSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('LIBRARY')),
      body: RefreshIndicator(
        color: AppColors.pink,
        onRefresh: () async {
          ref.invalidate(userPlaylistsProvider);
          ref.invalidate(likedSongsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(
              left: 16, right: 16, top: 16, bottom: 120),
          children: [
            // ── Liked Songs card ──────────────────────────────────────────
            likedAsync.when(
              loading: () => _skeletonCard(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (songs) => GestureDetector(
                onTap: () {
                  if (songs.isEmpty) return;
                  ref.read(musicServiceProvider).playQueue(songs, 0, ref);
                },
                child: NeoBox(
                  color:  AppColors.pink,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    const Icon(Icons.favorite, size: 40, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Liked Songs',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: Colors.white)),
                            Text('${songs.length} songs',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ]),
                    ),
                    const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  ]),
                ),
              ),
            ),

            // ── Section header ────────────────────────────────────────────
            Row(children: [
              const Expanded(
                child: Text('YOUR PLAYLISTS',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary)),
              ),
              NeoButton(
                onPressed: () => _showCreatePlaylistDialog(context, ref),
                color: AppColors.yellow,
                borderWidth: 2,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('+ NEW',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Playlists list ────────────────────────────────────────────
            playlistsAsync.when(
              loading: () => _skeletonCard(),
              error:   (e, _) => Text('Error: $e'),
              data: (playlists) => playlists.isEmpty
                  ? _emptyPlaylists()
                  : Column(
                      children: playlists
                          .map((p) => _PlaylistCard(playlist: p))
                          .toList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonCard() => NeoBox(
    color: Colors.black12,
    margin: const EdgeInsets.only(bottom: 12),
    child: const SizedBox(height: 48),
  );

  Widget _emptyPlaylists() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: const [
      Text('🎵', style: TextStyle(fontSize: 48)),
      SizedBox(height: 12),
      Text('No playlists yet.',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Text('Tap + NEW to create one.',
          style: TextStyle(color: AppColors.textSecondary)),
    ]),
  );

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 3),
        ),
        title: const Text('New Playlist',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name…',
            border: OutlineInputBorder(),
          ),
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
                await ref.read(playlistServiceProvider).createPlaylist(name);
                ref.invalidate(userPlaylistsProvider);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Playlist card ──────────────────────────────────────────────────────────

class _PlaylistCard extends ConsumerWidget {
  final PlaylistModel playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(playlist.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.pink,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 3),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete playlist?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.pink),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) async {
        await ref.read(playlistServiceProvider).deletePlaylist(playlist.id);
        ref.invalidate(userPlaylistsProvider);
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  PlaylistDetailScreen(playlist: playlist)),
        ),
        child: NeoBox(
          color: AppColors.cyan,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Cover or placeholder
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: AppColors.purple,
                border: Border.all(color: AppColors.border, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: playlist.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                          imageUrl: playlist.coverUrl!, fit: BoxFit.cover))
                  : const Icon(Icons.queue_music, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(playlist.isPublic ? 'Public' : 'Private',
                      style: const TextStyle(fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          ]),
        ),
      ),
    );
  }
}
