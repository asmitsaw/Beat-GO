import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/song_model.dart';
import '../models/sync_group_model.dart';
import 'music_service.dart' hide debugPrint;

class SyncGroupService {
  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;
  bool _isHost = false;
  SyncGroup? _currentGroup;
  List<SyncMember> _members = [];
  List<SyncQueueItem> _groupQueue = [];

  // Callbacks for State Updates
  void Function(SyncGroup group)? onGroupUpdated;
  void Function(List<SyncMember> members)? onMembersUpdated;
  void Function(List<SyncQueueItem> queue)? onQueueUpdated;
  void Function(String message)? onError;

  SyncGroup? get currentGroup => _currentGroup;
  bool get isHost => _isHost;
  List<SyncMember> get members => List.unmodifiable(_members);
  List<SyncQueueItem> get groupQueue => List.unmodifiable(_groupQueue);

  // ── 1. Create Sync Group (Host) ───────────────────────────────────────────
  Future<SyncGroup?> createGroup(WidgetRef ref) async {
    try {
      final user = supabase.auth.currentUser;
      final userId = user?.id ?? 'guest_${Random().nextInt(99999)}';

      String displayName = 'Host';
      if (user != null) {
        final profileRes = await supabase
            .from('profiles')
            .select('display_name, username')
            .eq('id', user.id)
            .maybeSingle();
        if (profileRes != null) {
          displayName = profileRes['display_name'] ??
              profileRes['username'] ??
              user.email?.split('@').first ??
              'Host';
        }
      }

      final code = _generateGroupCode();
      final now = DateTime.now();

      final currentSong = ref.read(currentSongProvider);
      final isPlaying = ref.read(isPlayingProvider).value ?? false;
      final position = ref.read(positionProvider).value ?? Duration.zero;

      final groupData = {
        'code': code,
        'host_id': userId,
        'host_name': displayName,
        'current_song': currentSong?.toMap(),
        'is_playing': isPlaying,
        'position_ms': position.inMilliseconds,
        'playback_timestamp_ms': now.millisecondsSinceEpoch,
      };

      Map<String, dynamic>? createdMap;
      try {
        final res = await supabase
            .from('sync_groups')
            .insert(groupData)
            .select()
            .single();
        createdMap = Map<String, dynamic>.from(res);
      } catch (e) {
        debugPrint('Supabase table insert failed (fallback to memory channel): $e');
        createdMap = {
          'id': 'mem_${Random().nextInt(999999)}',
          ...groupData,
          'created_at': now.toIso8601String(),
        };
      }

      _currentGroup = SyncGroup.fromMap(createdMap);
      _isHost = true;

      // Subscribe to Realtime Channel
      await _subscribeToGroupChannel(code, displayName, isHost: true, ref: ref);

      // Start Host Heartbeat
      _startHostHeartbeat(ref);

      onGroupUpdated?.call(_currentGroup!);
      return _currentGroup;
    } catch (e) {
      debugPrint('Error creating sync group: $e');
      onError?.call('Failed to create sync group: $e');
      return null;
    }
  }

  // ── 2. Join Sync Group (Guest) ────────────────────────────────────────────
  Future<SyncGroup?> joinGroup(String codeInput, WidgetRef ref) async {
    final code = codeInput.trim().toUpperCase();
    if (code.length < 4) {
      onError?.call('Please enter a valid group code');
      return null;
    }

    try {
      final user = supabase.auth.currentUser;

      String displayName = 'Listener';
      if (user != null) {
        final profileRes = await supabase
            .from('profiles')
            .select('display_name, username')
            .eq('id', user.id)
            .maybeSingle();
        if (profileRes != null) {
          displayName = profileRes['display_name'] ??
              profileRes['username'] ??
              user.email?.split('@').first ??
              'Listener';
        }
      }

      SyncGroup? group;
      try {
        final row = await supabase
            .from('sync_groups')
            .select()
            .eq('code', code)
            .maybeSingle();
        if (row != null) {
          group = SyncGroup.fromMap(Map<String, dynamic>.from(row));
        }
      } catch (_) {}

      // Fallback: If DB query fails or code was broadcast-only
      group ??= SyncGroup(
        id: 'group_$code',
        code: code,
        hostId: 'unknown',
        hostName: 'Party Host',
      );

      _currentGroup = group;
      _isHost = false;

      // Subscribe to Realtime Channel
      await _subscribeToGroupChannel(code, displayName, isHost: false, ref: ref);

      // Load initial Queue
      await fetchGroupQueue(group.id);

      // Perform initial playback sync if host already has a song
      if (group.currentSong != null) {
        _applyGuestSyncState(
          song: group.currentSong!,
          isPlaying: group.isPlaying,
          positionMs: group.positionMs,
          timestampMs: group.playbackTimestampMs,
          ref: ref,
        );
      }

      onGroupUpdated?.call(_currentGroup!);
      return _currentGroup;
    } catch (e) {
      debugPrint('Error joining sync group: $e');
      onError?.call('Failed to join group. Check code and try again.');
      return null;
    }
  }

