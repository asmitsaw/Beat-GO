import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final downloadServiceProvider =
    Provider<DownloadService>((ref) => DownloadService());

/// Tracks which song IDs are currently downloading (for progress UI).
class DownloadingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void add(String id)    => state = {...state, id};
  void remove(String id) => state = state.difference({id});
}
final downloadingProvider =
    NotifierProvider<DownloadingNotifier, Set<String>>(DownloadingNotifier.new);

/// Set of all downloaded song IDs.
class DownloadedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kDownloadedKey) ?? [];
    state = ids.toSet();
  }

  Future<void> add(String id) async {
    state = {...state, id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDownloadedKey, state.toList());
  }

  Future<void> remove(String id) async {
    state = state.difference({id});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDownloadedKey, state.toList());
  }

  static const _kDownloadedKey = 'downloaded_songs';
}
final downloadedProvider =
    NotifierProvider<DownloadedNotifier, Set<String>>(DownloadedNotifier.new);

// ── Service ────────────────────────────────────────────────────────────────

class DownloadService {
  static const _kPathsKey = 'download_paths';

  Future<Directory> get _songsDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/retro_beats_songs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _filePath(String songId) async {
    final dir = await _songsDir;
    return '${dir.path}/$songId.mp3';
  }

  Future<Map<String, String>> _loadPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kPathsKey) ?? '{}';
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<void> _savePaths(Map<String, String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPathsKey, jsonEncode(paths));
  }

  /// Returns the local file path if the song is downloaded, else null.
  Future<String?> getLocalPath(String songId) async {
    final path = await _filePath(songId);
    if (await File(path).exists()) return path;
    return null;
  }

  Future<bool> isDownloaded(String songId) async =>
      (await getLocalPath(songId)) != null;

  /// Downloads the song audio to local storage.
  Future<void> downloadSong(SongModel song, WidgetRef ref) async {
    if (await isDownloaded(song.id)) return;

    ref.read(downloadingProvider.notifier).add(song.id);
    try {
      final path     = await _filePath(song.id);
      final response = await http.get(Uri.parse(song.audioUrl));
      if (response.statusCode == 200) {
        await File(path).writeAsBytes(response.bodyBytes);
        final paths   = await _loadPaths();
        paths[song.id] = path;
        await _savePaths(paths);
        ref.read(downloadedProvider.notifier).add(song.id);
      }
    } catch (e) {
      debugPrint('Download failed for ${song.id}: $e');
    } finally {
      ref.read(downloadingProvider.notifier).remove(song.id);
    }
  }

  /// Deletes the downloaded file.
  Future<void> deleteSong(String songId, WidgetRef ref) async {
    final path = await _filePath(songId);
    final file = File(path);
    if (await file.exists()) await file.delete();
    final paths = await _loadPaths();
    paths.remove(songId);
    await _savePaths(paths);
    ref.read(downloadedProvider.notifier).remove(songId);
  }

  /// Total bytes used by cached songs.
  Future<int> getCacheSizeBytes() async {
    final dir = await _songsDir;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearAll(WidgetRef ref) async {
    final dir = await _songsDir;
    if (await dir.exists()) await dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPathsKey);
    await prefs.remove(DownloadedNotifier._kDownloadedKey);
    state_reset(ref);
  }

  void state_reset(WidgetRef ref) {
    ref.invalidate(downloadedProvider);
    ref.invalidate(downloadingProvider);
  }
}
