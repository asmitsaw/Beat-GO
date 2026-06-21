import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../models/song_model.dart';
import '../../providers/saavn_provider.dart';
import '../../services/music_service.dart';
import '../../services/playlist_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Album Screen
//
// Can be pushed two ways:
//   1. AlbumScreen(albumId: '...')         — fetches full album from Saavn
//   2. AlbumScreen.fromSong(song: song)    — shows album name + art from song,
//      then tries to load full album detail.
// ══════════════════════════════════════════════════════════════════════════════

class AlbumScreen extends ConsumerWidget {
  final String? albumId;
  final SongModel? seedSong; // shown while loading or as fallback

  const AlbumScreen({super.key, this.albumId, this.seedSong});

  /// Convenience constructor for tapping an album art from a song card.
  factory AlbumScreen.fromSong({required SongModel song}) =>
      AlbumScreen(seedSong: song);

  static const _trackColors = [
    AppColors.yellow,
    AppColors.cyan,
    AppColors.green,
    AppColors.purple,
    AppColors.pink,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = albumId;

    // If we have an albumId, fetch full detail; else show a minimal page.
    if (id != null && id.isNotEmpty) {
      final albumAsync = ref.watch(saavnAlbumDetailProvider(id));
      return albumAsync.when(
        loading: () => _buildShell(context, null, isLoading: true),
        error: (e, _) => _buildShell(context, null, error: e.toString()),
        data: (album) => _buildShell(
          context,
          null,
          title: album.name,
          artist: album.primaryArtists.join(', '),
          coverUrl: album.imageUrl,
          language: album.language,
          year: album.year?.toString(),
          songs: album.songs,
          ref: ref,
        ),
      );
    }

    // fromSong mode — no album ID available
    final song = seedSong;
    return _buildShell(
      context,
      null,
      title: song?.album.isNotEmpty == true ? song!.album : 'Album',
      artist: song?.artist ?? '',
      coverUrl: song?.coverUrl ?? '',
      language: song?.genre ?? '',
      songs: song != null ? [song] : [],
      ref: ref,
      noFullAlbum: true,
    );
  }

  Widget _buildShell(
    BuildContext context,
    dynamic _, {
    bool isLoading = false,
    String? error,
    String title = '',
    String artist = '',
    String coverUrl = '',
    String language = '',
    String? year,
    List<SongModel> songs = const [],
    WidgetRef? ref,
    bool noFullAlbum = false,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: coverUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const ColoredBox(color: Colors.black12),
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: Colors.black12),
                        ),
                        // Gradient overlay so text is readable
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const ColoredBox(color: Colors.black12),
              title: isLoading
                  ? null
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artist.isNotEmpty)
                          Text(
                            artist,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
          ),

          // ── Metadata chips ──────────────────────────────────────────────
          if (!isLoading && error == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (language.isNotEmpty) _Chip(language),
                    if (year != null) _Chip(year),
                    if (songs.isNotEmpty) _Chip('${songs.length} tracks'),
                    if (noFullAlbum) _Chip('Album detail unavailable'),
                  ],
                ),
              ),
            ),

          // ── Play All button ─────────────────────────────────────────────
          if (!isLoading && error == null && songs.isNotEmpty && ref != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: GestureDetector(
                  onTap: () =>
                      ref.read(musicServiceProvider).playQueue(songs, 0, ref),
                  child: NeoBox(
                    color: AppColors.pink,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 20,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, size: 22, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'PLAY ALL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Loading indicator ───────────────────────────────────────────
          if (isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.pink),
              ),
            ),

          // ── Error banner ────────────────────────────────────────────────
          if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NeoBox(
                  color: AppColors.pink,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Failed to load album: $error',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // ── Track listing ───────────────────────────────────────────────
          if (!isLoading && error == null && songs.isNotEmpty && ref != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final song = songs[i];
                  final color = _trackColors[i % _trackColors.length];
                  final likedIds = ref.watch(likedSongIdsProvider).value ?? {};
                  final isLiked = likedIds.contains(song.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NeoBox(
                      color: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // Track number
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),

                          // Cover thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: CachedNetworkImage(
                              imageUrl: song.coverUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  const ColoredBox(color: Colors.black12),
                              errorWidget: (_, _, _) =>
                                  const Icon(Icons.music_note),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Title + artist
                          Expanded(
                            child: GestureDetector(
                              onTap: () => ref
                                  .read(musicServiceProvider)
                                  .playQueue(songs, i, ref),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    song.artist,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          GestureDetector(
                            onTap: () async {
                              await ref
                                  .read(likedSongsProvider.notifier)
                                  .toggleLike(song);
                            },
                            child: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Play
                          GestureDetector(
                            onTap: () => ref
                                .read(musicServiceProvider)
                                .playQueue(songs, i, ref),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 26,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: songs.length),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small neobrutalism chip for metadata.
class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
