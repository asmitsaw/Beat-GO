import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../models/song_model.dart';
import '../../models/user_preferences_model.dart';
import '../../services/music_service.dart';
import '../../services/auth_service.dart';
import '../../services/playlist_service.dart';
import '../../services/download_service.dart';
import '../../components/neo_box.dart';
import '../../providers/saavn_provider.dart';
import '../../providers/recommendations_provider.dart';
import '../album/album_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Home Screen
// ══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync      = ref.watch(saavnTrendingProvider);
    final newReleasesAsync   = ref.watch(saavnNewReleasesProvider);
    final forYouAsync        = ref.watch(forYouRecommendationsProvider);
    final prefsAsync         = ref.watch(userPreferencesProvider);
    final currentSong        = ref.watch(currentSongProvider);
    final likedIds           = ref.watch(likedSongIdsProvider).value ?? {};
    final downloadedIds      = ref.watch(downloadedProvider);
    final downloadingIds     = ref.watch(downloadingProvider);

    // "Because You Liked" — based on currently playing song
    final becauseSong = currentSong;

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
      body: RefreshIndicator(
        color: AppColors.pink,
        onRefresh: () async {
          ref.invalidate(saavnTrendingProvider);
          ref.invalidate(saavnNewReleasesProvider);
          ref.invalidate(forYouRecommendationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [

            // ── Made For You (ML) ──────────────────────────────────────────
            prefsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (prefs) {
                if (prefs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: '✨ MADE FOR YOU'),
                    forYouAsync.when(
                      loading: () => const _HorizontalLoader(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (recs) => recs.isEmpty
                          ? const SizedBox.shrink()
                          : _MadeForYouRow(recs: recs),
                    ),
                    const SizedBox(height: 4),
                  ],
                );
              },
            ),

            // ── Because You Liked ──────────────────────────────────────────
            if (becauseSong != null) ...[
              _SectionHeader(
                  title: '🎵 BECAUSE YOU LIKED "${becauseSong.title.toUpperCase()}"'),
              _BecauseYouLikedRow(song: becauseSong),
              const SizedBox(height: 8),
            ],

            // ── Trending Now ───────────────────────────────────────────────
            _SectionHeader(title: 'TRENDING NOW 🔥'),
            trendingAsync.when(
              loading: () => const _HorizontalLoader(),
              error: (e, _) => _ErrorBanner(message: e.toString()),
              data: (songs) => _TrendingHorizontalList(
                songs: songs,
                likedIds: likedIds,
                downloadedIds: downloadedIds,
                downloadingIds: downloadingIds,
              ),
            ),

            const SizedBox(height: 8),

            // ── New Releases ───────────────────────────────────────────────
            _SectionHeader(title: 'NEW RELEASES ✨'),
            newReleasesAsync.when(
              loading: () => const _HorizontalLoader(),
              error: (e, _) => _ErrorBanner(message: e.toString()),
              data: (songs) => _NewReleasesGrid(
                songs: songs,
                likedIds: likedIds,
                downloadedIds: downloadedIds,
                downloadingIds: downloadingIds,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Made For You — ML recommendation horizontal row
// ══════════════════════════════════════════════════════════════════════════════

class _MadeForYouRow extends ConsumerWidget {
  final List<SongModel> recs;
  const _MadeForYouRow({required this.recs});

  static const _cardColors = [
    Color(0xFFE91E63), Color(0xFF00BCD4), Color(0xFFFF9800),
    Color(0xFF4CAF50), Color(0xFF9C27B0), Color(0xFFFF5722),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedIds = ref.watch(likedSongIdsProvider).value ?? {};

    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recs.length,
        itemBuilder: (_, i) {
          final rec   = recs[i];
          final color = _cardColors[i % _cardColors.length];
          final pct   = 85 + (rec.title.hashCode % 15);
          final isLiked = likedIds.contains(rec.id);

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => ref.read(musicServiceProvider).playQueue(recs, i, ref),
              child: Container(
                width: 148,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black,
                        offset: Offset(3, 3),
                        blurRadius: 0),
                  ],
                ),
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '⚡ $pct%',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await ref.read(likedSongsProvider.notifier).toggleLike(rec);
                          },
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? AppColors.pink : Colors.white70,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Album art thumbnail
                    if (rec.coverUrl.isNotEmpty)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black, width: 1.5),
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(rec.coverUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Song title
                    Text(
                      rec.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    // Artist
                    Text(
                      rec.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Because You Liked — shows ML recommendations based on currently playing song
// ══════════════════════════════════════════════════════════════════════════════

class _BecauseYouLikedRow extends ConsumerWidget {
  final SongModel song;
  const _BecauseYouLikedRow({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(songRecommendationsProvider(song.id));
    final likedIds = ref.watch(likedSongIdsProvider).value ?? {};

    return recsAsync.when(
      loading: () => const _HorizontalLoader(),
      error: (_, __) => const SizedBox.shrink(),
      data: (recs) {
        if (recs.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recs.length,
            itemBuilder: (_, i) {
              final rec = recs[i];
              final isLiked = likedIds.contains(rec.id);

              return GestureDetector(
                onTap: () => ref.read(musicServiceProvider).playQueue(recs, i, ref),
                child: Container(
                  width: 230,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cyan, width: 1.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Index / play icon area
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cyan,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Album Art thumbnail
                      if (rec.coverUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: rec.coverUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(color: Colors.black12),
                            errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 18),
                          ),
                        ),
                      const SizedBox(width: 10),
                      // Title + artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              rec.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              rec.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Like button
                      GestureDetector(
                        onTap: () async {
                          await ref.read(likedSongsProvider.notifier).toggleLike(rec);
                        },
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? AppColors.pink : AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section Header
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 2.0,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Trending — horizontal card carousel
// ══════════════════════════════════════════════════════════════════════════════

class _TrendingHorizontalList extends ConsumerWidget {
  final List<SongModel> songs;
  final Set<String> likedIds;
  final Set<String> downloadedIds;
  final Set<String> downloadingIds;

  const _TrendingHorizontalList({
    required this.songs,
    required this.likedIds,
    required this.downloadedIds,
    required this.downloadingIds,
  });

  static const _cardColors = [
    AppColors.pink,
    AppColors.cyan,
    AppColors.yellow,
    AppColors.green,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No trending songs found.'),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final song    = songs[i];
          final isLiked = likedIds.contains(song.id);
          final color   = _cardColors[i % _cardColors.length];

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => ref.read(musicServiceProvider).playQueue(songs, i, ref),
              child: NeoBox(
                color: color,
                padding: const EdgeInsets.all(10),
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Album art
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: song.coverUrl,
                        width: double.infinity,
                        height: 110,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.black12, height: 110),
                        errorWidget: (_, __, ___) =>
                            Container(
                              height: 110,
                              color: Colors.black12,
                              child: const Icon(Icons.music_note, size: 36),
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await ref
                                .read(likedSongsProvider.notifier)
                                .toggleLike(song);
                          },
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.white : AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                        const Icon(Icons.play_arrow,
                            size: 24, color: AppColors.textPrimary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// New Releases — vertical list with album art + metadata
// ══════════════════════════════════════════════════════════════════════════════

class _NewReleasesGrid extends ConsumerWidget {
  final List<SongModel> songs;
  final Set<String> likedIds;
  final Set<String> downloadedIds;
  final Set<String> downloadingIds;

  const _NewReleasesGrid({
    required this.songs,
    required this.likedIds,
    required this.downloadedIds,
    required this.downloadingIds,
  });

  static const _cardColors = [
    AppColors.yellow,
    AppColors.cyan,
    AppColors.green,
    AppColors.purple,
    AppColors.pink,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No new releases found.'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final song         = songs[i];
        final isLiked      = likedIds.contains(song.id);
        final isDownloaded = downloadedIds.contains(song.id);
        final isDownloading= downloadingIds.contains(song.id);
        final color        = _cardColors[i % _cardColors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeoBox(
            color: color,
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              // Album art — tappable to open album if available
              GestureDetector(
                onTap: () {
                  if (song.album.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlbumScreen.fromSong(song: song),
                      ),
                    );
                  } else {
                    ref.read(musicServiceProvider).playQueue(songs, i, ref);
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
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
              const SizedBox(width: 12),

              // Title + artist + language tag
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(musicServiceProvider).playQueue(songs, i, ref),
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
                          child: Text(
                            song.genre,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await ref
                          .read(likedSongsProvider.notifier)
                          .toggleLike(song);
                    },
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.pink : AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: isDownloading
                        ? null
                        : () => ref
                            .read(downloadServiceProvider)
                            .downloadSong(song, ref),
                    child: isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isDownloaded
                                ? Icons.download_done
                                : Icons.download_outlined,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SizedBox(width: 4),

              // Play
              GestureDetector(
                onTap: () =>
                    ref.read(musicServiceProvider).playQueue(songs, i, ref),
                child: const Icon(Icons.play_arrow,
                    size: 30, color: AppColors.textPrimary),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

class _HorizontalLoader extends StatelessWidget {
  const _HorizontalLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator(color: AppColors.pink)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeoBox(
        color: AppColors.pink,
        padding: const EdgeInsets.all(12),
        child: Text(
          'Error: $message',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
