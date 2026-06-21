import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../models/song_model.dart';
import '../../services/auth_service.dart';
import '../../services/saavn_service.dart';
import '../../services/music_service.dart';

// ── Retro Pixel Art Avatar Widget ────────────────────────────────────────────
class PixelAvatar extends StatelessWidget {
  final String email;
  final double size;

  const PixelAvatar({super.key, required this.email, this.size = 80});

  @override
  Widget build(BuildContext context) {
    int hash = 0;
    for (int i = 0; i < email.length; i++) {
      hash = email.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final colors = [
      AppColors.pink,
      AppColors.cyan,
      AppColors.green,
      AppColors.yellow,
      AppColors.purple,
    ];
    final mainColor = colors[hash.abs() % colors.length];

    // Generate 8x8 symmetric grid (8 columns, 8 rows)
    final grid = List.generate(8, (r) => List.generate(8, (c) => false));
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 4; c++) {
        final bitIndex = (r * 4 + c) % 32;
        final isFilled = ((hash.abs() >> bitIndex) & 1) == 1;
        grid[r][c] = isFilled;
        grid[r][7 - c] = isFilled; // Mirror
      }
    }

    final innerPadding = size * 0.08;
    final pixelSize = (size - (innerPadding * 2)) / 8;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: AppColors.border, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          )
        ],
      ),
      padding: EdgeInsets.all(innerPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(8, (r) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(8, (c) {
              final isFilled = grid[r][c];
              return Container(
                width: pixelSize - 1,
                height: pixelSize - 1,
                color: isFilled ? mainColor : Colors.transparent,
              );
            }),
          );
        }),
      ),
    );
  }
}

// ── Profile Statistics Model ────────────────────────────────────────────────
class ProfileStats {
  final List<SongModel> topSongs;
  final List<MapEntry<String, int>> topArtists;
  final int totalListens;

  ProfileStats({
    required this.topSongs,
    required this.topArtists,
    required this.totalListens,
  });
}

// ── Riverpod Provider for Listening Stats ────────────────────────────────────
final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) {
    return ProfileStats(topSongs: [], topArtists: [], totalListens: 0);
  }

  // Fetch listening events from Supabase
  final response = await supabase
      .from('listen_events')
      .select()
      .eq('uid', uid)
      .order('listened_at', ascending: false);

  final events = List<Map<String, dynamic>>.from(response as List);
  if (events.isEmpty) {
    return ProfileStats(topSongs: [], topArtists: [], totalListens: 0);
  }

  // Group and count song plays
  final songCounts = <String, int>{};
  for (final ev in events) {
    final songId = ev['song_id'] as String?;
    if (songId != null && songId.isNotEmpty) {
      songCounts[songId] = (songCounts[songId] ?? 0) + 1;
    }
  }

  // Sort song IDs by play count
  final sortedSongEntries = songCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topSongIds = sortedSongEntries.take(5).map((e) => e.key).toList();

  if (topSongIds.isEmpty) {
    return ProfileStats(topSongs: [], topArtists: [], totalListens: events.length);
  }

  // Fetch song details
  // 1. Check local songs database
  final dbSongsResponse = await supabase
      .from('songs')
      .select()
      .inFilter('id', topSongIds);

  final dbSongs = List<Map<String, dynamic>>.from(dbSongsResponse as List)
      .map((r) => SongModel.fromMap(r))
      .toList();

  final foundLocalIds = dbSongs.map((s) => s.id).toSet();
  final missingIds = topSongIds.where((id) => !foundLocalIds.contains(id)).toList();

  // 2. Fetch missing tracks from JioSaavn
  List<SongModel> saavnSongs = [];
  if (missingIds.isNotEmpty) {
    saavnSongs = await SaavnService().getSongsDetails(missingIds);
  }

  // Combine song metadata
  final allSongsMap = {
    for (final s in dbSongs) s.id: s,
    for (final s in saavnSongs) s.id: s,
  };

  final topSongs = topSongIds
      .map((id) => allSongsMap[id])
      .whereType<SongModel>()
      .toList();

  // Compute artist statistics
  final artistCounts = <String, int>{};
  for (final entry in songCounts.entries) {
    final songId = entry.key;
    final count = entry.value;
    final song = allSongsMap[songId];
    if (song != null) {
      final artists = song.artist.split(',').map((a) => a.trim());
      for (final artist in artists) {
        if (artist.isNotEmpty) {
          artistCounts[artist] = (artistCounts[artist] ?? 0) + count;
        }
      }
    }
  }

  final topArtists = artistCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return ProfileStats(
    topSongs: topSongs,
    topArtists: topArtists.take(3).toList(),
    totalListens: events.length,
  );
});

// ── Profile Screen ───────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authServiceProvider).currentUser;
    final statsAsync = ref.watch(profileStatsProvider);

    final email = user?.email ?? 'Unknown User';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MUSIC PROFILE'),
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.pink),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading stats: $err',
            style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.bold),
          ),
        ),
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header profile card ────────────────────────────────────────
              Row(
                children: [
                  PixelAvatar(email: email, size: 84),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email.split('@').first.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          email,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: Text(
                            '${stats.totalListens} TOTAL SCROBBLES',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Top Tracks section ─────────────────────────────────────────
              _sectionHeader('🎧 YOUR TOP TRACKS'),
              if (stats.topSongs.isEmpty)
                _emptyStateCard('No top songs yet. Start playing music to generate stats!')
              else
                ...List.generate(stats.topSongs.length, (i) {
                  final song = stats.topSongs[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        ref.read(musicServiceProvider).playQueue(stats.topSongs, i, ref);
                      },
                      child: NeoBox(
                        color: _getRankColor(i),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Rank Number Badge
                            Container(
                              width: 26,
                              alignment: Alignment.center,
                              child: Text(
                                '#${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Cover art
                            Container(
                              width: 44,
                              height: 44,
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
                            const SizedBox(width: 12),
                            // Metadata
                            Expanded(
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
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_arrow_rounded, size: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // ── Top Artists section ────────────────────────────────────────
              _sectionHeader('👑 TOP ARTISTS'),
              if (stats.topArtists.isEmpty)
                _emptyStateCard('No top artists data.')
              else
                NeoBox(
                  color: AppColors.yellow,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    children: List.generate(stats.topArtists.length, (i) {
                      final artistEntry = stats.topArtists[i];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  '#${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    artistEntry.key.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${artistEntry.value} PLAYS',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < stats.topArtists.length - 1)
                            const Divider(height: 1, color: Colors.black26),
                        ],
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 2),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _emptyStateCard(String msg) => NeoBox(
        color: Colors.black12,
        padding: const EdgeInsets.all(16),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );

  Color _getRankColor(int index) {
    final colors = [
      AppColors.cyan,
      AppColors.pink,
      AppColors.green,
      AppColors.yellow,
      AppColors.purple,
    ];
    return colors[index % colors.length];
  }
}
