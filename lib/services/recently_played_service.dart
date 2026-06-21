import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Recently Played Service
// Persists the last 50 played songs in SharedPreferences
// ══════════════════════════════════════════════════════════════════════════════

const _kRecentKey   = 'recently_played';
const _kSearchKey   = 'search_history';
const _kMaxRecent   = 50;
const _kMaxSearches = 20;

class RecentlyPlayedService {
  // ── Recently Played Songs ─────────────────────────────────────────────────

  Future<List<SongModel>> getRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_kRecentKey) ?? [];
    return raw
        .map((s) => SongModel.fromMap(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addSong(SongModel song) async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kRecentKey) ?? [];

    // Remove duplicates
    current.removeWhere((s) {
      try {
        return (jsonDecode(s) as Map<String, dynamic>)['id'] == song.id;
      } catch (_) {
        return false;
      }
    });

    // Add to front
    current.insert(0, jsonEncode(song.toMap()));

    // Trim
    if (current.length > _kMaxRecent) {
      current.removeRange(_kMaxRecent, current.length);
    }

    await prefs.setStringList(_kRecentKey, current);
  }

  Future<void> clearRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentKey);
  }

  // ── Search History ────────────────────────────────────────────────────────

  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kSearchKey) ?? [];
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kSearchKey) ?? [];

    current.remove(query); // remove duplicate
    current.insert(0, query);

    if (current.length > _kMaxSearches) {
      current.removeRange(_kMaxSearches, current.length);
    }

    await prefs.setStringList(_kSearchKey, current);
  }

  Future<void> removeSearch(String query) async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kSearchKey) ?? [];
    current.remove(query);
    await prefs.setStringList(_kSearchKey, current);
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSearchKey);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final recentlyPlayedServiceProvider =
    Provider<RecentlyPlayedService>((_) => RecentlyPlayedService());

final recentlyPlayedProvider = FutureProvider<List<SongModel>>((ref) async {
  return ref.read(recentlyPlayedServiceProvider).getRecentlyPlayed();
});

final searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(recentlyPlayedServiceProvider).getSearchHistory();
});
