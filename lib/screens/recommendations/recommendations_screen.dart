import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../models/user_preferences_model.dart';
import '../../providers/recommendations_provider.dart';
import '../../components/neo_box.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Recommendations Screen — "For You" tab
// ══════════════════════════════════════════════════════════════════════════════

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  String? _activeLanguageFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(userPreferencesProvider);
    final forYouAsync = ref.watch(forYouRecommendationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : AppColors.background,
      body: prefsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.pink),
        ),
        error: (e, _) => _EmptyState(onSetup: _openPreferences),
        data: (prefs) {
          if (prefs.isEmpty) {
            return _EmptyState(onSetup: _openPreferences);
          }
          return _buildContent(prefs, forYouAsync, isDark);
        },
      ),
    );
  }

  Widget _buildContent(
    UserPreferences prefs,
    AsyncValue<List<SongRecommendation>> forYouAsync,
    bool isDark,
  ) {
    return RefreshIndicator(
      color: AppColors.pink,
      onRefresh: () async {
        ref.invalidate(forYouRecommendationsProvider);
      },
      child: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor:
                isDark ? const Color(0xFF1A1A2E) : AppColors.background,
            title: const Text(
              'FOR YOU',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Adjust preferences',
                onPressed: _openPreferences,
              ),
            ],
          ),

          // ── User taste summary chip row ─────────────────────────────────
          SliverToBoxAdapter(child: _TasteChips(prefs: prefs)),

          // ── Language filter tabs ────────────────────────────────────────
          if (prefs.languages.isNotEmpty)
            SliverToBoxAdapter(
              child: _LanguageFilterBar(
                languages: prefs.languages,
                active: _activeLanguageFilter,
                onSelect: (lang) =>
                    setState(() => _activeLanguageFilter = lang),
              ),
            ),

          // ── "Made For You" horizontal row ──────────────────────────────
          const SliverToBoxAdapter(child: _SectionHeader(title: '✨ MADE FOR YOU')),
          SliverToBoxAdapter(
            child: forYouAsync.when(
              loading: () => const _HLoader(),
              error: (_, __) => const _ErrorBanner(msg: 'Could not load recommendations'),
              data: (recs) {
                final filtered = _activeLanguageFilter == null
                    ? recs
                    : recs
                        .where((r) =>
                            r.language.toLowerCase() ==
                            _activeLanguageFilter!.toLowerCase())
                        .toList();
                return _ForYouCarousel(recommendations: filtered);
              },
            ),
          ),

          // ── Per-language sections ───────────────────────────────────────
          for (final lang in prefs.languages.take(4))
            if (_activeLanguageFilter == null ||
                _activeLanguageFilter!.toLowerCase() == lang.toLowerCase()) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(title: '🎵 POPULAR IN ${lang.toUpperCase()}'),
              ),
              SliverToBoxAdapter(
                child: _LanguageSection(language: lang),
              ),
            ],

          // ── Bottom padding ─────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  void _openPreferences() {
    Navigator.of(context).pushNamed('/onboarding').then((_) {
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(forYouRecommendationsProvider);
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Taste Chips — small summary of user's selected moods
// ══════════════════════════════════════════════════════════════════════════════

class _TasteChips extends StatelessWidget {
  final UserPreferences prefs;
  const _TasteChips({required this.prefs});

  @override
  Widget build(BuildContext context) {
    if (prefs.moods.isEmpty && prefs.singers.isEmpty) return const SizedBox.shrink();

    final chips = [...prefs.moods.take(3), ...prefs.singers.take(3)];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Chip(
          label: Text(
            chips[i],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: _chipColor(i),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
      ),
    );
  }

  Color _chipColor(int i) {
    const colors = [
      AppColors.pink, AppColors.cyan, AppColors.yellow,
      AppColors.green, AppColors.purple,
    ];
    return colors[i % colors.length].withOpacity(0.25);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Language Filter Bar
// ══════════════════════════════════════════════════════════════════════════════

class _LanguageFilterBar extends StatelessWidget {
  final List<String> languages;
  final String? active;
  final ValueChanged<String?> onSelect;

  const _LanguageFilterBar({
    required this.languages,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = ['All', ...languages];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = all[i];
          final isActive =
              (i == 0 && active == null) || label == active;

          return GestureDetector(
            onTap: () => onSelect(i == 0 ? null : label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.pink : Colors.transparent,
                border: Border.all(
                  color: isActive ? AppColors.pink : Colors.grey.withOpacity(0.4),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.textPrimary),
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
// "For You" horizontal carousel — ML recommendation cards
// ══════════════════════════════════════════════════════════════════════════════

class _ForYouCarousel extends StatelessWidget {
  final List<SongRecommendation> recommendations;
  const _ForYouCarousel({required this.recommendations});

  static const _cardColors = [
    AppColors.pink, AppColors.cyan, AppColors.yellow,
    AppColors.green, AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyRecsCard(),
      );
    }
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recommendations.length,
        itemBuilder: (_, i) {
          final rec   = recommendations[i];
          final color = _cardColors[i % _cardColors.length];

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _RecommendationCard(rec: rec, color: color),
          );
        },
      ),
    );
  }
}

// ── Individual recommendation card ──────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final SongRecommendation rec;
  final Color color;
  const _RecommendationCard({required this.rec, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (rec.score * 100).round();

    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Vibe score badge ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⚡ $pct% match',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Song name ────────────────────────────────────────────────
          Text(
            rec.songName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.black,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          // ── Singer ───────────────────────────────────────────────────
          Text(
            rec.singer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // ── Language tag + search icon ────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black26, width: 1),
                ),
                child: Text(
                  rec.language,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _searchAndPlay(context, rec),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _searchAndPlay(BuildContext context, SongRecommendation rec) {
    // Navigate to search screen with the song pre-filled
    // This integrates with the existing search → JioSaavn flow
    Navigator.of(context).pushNamed('/search',
        arguments: '${rec.songName} ${rec.singer}');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Per-language section
// ══════════════════════════════════════════════════════════════════════════════

class _LanguageSection extends ConsumerWidget {
  final String language;
  const _LanguageSection({required this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(languageRecommendationsProvider(language));

    return recsAsync.when(
      loading: () => const _HLoader(),
      error: (_, __) => const SizedBox.shrink(),
      data: (recs) {
        if (recs.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recs.length,
            itemBuilder: (_, i) {
              final rec = recs[i];
              return _LanguageSongTile(rec: rec, index: i);
            },
          ),
        );
      },
    );
  }
}

class _LanguageSongTile extends StatelessWidget {
  final SongRecommendation rec;
  final int index;
  const _LanguageSongTile({required this.rec, required this.index});

  static const _colors = [
    AppColors.yellow, AppColors.cyan, AppColors.pink,
    AppColors.green, AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).pushNamed('/search',
              arguments: '${rec.songName} ${rec.singer}'),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Index number
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    rec.songName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.singer,
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
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Empty States & Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final VoidCallback onSetup;
  const _EmptyState({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎧', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'Tell us what you love',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Set up your music preferences to get personalized recommendations powered by our ML engine.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pink,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black, width: 2.5),
                ),
              ),
              child: const Text(
                '🎵  SET UP MY TASTE',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecsCard extends StatelessWidget {
  const _EmptyRecsCard();

  @override
  Widget build(BuildContext context) {
    return NeoBox(
      color: AppColors.yellow,
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Text('🎵', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Recommendations load as you listen more. Try searching for songs!',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _HLoader extends StatelessWidget {
  const _HLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator(color: AppColors.pink)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeoBox(
        color: AppColors.pink,
        padding: const EdgeInsets.all(12),
        child: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
