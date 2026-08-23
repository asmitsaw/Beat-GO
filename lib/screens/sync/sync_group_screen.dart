import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/neo_box.dart';
import '../../components/neo_text_field.dart';
import '../../models/song_model.dart';
import '../../models/sync_group_model.dart';
import '../../providers/sync_group_provider.dart';
import '../../services/music_service.dart';
import '../../theme/app_colors.dart';
import '../search/search_screen.dart';

class SyncGroupSheet extends ConsumerStatefulWidget {
  const SyncGroupSheet({super.key});

  @override
  ConsumerState<SyncGroupSheet> createState() => _SyncGroupSheetState();
}

class _SyncGroupSheetState extends ConsumerState<SyncGroupSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final service = ref.read(syncGroupServiceProvider);
      final group = await service.createGroup(ref);

      if (group != null && mounted) {
        ref.read(activeSyncGroupProvider.notifier).setGroup(group);
      } else if (mounted) {
        setState(() => _errorMsg = 'Failed to create group. Please try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleJoinGroup() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _errorMsg = 'Please enter a valid 6-character code.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final service = ref.read(syncGroupServiceProvider);
      final group = await service.joinGroup(code, ref);

      if (group != null && mounted) {
        ref.read(activeSyncGroupProvider.notifier).setGroup(group);
      } else if (mounted) {
        setState(() => _errorMsg = 'Group not found or expired.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Failed to join group.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLeaveGroup() async {
    final service = ref.read(syncGroupServiceProvider);
    await service.leaveGroup(ref: ref);
    ref.read(activeSyncGroupProvider.notifier).setGroup(null);
    if (mounted) Navigator.pop(context);
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $code copied to clipboard!'),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareCode(String code) {
    SharePlus.instance.share(
      ShareParams(
        text: '🎵 Join my Retro Beats Music Party! Code: $code\nListen together in perfect sync!',
        subject: 'Join my Music Sync Group',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeSyncGroupProvider);
    final isHost = ref.watch(isSyncHostProvider);
    final members = ref.watch(syncGroupMembersProvider);
    final groupQueue = ref.watch(syncGroupQueueProvider);
    final currentSong = ref.watch(currentSongProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppColors.border, width: 4),
              left: BorderSide(color: AppColors.border, width: 4),
              right: BorderSide(color: AppColors.border, width: 4),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black, offset: Offset(0, -6), blurRadius: 0),
            ],
          ),
          child: Column(
            children: [
              // Handle Bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(LucideIcons.radio, color: AppColors.pink, size: 26),
                        SizedBox(width: 10),
                        Text(
                          'MUSIC SYNC PARTY',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 3, color: AppColors.border),

              // Content Switcher
              Expanded(
                child: activeGroup == null
                    ? _buildSetupView()
                    : _buildActiveGroupView(
                        activeGroup, isHost, members, groupQueue, currentSong, scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SETUP VIEW: Create or Join Group
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Tab Switcher
          Container(
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: Colors.black,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 2),
              ),
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              tabs: const [
                Tab(text: 'CREATE GROUP'),
                Tab(text: 'JOIN WITH CODE'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.pink, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.pink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── CREATE TAB ──────────────────────────────────────────────
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Icon(LucideIcons.users, size: 64, color: AppColors.purple),
                      const SizedBox(height: 16),
                      const Text(
                        'Host a Music Party 🚀',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a group, share your 6-digit party code with friends, and sync playback across all phone speakers simultaneously!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 32),
                      NeoBox(
                        color: AppColors.yellow,
                        borderRadius: 14,
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          onTap: _loading ? null : _handleCreateGroup,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            alignment: Alignment.center,
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.black)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(LucideIcons.sparkles, color: Colors.black),
                                      SizedBox(width: 10),
                                      Text(
                                        'CREATE GROUP CODE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: Colors.black,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── JOIN TAB ────────────────────────────────────────────────
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      const Icon(LucideIcons.headphones, size: 56, color: AppColors.cyan),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter 6-Digit Party Code',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ask the host for the party code to join their synchronized session.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      NeoTextField(
                        controller: _codeCtrl,
                        hintText: 'e.g. BEAT89',
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      NeoBox(
                        color: AppColors.cyan,
                        borderRadius: 14,
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          onTap: _loading ? null : _handleJoinGroup,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            alignment: Alignment.center,
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.black)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(LucideIcons.logIn, color: Colors.black),
                                      SizedBox(width: 10),
                                      Text(
                                        'JOIN PARTY NOW',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: Colors.black,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ACTIVE GROUP VIEW: Host & Listener Controls, Members, Shared Queue
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildActiveGroupView(
    SyncGroup group,
    bool isHost,
    List<SyncMember> members,
    List<SyncQueueItem> queue,
    SongModel? currentSong,
    ScrollController scrollCtrl,
  ) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(20),
      children: [
        // ── CODE DISPLAY BANNER ──────────────────────────────────────────────
        NeoBox(
          color: isHost ? AppColors.yellow : AppColors.cyan,
          borderRadius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isHost ? '👑 PARTY HOST' : '🎧 LISTENER',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    '${members.length} Connected',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'GROUP PARTY CODE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                group.code,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black, width: 2),
                        elevation: 0,
                      ),
                      onPressed: () => _copyCode(group.code),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('COPY', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: () => _shareCode(group.code),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('SHARE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── NOW PLAYING CARD ────────────────────────────────────────────────
        NeoBox(
          color: AppColors.purple,
          borderRadius: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: currentSong != null
                      ? CachedNetworkImage(
                          imageUrl: currentSong.coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                        )
                      : Container(
                          color: Colors.black26,
                          child: const Icon(Icons.music_note, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOW SYNCING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentSong?.title ?? 'No track selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentSong?.artist ?? (isHost ? 'Pick a song to play!' : 'Waiting for host...'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isHost) ...[
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                  onPressed: () => ref.read(musicServiceProvider).seekToNext(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── CONNECTED MEMBERS ───────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONNECTED MEMBERS (${members.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: members.isEmpty
              ? const Center(
                  child: Text('Connecting listeners...',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final m = members[i];
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: m.isHost ? AppColors.yellow : AppColors.cyan,
                                child: Text(
                                  m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              if (m.isHost)
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 7,
                                    backgroundColor: Colors.black,
                                    child: Icon(Icons.star, size: 9, color: AppColors.yellow),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.displayName,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 20),

        // ── SHARED GROUP QUEUE ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SHARED GROUP QUEUE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                side: const BorderSide(color: Colors.black, width: 2),
                elevation: 0,
              ),
              onPressed: () {
                // Open search to pick & add song to group queue
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ADD SONG', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (queue.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Column(
              children: const [
                Icon(LucideIcons.listPlus, size: 36, color: AppColors.textSecondary),
                SizedBox(height: 8),
                Text(
                  'Shared Queue is Empty',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Anyone in the group can search and add songs!',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: queue.length,
            itemBuilder: (_, i) {
              final item = queue[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: item.song.coverUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.song.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                item.song.artist,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'By ${item.addedByName}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: AppColors.pink),
                      onPressed: () async {
                        await ref.read(musicServiceProvider).playQueue([item.song], 0, ref);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 28),

        // ── LEAVE / END GROUP BUTTON ────────────────────────────────────────
        NeoBox(
          color: AppColors.pink,
          borderRadius: 14,
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: _handleLeaveGroup,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.logOut, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isHost ? 'END PARTY & LEAVE' : 'LEAVE PARTY GROUP',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}