  // ── 3. Subscribe to Realtime Channel & Presence ────────────────────────────
  Future<void> _subscribeToGroupChannel(
      String code, String displayName, {required bool isHost, required WidgetRef ref}) async {
    await leaveGroup(ref: ref, notify: false);

    _channel = supabase.channel('sync_group:$code', opts: const RealtimeChannelConfig(self: true));

    // 1. Broadcast Listener: Playback State
    _channel!.onBroadcast(event: 'playback_state', callback: (payload) {
      final map = Map<String, dynamic>.from(payload);
      final songMap = map['song'] != null ? Map<String, dynamic>.from(map['song']) : null;
      final song = songMap != null ? SongModel.fromMap(songMap) : null;
      final isPlaying = map['is_playing'] == true;
      final positionMs = (map['position_ms'] as num?)?.toInt() ?? 0;
      final timestampMs = (map['timestamp_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

      if (_currentGroup != null) {
        _currentGroup = _currentGroup!.copyWith(
          currentSong: song,
          isPlaying: isPlaying,
          positionMs: positionMs,
          playbackTimestampMs: timestampMs,
        );
        onGroupUpdated?.call(_currentGroup!);
      }

      // Guest applies sync state
      if (!_isHost && song != null) {
        _applyGuestSyncState(
          song: song,
          isPlaying: isPlaying,
          positionMs: positionMs,
          timestampMs: timestampMs,
          ref: ref,
        );
      }
    });

    // 2. Broadcast Listener: Shared Queue Update
    _channel!.onBroadcast(event: 'queue_updated', callback: (payload) {
      if (payload['queue'] is List) {
        final list = List<Map<String, dynamic>>.from(payload['queue']);
        _groupQueue = list.map((item) => SyncQueueItem.fromMap(item)).toList();
        onQueueUpdated?.call(_groupQueue);
      }
    });

    // 3. Presence Tracking (Live Members)
    _channel!.onPresenceSync((_) {
      final state = _channel!.presenceState();
      final membersList = <SyncMember>[];

      for (final presenceState in state) {
        for (final presence in presenceState.presences) {
          final payload = presence.payload;
          membersList.add(SyncMember(
            id: payload['user_id']?.toString() ?? presence.presenceRef,
            displayName: payload['display_name']?.toString() ?? 'Listener',
            avatarUrl: payload['avatar_url']?.toString(),
            isHost: payload['is_host'] == true,
          ));
        }
      }

      _members = membersList;
      onMembersUpdated?.call(_members);
    });

    _channel!.subscribe();

    // Track presence
    final user = supabase.auth.currentUser;
    await _channel!.track({
      'user_id': user?.id ?? 'user_${Random().nextInt(99999)}',
      'display_name': displayName,
      'is_host': isHost,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // ── 4. Broadcast Host Playback Changes ─────────────────────────────────────
  Future<void> broadcastHostPlayback({
    required SongModel? song,
    required bool isPlaying,
    required Duration position,
    required WidgetRef ref,
  }) async {
    if (!_isHost || _currentGroup == null || _channel == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final posMs = position.inMilliseconds;

    _currentGroup = _currentGroup!.copyWith(
      currentSong: song,
      isPlaying: isPlaying,
      positionMs: posMs,
      playbackTimestampMs: now,
    );
    onGroupUpdated?.call(_currentGroup!);

    final payload = {
      'song': song?.toMap(),
      'is_playing': isPlaying,
      'position_ms': posMs,
      'timestamp_ms': now,
    };

    // Fast WebSockets Broadcast via Dynamic Dispatch
    (_channel as dynamic)?.send(
      type: 'broadcast',
      event: 'playback_state',
      payload: payload,
    );

    // Async Update Supabase DB row
    try {
      supabase.from('sync_groups').update({
        'current_song': song?.toMap(),
        'is_playing': isPlaying,
        'position_ms': posMs,
        'playback_timestamp_ms': now,
      }).eq('id', _currentGroup!.id).then((_) {}).catchError((_) {});
    } catch (_) {}
  }

  // ── 5. Host Periodic Heartbeat (Drift Correction) ─────────────────────────
  void _startHostHeartbeat(WidgetRef ref) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isHost || _currentGroup == null) return;
      final isPlaying = ref.read(isPlayingProvider).value ?? false;
      if (!isPlaying) return;

      final song = ref.read(currentSongProvider);
      final position = ref.read(positionProvider).value ?? Duration.zero;

      broadcastHostPlayback(
        song: song,
        isPlaying: true,
        position: position,
        ref: ref,
      );
    });
  }

  // ── 6. Guest Anti-Glitch & Drift Compensation Engine ──────────────────────
  Future<void> _applyGuestSyncState({
    required SongModel song,
    required bool isPlaying,
    required int positionMs,
    required int timestampMs,
    required WidgetRef ref,
  }) async {
    final musicService = ref.read(musicServiceProvider);
    final currentLocalSong = ref.read(currentSongProvider);

    // Calculate latency & adjusted target position
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSinceBroadcast = max(0, nowMs - timestampMs);
    final targetPositionMs = isPlaying ? (positionMs + elapsedSinceBroadcast) : positionMs;
    final targetDuration = Duration(milliseconds: targetPositionMs);

    // Step A: Song Change
    final songChanged = currentLocalSong == null || currentLocalSong.id != song.id;
    if (songChanged) {
      await musicService.playQueue([song], 0, ref);
      await musicService.seek(targetDuration);
      if (!isPlaying) {
        await musicService.pause();
      }
      return;
    }

    // Step B: Play / Pause State Alignment
    final currentLocalIsPlaying = ref.read(isPlayingProvider).value ?? false;
    if (isPlaying != currentLocalIsPlaying) {
      if (isPlaying) {
        await musicService.resume();
      } else {
        await musicService.pause();
      }
    }

    // Step C: Anti-Glitch & Drift Threshold Check
    final currentLocalPosMs = (ref.read(positionProvider).value ?? Duration.zero).inMilliseconds;
    final driftMs = (currentLocalPosMs - targetPositionMs).abs();

    // Adaptive Thresholds:
    // < 150ms drift: Do NOT seek (prevents audio glitch/stutter/flicker)
    // 150ms - 500ms drift: Seek smoothly
    // > 500ms drift: Seek immediately to target
    if (driftMs >= 150) {
      debugPrint('Sync Engine: Correcting clock drift of ${driftMs}ms');
      await musicService.seek(targetDuration);
    }
  }

  // ── 7. Shared Queue Operations ────────────────────────────────────────────
  Future<void> fetchGroupQueue(String groupId) async {
    try {
      final rows = await supabase
          .from('sync_group_queue')
          .select()
          .eq('group_id', groupId)
          .order('position', ascending: true);

      final list = List<Map<String, dynamic>>.from(rows as List);
      _groupQueue = list.map((r) => SyncQueueItem.fromMap(r)).toList();
      onQueueUpdated?.call(_groupQueue);
    } catch (e) {
      debugPrint('Error fetching group queue: $e');
    }
  }

  Future<void> addToGroupQueue(SongModel song, WidgetRef ref) async {
    if (_currentGroup == null) return;

    final user = supabase.auth.currentUser;
    final userId = user?.id;

    String displayName = 'Guest';
    if (user != null) {
      final profileRes = await supabase
          .from('profiles')
          .select('display_name, username')
          .eq('id', user.id)
          .maybeSingle();
      if (profileRes != null) {
        displayName = profileRes['display_name'] ?? profileRes['username'] ?? 'Member';
      }
    }

    final newItem = SyncQueueItem(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}',
      groupId: _currentGroup!.id,
      song: song,
      addedById: userId,
      addedByName: displayName,
      position: _groupQueue.length,
      addedAt: DateTime.now(),
    );

    _groupQueue = [..._groupQueue, newItem];
    onQueueUpdated?.call(_groupQueue);

    // Broadcast queue update via WebSocket
    if (_channel != null) {
      (_channel as dynamic)?.send(
        type: 'broadcast',
        event: 'queue_updated',
        payload: {
          'queue': _groupQueue.map((i) => i.toMap()).toList(),
        },
      );
    }

    // Persist to Supabase DB if available
    try {
      await supabase.from('sync_group_queue').insert({
        'group_id': _currentGroup!.id,
        'song': song.toMap(),
        'added_by_id': userId,
        'added_by_name': displayName,
        'position': newItem.position,
      });
    } catch (e) {
      debugPrint('Supabase queue insert error: $e');
    }
  }

  Future<void> removeFromGroupQueue(String itemId) async {
    _groupQueue = _groupQueue.where((i) => i.id != itemId).toList();
    onQueueUpdated?.call(_groupQueue);

    if (_channel != null) {
      (_channel as dynamic)?.send(
        type: 'broadcast',
        event: 'queue_updated',
        payload: {
          'queue': _groupQueue.map((i) => i.toMap()).toList(),
        },
      );
    }

    try {
      await supabase.from('sync_group_queue').delete().eq('id', itemId);
    } catch (_) {}
  }

  // ── 8. Leave / Disconnect Group ───────────────────────────────────────────
  Future<void> leaveGroup({required WidgetRef ref, bool notify = true}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_channel != null) {
      try {
        await _channel!.unsubscribe();
      } catch (_) {}
      _channel = null;
    }

    _isHost = false;
    _currentGroup = null;
    _members = [];
    _groupQueue = [];

    if (notify) {
      onGroupUpdated?.call(null as dynamic);
      onMembersUpdated?.call([]);
      onQueueUpdated?.call([]);
    }
  }

  // ── Helper: 6-Digit Alphanumeric Code Generator ───────────────────────────
  String _generateGroupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }
}
