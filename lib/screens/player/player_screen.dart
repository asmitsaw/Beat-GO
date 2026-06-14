import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../models/song_model.dart';
import '../../services/music_service.dart';
import '../../services/playlist_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Screen
// ─────────────────────────────────────────────────────────────────────────────

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _showQueue(BuildContext context) {
    final queue = ref.read(queueProvider);
    final currentSong = ref.read(currentSongProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QueueSheet(queue: queue, currentSongId: currentSong?.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSong    = ref.watch(currentSongProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync  = ref.watch(positionProvider);
    final durationAsync  = ref.watch(durationProvider);
    final shuffleAsync   = ref.watch(shuffleProvider);
    final loopAsync      = ref.watch(loopModeProvider);
    final likedIds       = ref.watch(likedSongIdsProvider).value ?? {};

    if (currentSong == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_off_rounded, size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Text('No song playing',
                  style: TextStyle(fontSize: 18, color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final isPlaying = isPlayingAsync.value ?? false;
    final position  = positionAsync.value  ?? Duration.zero;
    final duration  = durationAsync.value  ?? const Duration(minutes: 3);
    final shuffle   = shuffleAsync.value   ?? false;
    final loop      = loopAsync.value      ?? LoopMode.off;
    final isLiked   = likedIds.contains(currentSong.id);

    // Keep rotation running only while playing
    if (isPlaying) {
      if (!_rotationCtrl.isAnimating) _rotationCtrl.repeat();
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    } else {
      _rotationCtrl.stop();
      _pulseCtrl.stop();
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Blurred cover art background ──────────────────────────────────
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: currentSong.coverUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  Container(color: AppColors.purple),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withAlpha(180),
                      AppColors.background.withAlpha(230),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 36),
                        color: AppColors.textPrimary,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'NOW PLAYING',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.queue_music_rounded, size: 28),
                        color: AppColors.textPrimary,
                        onPressed: () => _showQueue(context),
                      ),
                    ],
                  ),
                ),

                // ── Rotating album art ───────────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Center(
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: RotationTransition(
                        turns: _rotationCtrl,
                        child: NeoBox(
                          color: AppColors.background,
                          padding: EdgeInsets.zero,
                          borderRadius: size.width * 0.45,
                          shadowOffset: const Offset(6, 6),
                          width:  size.width * 0.72,
                          height: size.width * 0.72,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(size.width * 0.45),
                            child: CachedNetworkImage(
                              imageUrl: currentSong.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: AppColors.purple),
                              errorWidget: (_, _, _) => const Icon(
                                  Icons.music_note,
                                  size: 80,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Song info ────────────────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentSong.title,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentSong.artist,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (currentSong.album.isNotEmpty)
                                    Text(
                                      currentSong.album,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Like button
                            NeoBox(
                              color: isLiked ? AppColors.pink : AppColors.background,
                              padding: const EdgeInsets.all(10),
                              borderRadius: 40,
                              child: GestureDetector(
                                onTap: () async {
                                  await ref
                                      .read(playlistServiceProvider)
                                      .toggleLike(currentSong.id, isLiked);
                                  ref.invalidate(likedSongIdsProvider);
                                },
                                child: Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isLiked
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Progress bar ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor:   AppColors.textPrimary,
                          inactiveTrackColor: const Color(0x44000000),
                          thumbColor:         AppColors.yellow,
                          overlayColor:       const Color(0x33FFD166),
                          trackHeight:        5,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                        ),
                        child: Slider(
                          min: 0,
                          max: duration.inMilliseconds
                              .toDouble()
                              .clamp(1, double.infinity),
                          value: position.inMilliseconds
                              .toDouble()
                              .clamp(0, duration.inMilliseconds.toDouble()),
                          onChanged: (v) => ref
                              .read(musicServiceProvider)
                              .seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(position),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            Text(_fmt(duration),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Main controls ────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      _ControlButton(
                        icon: Icons.shuffle_rounded,
                        active: shuffle,
                        onTap: () =>
                            ref.read(musicServiceProvider).toggleShuffle(),
                      ),

                      // Previous
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: AppColors.textPrimary,
                        onPressed: () =>
                            ref.read(musicServiceProvider).seekToPrevious(),
                      ),

                      // Play / Pause
                      GestureDetector(
                        onTap: () => isPlaying
                            ? ref.read(musicServiceProvider).pause()
                            : ref.read(musicServiceProvider).resume(),
                        child: NeoBox(
                          color: AppColors.yellow,
                          borderRadius: 50,
                          padding: const EdgeInsets.all(18),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 44,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),

                      // Next
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: AppColors.textPrimary,
                        onPressed: () =>
                            ref.read(musicServiceProvider).seekToNext(),
                      ),

                      // Repeat
                      _ControlButton(
                        icon: loop == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        active: loop != LoopMode.off,
                        onTap: () =>
                            ref.read(musicServiceProvider).cycleRepeatMode(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small control button (shuffle / repeat)
// ─────────────────────────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: AppColors.border, width: 2)
              : null,
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 26,
          color: active ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Queue bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _QueueSheet extends StatelessWidget {
  final List<SongModel> queue;
  final String? currentSongId;

  const _QueueSheet({required this.queue, required this.currentSongId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: const Border(
              top:   BorderSide(color: AppColors.border, width: 3),
              left:  BorderSide(color: AppColors.border, width: 3),
              right: BorderSide(color: AppColors.border, width: 3),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(0, -4), blurRadius: 0)
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'UP NEXT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: queue.isEmpty
                    ? const Center(
                        child: Text('Queue is empty',
                            style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: queue.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (_, i) {
                          final song = queue[i];
                          final isCurrent = song.id == currentSongId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.yellow
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.border, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(3, 3),
                                    blurRadius: 0)
                              ],
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
                                    errorWidget: (_, _, _) => Container(
                                      width: 44,
                                      height: 44,
                                      color: AppColors.purple,
                                      child: const Icon(Icons.music_note,
                                          size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCurrent
                                              ? AppColors.textPrimary
                                              : AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        song.artist,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(Icons.graphic_eq_rounded,
                                      color: AppColors.textPrimary, size: 22),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
