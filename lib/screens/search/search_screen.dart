import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../components/neo_text_field.dart';
import '../../models/song_model.dart';
import '../../services/music_service.dart';
import '../../services/recently_played_service.dart';
import '../../providers/saavn_provider.dart';
import '../album/album_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Search query state
// ══════════════════════════════════════════════════════════════════════════════

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final _searchQueryProvider = NotifierProvider<_SearchQueryNotifier, String>(
  _SearchQueryNotifier.new,
);

// ══════════════════════════════════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════════════════════════════════

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _ctrl.addListener(() {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          final q = _ctrl.text.trim();
          ref.read(_searchQueryProvider.notifier).set(q);
          // Save to history when user pauses typing
          if (q.length > 2) {
            ref.read(recentlyPlayedServiceProvider).addSearch(q).then((_) {
              ref.invalidate(searchHistoryProvider);
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final isSearching = query.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SEARCH'),
        bottom: isSearching
            ? TabBar(
                controller: _tabs,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.pink,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'SONGS'),
                  Tab(text: 'ALBUMS'),
                  Tab(text: 'ARTISTS'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Search input ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: NeoTextField(
              controller: _ctrl,
              hintText: 'Songs, artists, albums…',
            ),
          ),

          // ── Content area ───────────────────────────────────────────────────
          Expanded(
            child: isSearching
                ? TabBarView(
                    controller: _tabs,
                    children: [
                      _SongTab(query: query),
                      _AlbumTab(query: query),
                      _ArtistTab(query: query),
                    ],
                  )
                : _TrendingTab(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tabs
// ══════════════════════════════════════════════════════════════════════════════

// ── Trending (empty state) + Search History ─────────────────────────────────

class _TrendingTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(searchHistoryProvider);
    final trendingAsync = ref.watch(saavnTrendingProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        // Search History
        historyAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (history) {
            if (history.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RECENT SEARCHES',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await RecentlyPlayedService().clearSearchHistory();
                        ref.invalidate(searchHistoryProvider);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.pink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: history.take(10).map((q) {
                    return GestureDetector(
                      onTap: () {
                        _setSearchQuery(ref, q);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.yellow, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              q,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // Recently Played
        Consumer(
          builder: (_, ref, __) {
            final recentAsync = ref.watch(recentlyPlayedProvider);
            return recentAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (songs) {
                if (songs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECENTLY PLAYED',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: songs.take(15).length,
                        itemBuilder: (ctx, i) {
                          final song = songs[i];
                          return GestureDetector(
                            onTap: () => ref
                                .read(musicServiceProvider)
                                .playQueue(songs, i, ref),
                            child: Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.cyan, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: song.coverUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.music_note),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          },
        ),

        // Trending Now
        const Text(
          'TRENDING NOW',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        trendingAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.pink),
          ),
          error: (e, _) => _errorText(e.toString()),
          data: (songs) => _SongList(songs: songs),
        ),
      ],
    );
  }

  void _setSearchQuery(WidgetRef ref, String q) {
    ref.read(_searchQueryProvider.notifier).set(q);
  }
}

// ── Songs tab ───────────────────────────────────────────────────────────────

class _SongTab extends ConsumerWidget {
  final String query;
  const _SongTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(saavnSongSearchProvider(query));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.pink)),
      error: (e, _) => _errorText(e.toString()),
      data: (songs) => songs.isEmpty
          ? _emptyState('No songs found for "$query"')
          : _SongList(songs: songs),
    );
  }
}

// ── Albums tab ───────────────────────────────────────────────────────────────

class _AlbumTab extends ConsumerWidget {
  final String query;
  const _AlbumTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(saavnAlbumSearchProvider(query));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.pink)),
      error: (e, _) => _errorText(e.toString()),
      data: (albums) => albums.isEmpty
          ? _emptyState('No albums found for "$query"')
          : _AlbumList(albums: albums),
    );
  }
}

// ── Artists tab ──────────────────────────────────────────────────────────────

class _ArtistTab extends ConsumerWidget {
  final String query;
  const _ArtistTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(saavnArtistSearchProvider(query));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.pink)),
      error: (e, _) => _errorText(e.toString()),
      data: (artists) => artists.isEmpty
          ? _emptyState('No artists found for "$query"')
          : _ArtistList(artists: artists),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Song list widget
// ══════════════════════════════════════════════════════════════════════════════

class _SongList extends ConsumerWidget {
  final List<SongModel> songs;
  const _SongList({required this.songs});

  static const _colors = [
    AppColors.yellow,
    AppColors.cyan,
    AppColors.green,
    AppColors.purple,
    AppColors.pink,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final song = songs[i];
        final color = _colors[i % _colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () =>
                ref.read(musicServiceProvider).playQueue(songs, i, ref),
            child: NeoBox(
              color: color,
              padding: const EdgeInsets.all(10),
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
                        placeholder: (_, _) =>
                            const ColoredBox(color: Colors.black12),
                        errorWidget: (_, _, _) => const Icon(Icons.music_note),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
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
                        Text(
                          song.artist,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                        ),
                        if (song.genre.isNotEmpty)
                          Text(
                            song.genre,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.play_arrow,
                    size: 28,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Album list widget
// ══════════════════════════════════════════════════════════════════════════════

class _AlbumList extends StatelessWidget {
  final List<Map<String, dynamic>> albums;
  const _AlbumList({required this.albums});

  static const _colors = [
    AppColors.cyan,
    AppColors.purple,
    AppColors.green,
    AppColors.yellow,
    AppColors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final album = albums[i];
        final color = _colors[i % _colors.length];
        final name = album['name'] as String? ?? 'Unknown Album';
        final artist = album['artist'] as String? ?? '';
        final year = album['year']?.toString() ?? '';
        final lang = album['language'] as String? ?? '';
        final id = album['id']?.toString() ?? '';

        // Image
        final imgList =
            (album['image'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final coverUrl = imgList.isNotEmpty
            ? (imgList.last['url'] as String? ?? '')
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              if (id.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AlbumScreen(albumId: id)),
                );
              }
            },
            child: NeoBox(
              color: color,
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Cover
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  const ColoredBox(color: Colors.black12),
                              errorWidget: (_, _, _) => const Icon(Icons.album),
                            )
                          : const Icon(Icons.album),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artist.isNotEmpty)
                          Text(
                            artist,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                          ),
                        Row(
                          children: [
                            if (year.isNotEmpty) _tag(year),
                            if (lang.isNotEmpty) _tag(lang),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right,
                    size: 26,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tag(String label) => Container(
    margin: const EdgeInsets.only(right: 4, top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: AppColors.border, width: 1),
    ),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Artist list widget
// ══════════════════════════════════════════════════════════════════════════════

class _ArtistList extends StatelessWidget {
  final List<Map<String, dynamic>> artists;
  const _ArtistList({required this.artists});

  static const _colors = [
    AppColors.purple,
    AppColors.pink,
    AppColors.cyan,
    AppColors.yellow,
    AppColors.green,
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final artist = artists[i];
        final color = _colors[i % _colors.length];
        final name = artist['name'] as String? ?? 'Unknown Artist';

        final imgList =
            (artist['image'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final imgUrl = imgList.isNotEmpty
            ? (imgList.last['url'] as String? ?? '')
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NeoBox(
            color: color,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Artist photo (circular)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: ClipOval(
                    child: imgUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const ColoredBox(color: Colors.black12),
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.person, size: 28),
                          )
                        : const Icon(Icons.person, size: 28),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const Icon(
                  Icons.chevron_right,
                  size: 26,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

Widget _emptyState(String message) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🔍', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _errorText(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
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
    ),
  );
}
