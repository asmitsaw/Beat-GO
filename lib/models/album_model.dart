import 'song_model.dart';

/// Represents a JioSaavn album, including its full track listing.
class AlbumModel {
  final String id;
  final String name;
  final String description;
  final String language;
  final String imageUrl;
  final int? year;
  final int? playCount;
  final List<String> primaryArtists;
  final List<SongModel> songs;

  const AlbumModel({
    required this.id,
    required this.name,
    this.description = '',
    this.language = '',
    required this.imageUrl,
    this.year,
    this.playCount,
    this.primaryArtists = const [],
    this.songs = const [],
  });

  /// Build from a JioSaavn API album response map, with pre-converted songs.
  factory AlbumModel.fromJson(Map<String, dynamic> json, List<SongModel> songs) {
    // Image: pick highest quality available
    final imageList = (json['image'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final imageUrl = imageList.isNotEmpty
        ? (imageList.last['url'] as String? ?? '')
        : '';

    // Primary artists
    final artistsObj = json['artists'] as Map<String, dynamic>?;
    final primaryList = (artistsObj?['primary'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final primaryArtists = primaryList
        .map((a) => (a['name'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    return AlbumModel(
      id:             json['id']?.toString() ?? '',
      name:           json['name']?.toString() ?? 'Unknown Album',
      description:    json['description']?.toString() ?? '',
      language:       json['language']?.toString() ?? '',
      imageUrl:       imageUrl,
      year:           json['year'] as int?,
      playCount:      json['playCount'] as int?,
      primaryArtists: primaryArtists,
      songs:          songs,
    );
  }
}
