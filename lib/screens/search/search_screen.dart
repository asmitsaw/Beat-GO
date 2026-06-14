import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../components/neo_text_field.dart';
import '../../models/song_model.dart';
import '../../services/music_service.dart';

// ── Genres ─────────────────────────────────────────────────────────────────
const _genres = ['All', 'Electronic', 'Hip-Hop', 'Pop', 'Rock', 'Jazz', 'Chill', 'Workout'];

// ── Providers ──────────────────────────────────────────────────────────────
class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

class _SelectedGenreNotifier extends Notifier<String> {
  @override
  String build() => 'All';
  void set(String v) => state = v;
}

final _searchQueryProvider   = NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);
final _selectedGenreProvider = NotifierProvider<_SelectedGenreNotifier, String>(_SelectedGenreNotifier.new);

final _searchResultsProvider = FutureProvider<List<SongModel>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  final genre = ref.watch(_selectedGenreProvider);
  return ref.read(musicServiceProvider).fetchSongs(
    query: query.isEmpty ? null : query,
    genre: genre == 'All' ? null : genre,
  );
});

final _trendingProvider = FutureProvider<List<SongModel>>((ref) async {
  return ref.read(musicServiceProvider).fetchTrending(limit: 10);
});

// ── Screen ─────────────────────────────────────────────────────────────────
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      // Debounce by using the state directly (provider rebuilds)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) ref.read(_searchQueryProvider.notifier).set(_ctrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query        = ref.watch(_searchQueryProvider);
    final selectedGenre = ref.watch(_selectedGenreProvider);
    final isSearching  = query.isNotEmpty || selectedGenre != 'All';
    final resultsAsync = ref.watch(isSearching
        ? _searchResultsProvider
        : _trendingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('SEARCH')),
      body: Column(children: [
        // ── Search Input ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: NeoTextField(controller: _ctrl, hintText: 'Songs, artists, albums…'),
        ),

        // ── Genre chips ───────────────────────────────────────────────────
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _genres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final genre    = _genres[i];
              final selected = genre == selectedGenre;
              return GestureDetector(
                onTap: () => ref
                    .read(_selectedGenreProvider.notifier)
                    .set(genre),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color:  selected ? AppColors.pink : AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.border,
                        width: selected ? 3 : 2),
                    boxShadow: selected
                        ? const [BoxShadow(
                            color: Colors.black, offset: Offset(3, 3))]
                        : const [],
                  ),
                  child: Text(genre,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 13)),
                ),
              );
            },
          ),
        ),

        // ── Section label ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isSearching ? 'RESULTS' : 'TRENDING NOW',
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.textSecondary),
            ),
          ),
        ),

        // ── Results ───────────────────────────────────────────────────────
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.pink)),
            error: (e, _) =>
                Center(child: Text('Search error: $e')),
            data: (songs) => songs.isEmpty
                ? _EmptyResults(query: query)
                : _SongResults(songs: songs),
          ),
        ),
      ]),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final String query;
  const _EmptyResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔍', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(query.isNotEmpty
            ? 'No results for "$query"'
            : 'No songs in this genre yet.',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _SongResults extends ConsumerWidget {
  final List<SongModel> songs;
  const _SongResults({required this.songs});

  static const _colors = [
    AppColors.yellow, AppColors.cyan, AppColors.green,
    AppColors.purple, AppColors.pink
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final song = songs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () =>
                ref.read(musicServiceProvider).playQueue(songs, i, ref),
            child: NeoBox(
              color: _colors[i % _colors.length],
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
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
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(song.artist,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow, size: 28),
              ]),
            ),
          ),
        );
      },
    );
  }
}
