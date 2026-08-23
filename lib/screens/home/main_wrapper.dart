import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../services/music_service.dart';
import '../../widgets/sync_status_badge.dart';
import '../../widgets/mini_player.dart';
import '../../providers/recommendations_provider.dart';
import '../../providers/sync_group_provider.dart';
import '../../screens/onboarding/music_preferences_screen.dart';
import 'home_screen.dart';
import '../library/library_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../recommendations/recommendations_screen.dart';

class MainWrapper extends ConsumerStatefulWidget {
  const MainWrapper({super.key});

  @override
  ConsumerState<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends ConsumerState<MainWrapper> {
  int _currentIndex = 0;
  bool _onboardingChecked = false;

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    RecommendationsScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Check onboarding after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;

    final done = await ref.read(onboardingDoneProvider.future);
    if (!done && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MusicPreferencesScreen(),
          fullscreenDialog: true,
        ),
      );
      // Refresh recommendations after onboarding
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(forYouRecommendationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autoplayProvider);
    ref.watch(activeSongChangedProvider);
    final currentSong = ref.watch(currentSongProvider);
    final activeGroup = ref.watch(activeSyncGroupProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],

          // Sync status badge pill at top right floating position if active
          if (activeGroup != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: const SyncStatusBadge(),
            ),

          // Mini player floats above bottom nav
          if (currentSong != null)
            Positioned(
              left: 12, right: 12,
              bottom: 80, // above the nav bar height
              child: const MiniPlayer(),
            ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white24 : AppColors.border,
              width: 3,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.home), label: 'Discover'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.search), label: 'Search'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.sparkles), label: 'For You'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.library), label: 'Library'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
