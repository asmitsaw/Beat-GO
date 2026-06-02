import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_client.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase ──
  await Supabase.initialize(
    url:     supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // ── Background audio (lock-screen controls) ──
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId:   'com.retrobeats.channel.audio',
      androidNotificationChannelName: 'Retro Beats',
      androidNotificationOngoing:     true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground init skipped: $e');
  }

  runApp(const ProviderScope(child: RetroBeatsApp()));
}

class RetroBeatsApp extends ConsumerWidget {
  const RetroBeatsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final settings  = ref.watch(settingsProvider);
    final themeMode = settings.value?.themeMode ?? ThemeMode.light;

    return MaterialApp(
      title:     'Retro Beats',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: authState.when(
        data: (User? user) =>
            user != null ? const MainWrapper() : const LoginScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('Auth error: $e')),
        ),
      ),
    );
  }
}
