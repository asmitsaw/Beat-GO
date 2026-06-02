class PlaylistModel {
  final String id;
  final String ownerId;
  final String title;
  final String? coverUrl;
  final bool isPublic;
  final int songCount;

  const PlaylistModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.coverUrl,
    this.isPublic = false,
    this.songCount = 0,
  });

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id:        map['id']?.toString() ?? '',
      ownerId:   map['owner_id']?.toString() ?? '',
      title:     map['title'] ?? 'Untitled Playlist',
      coverUrl:  map['cover_url'],
      isPublic:  map['is_public'] ?? false,
      songCount: map['song_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'owner_id':  ownerId,
        'title':     title,
        'cover_url': coverUrl,
        'is_public': isPublic,
      };
}
