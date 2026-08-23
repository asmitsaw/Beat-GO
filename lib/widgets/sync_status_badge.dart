import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/sync_group_provider.dart';
import '../screens/sync/sync_group_screen.dart';
import '../theme/app_colors.dart';

class SyncStatusBadge extends ConsumerWidget {
  final bool compact;

  const SyncStatusBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(activeSyncGroupProvider);
    final isHost = ref.watch(isSyncHostProvider);
    final members = ref.watch(syncGroupMembersProvider);

    if (group == null) return const SizedBox.shrink();

    final listenerCount = members.isNotEmpty ? members.length : 1;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const SyncGroupSheet(),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isHost ? AppColors.yellow : AppColors.cyan,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingRadioIcon(),
            const SizedBox(width: 6),
            Text(
              '${group.code} • ${isHost ? 'HOST' : 'SYNCED'}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: compact ? 11 : 12,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.users, size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      '$listenerCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PulsingRadioIcon extends StatefulWidget {
  const _PulsingRadioIcon();

  @override
  State<_PulsingRadioIcon> createState() => _PulsingRadioIconState();
}

class _PulsingRadioIconState extends State<_PulsingRadioIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const Icon(
        LucideIcons.radio,
        size: 14,
        color: Colors.black,
      ),
    );
  }
}
