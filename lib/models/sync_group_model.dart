import 'song_model.dart';

class SyncGroup {
  final String id;
  final String code;
  final String hostId;
  final String hostName;
  final SongModel? currentSong;
  final bool isPlaying;
  final int positionMs;
  final int playbackTimestampMs;
  final DateTime? createdAt;

  SyncGroup({
    required this.id,
    required this.code,
    required this.hostId,
    required this.hostName,
    this.currentSong,
    this.isPlaying = false,
    this.positionMs = 0,
    this.playbackTimestampMs = 0,
    this.createdAt,
  });

  factory SyncGroup.fromMap(Map<String, dynamic> map) {
    return SyncGroup(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      hostId: map['host_id']?.toString() ?? '',
      hostName: map['host_name']?.toString() ?? 'Host',
      currentSong: map['current_song'] != null && map['current_song'] is Map
          ? SongModel.fromMap(Map<String, dynamic>.from(map['current_song']))
          : null,
      isPlaying: map['is_playing'] == true,
      positionMs: map['position_ms'] is int ? map['position_ms'] : 0,
      playbackTimestampMs: map['playback_timestamp_ms'] is int
          ? map['playback_timestamp_ms']
          : (map['playback_timestamp_ms'] is num
              ? (map['playback_timestamp_ms'] as num).toInt()
              : 0),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'host_id': hostId,
      'host_name': hostName,
      'current_song': currentSong?.toMap(),
      'is_playing': isPlaying,
      'position_ms': positionMs,
      'playback_timestamp_ms': playbackTimestampMs,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  SyncGroup copyWith({
    String? id,
    String? code,
    String? hostId,
    String? hostName,
    SongModel? currentSong,
    bool? isPlaying,
    int? positionMs,
    int? playbackTimestampMs,
    DateTime? createdAt,
  }) {
    return SyncGroup(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      playbackTimestampMs: playbackTimestampMs ?? this.playbackTimestampMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SyncQueueItem {
  final String id;
  final String groupId;
  final SongModel song;
  final String? addedById;
  final String addedByName;
  final int position;
  final DateTime? addedAt;

  SyncQueueItem({
    required this.id,
    required this.groupId,
    required this.song,
    this.addedById,
    required this.addedByName,
    this.position = 0,
    this.addedAt,
  });

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      song: SongModel.fromMap(Map<String, dynamic>.from(map['song'] ?? {})),
      addedById: map['added_by_id']?.toString(),
      addedByName: map['added_by_name']?.toString() ?? 'Guest',
      position: map['position'] is int ? map['position'] : 0,
      addedAt: map['added_at'] != null
          ? DateTime.tryParse(map['added_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'song': song.toMap(),
      'added_by_id': addedById,
      'added_by_name': addedByName,
      'position': position,
      'added_at': addedAt?.toIso8601String(),
    };
  }
}

class SyncMember {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isHost;

  SyncMember({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isHost = false,
  });

  factory SyncMember.fromMap(Map<String, dynamic> map) {
    return SyncMember(
      id: map['id']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Listener',
      avatarUrl: map['avatar_url']?.toString(),
      isHost: map['is_host'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'is_host': isHost,
    };
  }
}
