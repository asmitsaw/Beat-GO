import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../models/song_model.dart';
import 'package:flutter/rendering.dart';
import '../../services/music_service.dart' hide debugPrint;
import '../../services/playlist_service.dart';
import '../../services/sleep_timer_service.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/share_card_widget.dart';
import '../../providers/sync_group_provider.dart';
import '../sync/sync_group_screen.dart';
import 'equalizer_screen.dart';

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
    final currentSong = ref.read(currentSongProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QueueSheet(currentSongId: currentSong?.id),
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

    final activeGroup    = ref.watch(activeSyncGroupProvider);
    final isHost         = ref.watch(isSyncHostProvider);
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
                        icon: const Icon(Icons.radio_rounded, size: 24),
                        color: activeGroup != null ? AppColors.pink : AppColors.textPrimary,
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const SyncGroupSheet(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 26),
                        color: AppColors.textPrimary,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EqualizerScreen()),
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
                                        .read(likedSongsProvider.notifier)
                                        .toggleLike(currentSong);
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
                          onChanged: (v) async {
                            final targetPos = Duration(milliseconds: v.toInt());
                            await ref.read(musicServiceProvider).seek(targetPos);
                            if (isHost) {
                              ref.read(syncGroupServiceProvider).broadcastHostPlayback(
                                song: currentSong,
                                isPlaying: isPlaying,
                                position: targetPos,
                                ref: ref,
                              );
                            }
                          },
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
                        onTap: () async {
                          final music = ref.read(musicServiceProvider);
                          if (isPlaying) {
                            await music.pause();
                            if (isHost) {
                              ref.read(syncGroupServiceProvider).broadcastHostPlayback(
                                song: currentSong,
                                isPlaying: false,
                                position: position,
                                ref: ref,
                              );
                            }
                          } else {
                            await music.resume();
                            if (isHost) {
                              ref.read(syncGroupServiceProvider).broadcastHostPlayback(
                                song: currentSong,
                                isPlaying: true,
                                position: position,
                                ref: ref,
                              );
                            }
                          }
                        },
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

                // ── Action row: Lyrics | Share | Sleep Timer ─────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Lyrics
                      _ActionChip(
                        icon: Icons.lyrics_outlined,
                        label: 'LYRICS',
                        color: AppColors.cyan,
                        onTap: () => _showLyrics(context, currentSong),
                      ),
                      // Share
                      _ActionChip(
                        icon: Icons.share_outlined,
                        label: 'SHARE',
                        color: AppColors.green,
                        onTap: () => _shareSong(currentSong),
                      ),
                      // Sleep Timer
                      _SleepTimerChip(),
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

  // ── Lyrics sheet ─────────────────────────────────────────────────────────
  void _showLyrics(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LyricsSheet(song: song),
    );
  }

  // ── Share ────────────────────────────────────────────────────────────────
  void _shareSong(SongModel song) {
    final cardKey = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border, width: 3),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SHARE SONG',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview of the card
              RepaintBoundary(
                key: cardKey,
                child: ShareCardWidget(song: song),
              ),
              const SizedBox(height: 20),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        side: const BorderSide(color: AppColors.border, width: 2),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: () async {
                        // Show loader
                        showDialog(
                          context: ctx,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                            child: CircularProgressIndicator(color: AppColors.pink),
                          ),
                        );

                        try {
                          final boundary = cardKey.currentContext!
                              .findRenderObject() as RenderRepaintBoundary;
                          final image = await boundary.toImage(pixelRatio: 3.0);
                          final byteData = await image.toByteData(
                              format: ui.ImageByteFormat.png);
                          final pngBytes = byteData!.buffer.asUint8List();

                          final tempDir = await getTemporaryDirectory();
                          final file = await File(
                                  '${tempDir.path}/share_${song.id}.png')
                              .create();
                          await file.writeAsBytes(pngBytes);

                          // Pop loading
                          if (ctx.mounted) Navigator.pop(ctx);
                          // Pop share dialog
                          if (ctx.mounted) Navigator.pop(ctx);

                          await SharePlus.instance.share(
                            ShareParams(
                              text: '🎵 Listen to "${song.title}" by ${song.artist} on Retro Beats!',
                              files: [XFile(file.path)],
                            ),
                          );
                        } catch (e) {
                          // Pop loading if active
                          if (ctx.mounted) Navigator.pop(ctx);
                          debugPrint('Error generating share image: $e');
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'IMAGE CARD',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        side: const BorderSide(color: AppColors.border, width: 2),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await SharePlus.instance.share(
                          ShareParams(
                            text: '🎵 Listen to "${song.title}" by ${song.artist} on Retro Beats!',
                            subject: song.title,
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'TEXT LINK',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Action chip (Lyrics / Share / Sleep Timer)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleep Timer Chip — shows remaining time when active
// ─────────────────────────────────────────────────────────────────────────────

class _SleepTimerChip extends ConsumerWidget {
  const _SleepTimerChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);

    return GestureDetector(
      onTap: () => _showSleepTimerSheet(context, ref, timer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: timer.isActive
              ? AppColors.pink.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: timer.isActive ? AppColors.pink : AppColors.textSecondary,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bedtime_outlined,
              size: 16,
              color: timer.isActive ? AppColors.pink : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              timer.isActive ? _fmtRemaining(timer.remaining!) : 'SLEEP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: timer.isActive ? AppColors.pink : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtRemaining(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _showSleepTimerSheet(
      BuildContext context, WidgetRef ref, SleepTimerState timer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SleepTimerSheet(isActive: timer.isActive),
    );
  }
}

class _SleepTimerSheet extends ConsumerWidget {
  final bool isActive;
  const _SleepTimerSheet({required this.isActive});

  static const _options = [
    ('15 min', Duration(minutes: 15)),
    ('30 min', Duration(minutes: 30)),
    ('45 min', Duration(minutes: 45)),
    ('1 hour', Duration(hours: 1)),
    ('90 min', Duration(minutes: 90)),
    ('2 hours', Duration(hours: 2)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top:   BorderSide(color: AppColors.border, width: 3),
          left:  BorderSide(color: AppColors.border, width: 3),
          right: BorderSide(color: AppColors.border, width: 3),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black, offset: Offset(0, -4), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 48, height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Text(
            '🌙  SLEEP TIMER',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          // Options grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: _options.map((opt) {
              final (label, dur) = opt;
              return GestureDetector(
                onTap: () {
                  ref.read(sleepTimerProvider.notifier).start(dur);
                  Navigator.pop(context);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                ref.read(sleepTimerProvider.notifier).cancel();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black,
                        offset: Offset(3, 3),
                        blurRadius: 0),
                  ],
                ),
                child: const Text(
                  '✕  CANCEL TIMER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lyrics Sheet — fetches from lyrics.ovh (free API)
// ─────────────────────────────────────────────────────────────────────────────

class _LyricsSheet extends StatefulWidget {
  final SongModel song;
  const _LyricsSheet({required this.song});

  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  String? _lyrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  String _cleanLyrics(String rawLyrics) {
    // Remove LRC timestamps like [00:12.34] or [00:12] or [00:12.345]
    final regExp = RegExp(r'\[\d{2}:\d{2}(?:\.\d{2,3})?\]');
    return rawLyrics.replaceAll(regExp, '').trim();
  }

  String _cleanTitle(String title) {
    // Remove (From "Movie"), (Remix), [From "Movie"], (feat. ...), (with ...), (Single Version), etc.
    var cleaned = title.replaceAll(RegExp(r'\([^)]*\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    // Remove " - Single", " - EP", " - Remix", etc.
    cleaned = cleaned.split(' - ').first;
    return cleaned.trim();
  }

  String _cleanArtist(String artist) {
    // Take only the first artist before comma, feat., &, and
    var cleaned = artist.split(RegExp(r',|&|feat\.|\b(?:and)\b', caseSensitive: false)).first;
    return cleaned.trim();
  }

  Future<void> _fetchLyrics() async {
    try {
      final rawTitle = widget.song.title;
      final rawArtist = widget.song.artist;
      final album = widget.song.album;
      final durationSec = (widget.song.durationMs / 1000).round();

      final title = _cleanTitle(rawTitle);
      final artist = _cleanArtist(rawArtist);

      debugPrint('Fetching lyrics for cleaned title: "$title", cleaned artist: "$artist"');

      // 1. Try LRCLIB /api/get (exact matching with duration)
      try {
        final queryParams = {
          'track_name': title,
          'artist_name': artist,
          if (album.isNotEmpty) 'album_name': album,
          if (durationSec > 0) 'duration': durationSec.toString(),
        };
        final uri = Uri.parse('https://lrclib.net/api/get').replace(queryParameters: queryParams);
        final response = await http.get(uri, headers: {
          'User-Agent': 'RetroBeats/1.0.0 (https://github.com/asmitsaw/Beat-GO-)'
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final lyrics = (data['syncedLyrics'] as String?)?.isNotEmpty == true
              ? data['syncedLyrics'] as String
              : data['plainLyrics'] as String?;
          if (lyrics != null && lyrics.isNotEmpty) {
            if (mounted) {
              setState(() {
                _lyrics = _cleanLyrics(lyrics);
                _loading = false;
              });
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('LRCLIB get error: $e');
      }

      // 2. Try LRCLIB /api/get without duration/album (to be less strict)
      try {
        final queryParams = {
          'track_name': title,
          'artist_name': artist,
        };
        final uri = Uri.parse('https://lrclib.net/api/get').replace(queryParameters: queryParams);
        final response = await http.get(uri, headers: {
          'User-Agent': 'RetroBeats/1.0.0 (https://github.com/asmitsaw/Beat-GO-)'
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final lyrics = (data['syncedLyrics'] as String?)?.isNotEmpty == true
              ? data['syncedLyrics'] as String
              : data['plainLyrics'] as String?;
          if (lyrics != null && lyrics.isNotEmpty) {
            if (mounted) {
              setState(() {
                _lyrics = _cleanLyrics(lyrics);
                _loading = false;
              });
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('LRCLIB get (no duration) error: $e');
      }

      // 3. Try LRCLIB /api/search (fuzzy query with cleaned title + cleaned artist)
      try {
        final searchUri = Uri.parse('https://lrclib.net/api/search').replace(queryParameters: {
          'q': '$title $artist',
        });
        final response = await http.get(searchUri, headers: {
          'User-Agent': 'RetroBeats/1.0.0 (https://github.com/asmitsaw/Beat-GO-)'
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            final bestMatch = data.first as Map<String, dynamic>;
            final lyrics = (bestMatch['syncedLyrics'] as String?)?.isNotEmpty == true
                ? bestMatch['syncedLyrics'] as String
                : bestMatch['plainLyrics'] as String?;
            if (lyrics != null && lyrics.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _lyrics = _cleanLyrics(lyrics);
                  _loading = false;
                });
                return;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('LRCLIB search error: $e');
      }

      // 4. Try LRCLIB /api/search with rawTitle + rawArtist
      try {
        final searchUri = Uri.parse('https://lrclib.net/api/search').replace(queryParameters: {
          'q': '$rawTitle $rawArtist',
        });
        final response = await http.get(searchUri, headers: {
          'User-Agent': 'RetroBeats/1.0.0 (https://github.com/asmitsaw/Beat-GO-)'
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            final bestMatch = data.first as Map<String, dynamic>;
            final lyrics = (bestMatch['syncedLyrics'] as String?)?.isNotEmpty == true
                ? bestMatch['syncedLyrics'] as String
                : bestMatch['plainLyrics'] as String?;
            if (lyrics != null && lyrics.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _lyrics = _cleanLyrics(lyrics);
                  _loading = false;
                });
                return;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('LRCLIB raw search error: $e');
      }

      // 5. Fallback to lyrics.ovh with cleaned title & artist
      try {
        final encodedArtist = Uri.encodeComponent(artist);
        final encodedTitle  = Uri.encodeComponent(title);
        final url = Uri.parse('https://api.lyrics.ovh/v1/$encodedArtist/$encodedTitle');
        final res = await _doFetch(url);
        if (mounted) {
          setState(() {
            _lyrics = _cleanLyrics(res);
            _loading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('lyrics.ovh cleaned error: $e');
      }

      // 6. Fallback to lyrics.ovh with raw title & artist
      final encodedArtist = Uri.encodeComponent(rawArtist);
      final encodedTitle  = Uri.encodeComponent(rawTitle);
      final url = Uri.parse('https://api.lyrics.ovh/v1/$encodedArtist/$encodedTitle');
      final res = await _doFetch(url);
      if (mounted) {
        setState(() {
          _lyrics = _cleanLyrics(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('All lyrics fetches failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Lyrics not found';
          _loading = false;
        });
      }
    }
  }

  Future<String> _doFetch(Uri url) async {
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('lyrics')) {
      return json['lyrics'] as String;
    }
    throw Exception('No lyrics key');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top:   BorderSide(color: AppColors.border, width: 3),
              left:  BorderSide(color: AppColors.border, width: 3),
              right: BorderSide(color: AppColors.border, width: 3),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black, offset: Offset(0, -4), blurRadius: 0),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 48, height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎤', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.song.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.song.artist,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 2),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.pink),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🎵', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Try searching for lyrics on Google',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            children: [
                              Text(
                                _lyrics ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
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

class _QueueSheet extends ConsumerWidget {
  final String? currentSongId;

  const _QueueSheet({required this.currentSongId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);

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
                    : ReorderableListView.builder(
                        scrollController: scrollCtrl,
                        itemCount: queue.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onReorder: (oldIdx, newIdx) {
                          ref.read(musicServiceProvider).reorderQueue(oldIdx, newIdx, ref);
                        },
                        itemBuilder: (_, i) {
                          final song = queue[i];
                          final isCurrent = song.id == currentSongId;
                          return Container(
                            key: ValueKey(song.id),
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
                                      color: AppColors.textPrimary, size: 22)
                                else
                                  const Icon(Icons.drag_handle_rounded,
                                      color: AppColors.textSecondary, size: 22),
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
