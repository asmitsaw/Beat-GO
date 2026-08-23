import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/song_model.dart';
import '../models/sync_group_model.dart';
import '../services/sync_group_service.dart';

final syncGroupServiceProvider = Provider<SyncGroupService>((ref) {
  final service = SyncGroupService();
  ref.onDispose(() {
    service.leaveGroup(ref: ref, notify: false);
  });
  return service;
});

// ── Active Group State ───────────────────────────────────────────────────────
class ActiveSyncGroupNotifier extends Notifier<SyncGroup?> {
  @override
  SyncGroup? build() => null;

  void setGroup(SyncGroup? group) => state = group;
}

final activeSyncGroupProvider =
    NotifierProvider<ActiveSyncGroupNotifier, SyncGroup?>(
  ActiveSyncGroupNotifier.new,
);

// ── Members State ────────────────────────────────────────────────────────────
class SyncMembersNotifier extends Notifier<List<SyncMember>> {
  @override
  List<SyncMember> build() => [];

  void setMembers(List<SyncMember> members) => state = members;
}

final syncGroupMembersProvider =
    NotifierProvider<SyncMembersNotifier, List<SyncMember>>(
  SyncMembersNotifier.new,
);

// ── Shared Queue State ───────────────────────────────────────────────────────
class SyncGroupQueueNotifier extends Notifier<List<SyncQueueItem>> {
  @override
  List<SyncQueueItem> build() => [];

  void setQueue(List<SyncQueueItem> queue) => state = queue;
}

final syncGroupQueueProvider =
    NotifierProvider<SyncGroupQueueNotifier, List<SyncQueueItem>>(
  SyncGroupQueueNotifier.new,
);

// ── Derived Host Status ──────────────────────────────────────────────────────
final isSyncHostProvider = Provider<bool>((ref) {
  final group = ref.watch(activeSyncGroupProvider);
  if (group == null) return false;
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId != null && currentUserId == group.hostId) return true;
  return ref.watch(syncGroupServiceProvider).isHost;
});

// ── Controller / Actions Helper ──────────────────────────────────────────────
final syncGroupControllerProvider = Provider((ref) {
  return SyncGroupController(ref);
});

class SyncGroupController {
  final Ref _ref;

  SyncGroupController(this._ref) {
    final service = _ref.read(syncGroupServiceProvider);
    service.onGroupUpdated = (group) {
      _ref.read(activeSyncGroupProvider.notifier).setGroup(group);
    };
    service.onMembersUpdated = (members) {
      _ref.read(syncGroupMembersProvider.notifier).setMembers(members);
    };
    service.onQueueUpdated = (queue) {
      _ref.read(syncGroupQueueProvider.notifier).setQueue(queue);
    };
  }

  Future<SyncGroup?> createGroup() async {
    final service = _ref.read(syncGroupServiceProvider);
    final group = await service.createGroup(_ref as WidgetRef);
    if (group != null) {
      _ref.read(activeSyncGroupProvider.notifier).setGroup(group);
    }
    return group;
  }

  Future<SyncGroup?> joinGroup(String code) async {
    final service = _ref.read(syncGroupServiceProvider);
    final group = await service.joinGroup(code, _ref as WidgetRef);
    if (group != null) {
      _ref.read(activeSyncGroupProvider.notifier).setGroup(group);
    }
    return group;
  }

  Future<void> leaveGroup() async {
    final service = _ref.read(syncGroupServiceProvider);
    await service.leaveGroup(ref: _ref as WidgetRef);
    _ref.read(activeSyncGroupProvider.notifier).setGroup(null);
    _ref.read(syncGroupMembersProvider.notifier).setMembers([]);
    _ref.read(syncGroupQueueProvider.notifier).setQueue([]);
  }

  Future<void> addToQueue(SongModel song) async {
    final service = _ref.read(syncGroupServiceProvider);
    await service.addToGroupQueue(song, _ref as WidgetRef);
  }

  Future<void> removeFromQueue(String itemId) async {
    final service = _ref.read(syncGroupServiceProvider);
    await service.removeFromGroupQueue(itemId);
  }
}
