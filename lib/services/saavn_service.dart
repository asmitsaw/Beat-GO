import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';
import '../models/album_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
// JioSaavn API Service
//
// Base URL: https://jiosaavn-api.asmit01052005.workers.dev
// All endpoints return { success: bool, data: ... }
// ══════════════════════════════════════════════════════════════════════════════

const _kBaseUrl = 'https://jiosaavn-api.asmit01052005.workers.dev';

/// Quality preference order — first match wins.
const _kQualityOrder = ['320kbps', '160kbps', '96kbps', '12kbps'];

/// Terms used to simulate a "Trending" feed (JioSaavn has no dedicated endpoint).
const _kTrendingTerms = [
  'arijit singh',
  'bollywood hits 2024',
  'top english 2024',
  'ap dhillon',
  'diljit dosanjh',
];

class SaavnService {
  final http.Client _client;

  SaavnService({http.Client? client}) : _client = client ?? http.Client();

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, String>? params]) =>
      Uri.parse('$_kBaseUrl$path').replace(queryParameters: params);

  Future<dynamic> _get(String path, [Map<String, String>? params]) async {
    final uri = _uri(path, params);
    debugPrint('[SaavnService] GET $uri');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} for $uri');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception('API returned success=false for $uri');
    }
    return body['data'];
  }

  /// Converts a raw JioSaavn song map into a [SongModel].
  static SongModel songFromJson(Map<String, dynamic> s) {
    // ── Download URL (audio stream) ──────────────────────────────────────
    final dlList =
        (s['downloadUrl'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    String audioUrl = '';
    for (final quality in _kQualityOrder) {
      final match = dlList.firstWhere(
        (d) => d['quality'] == quality,
        orElse: () => {},
      );
      if ((match['url'] as String?)?.isNotEmpty == true) {
        audioUrl = match['url'] as String;
        break;
      }
    }
    if (audioUrl.isEmpty && dlList.isNotEmpty) {
      audioUrl = (dlList.last['url'] as String?) ?? '';
    }

    // ── Cover image ──────────────────────────────────────────────────────
    final imgList =
        (s['image'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    String coverUrl = '';
    if (imgList.isNotEmpty) {
      // Prefer 500x500, else take last (usually highest res)
      final match = imgList.firstWhere(
        (i) => (i['quality'] as String?) == '500x500',
        orElse: () => imgList.last,
      );
      coverUrl = (match['url'] as String?) ?? '';
    }

    // ── Primary artist ───────────────────────────────────────────────────
    final artistsObj = s['artists'] as Map<String, dynamic>?;
    final primaryList =
        (artistsObj?['primary'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final artist = primaryList.isNotEmpty
        ? primaryList.map((a) => a['name'] as String? ?? '').join(', ')
        : (s['primaryArtists'] as String?) ?? 'Unknown Artist';

    // ── Album name ───────────────────────────────────────────────────────
    final albumObj = s['album'] as Map<String, dynamic>?;
    final albumName = (albumObj?['name'] as String?) ?? '';

    // ── Duration ─────────────────────────────────────────────────────────
    final durationSec = (s['duration'] as num?)?.toInt() ?? 0;

    return SongModel(
      id:         s['id']?.toString() ?? '',
      title:      (s['name'] as String?) ?? 'Unknown Title',
      artist:     artist,
      album:      albumName,
      genre:      _capitalise((s['language'] as String?) ?? ''),
      mood:       '',
      coverUrl:   coverUrl,
      audioUrl:   audioUrl,
      durationMs: durationSec * 1000,
      playCount:  (s['playCount'] as num?)?.toInt() ?? 0,
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Search for songs matching [query]. Supports pagination.
  Future<List<SongModel>> searchSongs(
    String query, {
    int page = 0,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/api/search/songs', {
      'query': query,
      'page':  page.toString(),
      'limit': limit.toString(),
    }) as Map<String, dynamic>;
    final results = (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return results.map(songFromJson).where((s) => s.audioUrl.isNotEmpty).toList();
  }

  /// Search for albums matching [query].
  Future<List<Map<String, dynamic>>> searchAlbums(
    String query, {
    int page = 0,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/api/search/albums', {
      'query': query,
      'page':  page.toString(),
      'limit': limit.toString(),
    }) as Map<String, dynamic>;
    return (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Search for artists matching [query].
  Future<List<Map<String, dynamic>>> searchArtists(
    String query, {
    int page = 0,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/api/search/artists', {
      'query': query,
      'page':  page.toString(),
      'limit': limit.toString(),
    }) as Map<String, dynamic>;
    return (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Fetch song suggestions (similar songs) for [songId].
  Future<List<SongModel>> getSongSuggestions(
    String songId, {
    int limit = 10,
  }) async {
    final data = await _get(
      '/api/songs/$songId/suggestions',
      {'limit': limit.toString()},
    ) as List;
    return data
        .cast<Map<String, dynamic>>()
        .map(songFromJson)
        .where((s) => s.audioUrl.isNotEmpty)
        .toList();
  }

  /// Fetch a full album (with track listing) by [albumId].
  Future<AlbumModel> getAlbum(String albumId) async {
    final data = await _get('/api/albums', {'id': albumId}) as Map<String, dynamic>;
    final rawSongs =
        (data['songs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final songs = rawSongs.map(songFromJson)
        .where((s) => s.audioUrl.isNotEmpty)
        .toList();
    return AlbumModel.fromJson(data, songs);
  }

  /// Simulate a trending feed by searching popular terms, deduplicating,
  /// and sorting by playCount descending.
  Future<List<SongModel>> getTrendingSongs({int limit = 20}) async {
    final futures = _kTrendingTerms
        .map((term) => searchSongs(term, limit: 10).catchError((_) => <SongModel>[]));
    final results = await Future.wait(futures);

    final seen = <String>{};
    final combined = <SongModel>[];
    for (final batch in results) {
      for (final song in batch) {
        if (seen.add(song.id) && song.audioUrl.isNotEmpty) {
          combined.add(song);
        }
      }
    }
    combined.sort((a, b) => b.playCount.compareTo(a.playCount));
    return combined.take(limit).toList();
  }

  /// Fetch top new releases by searching recent terms.
  Future<List<SongModel>> getNewReleases({int limit = 15}) async {
    final results = await searchSongs('new songs 2025', limit: limit);
    return results;
  }
}
