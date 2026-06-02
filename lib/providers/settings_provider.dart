import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Settings model ─────────────────────────────────────────────────────────
class AppSettings {
  final ThemeMode themeMode;
  final String audioQuality; // 'standard' | 'high'

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.audioQuality = 'standard',
  });

  AppSettings copyWith({ThemeMode? themeMode, String? audioQuality}) {
    return AppSettings(
      themeMode:    themeMode    ?? this.themeMode,
      audioQuality: audioQuality ?? this.audioQuality,
    );
  }
}

// ── Notifier ────────────────────────────────────────────────────────────────
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _kTheme   = 'theme_mode';
  static const _kQuality = 'audio_quality';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_kTheme) ?? 'light';
    final quality  = prefs.getString(_kQuality) ?? 'standard';
    return AppSettings(
      themeMode:    themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light,
      audioQuality: quality,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode == ThemeMode.dark ? 'dark' : 'light');
    final current = state.value ?? const AppSettings();
    state = AsyncData(current.copyWith(themeMode: mode));
  }

  Future<void> setAudioQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQuality, quality);
    final current = state.value ?? const AppSettings();
    state = AsyncData(current.copyWith(audioQuality: quality));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
