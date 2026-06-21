import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../models/user_preferences_model.dart';
import '../../providers/recommendations_provider.dart';
import '../../data/popular_artists.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Music Preferences Onboarding — Spotify-style 3-step wizard
// ══════════════════════════════════════════════════════════════════════════════

class MusicPreferencesScreen extends ConsumerStatefulWidget {
  const MusicPreferencesScreen({super.key});

  @override
  ConsumerState<MusicPreferencesScreen> createState() =>
      _MusicPreferencesScreenState();
}

class _MusicPreferencesScreenState
    extends ConsumerState<MusicPreferencesScreen>
    with TickerProviderStateMixin {
  int _step = 0; // 0=languages, 1=artists, 2=moods

  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedArtists   = {};
  final Set<String> _selectedMoods     = {};

  bool _isSaving = false;

  late final AnimationController _progressController;
  late final AnimationController _fadeController;
  late Animation<double>         _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _progressController.animateTo(1 / 3);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _nextStep() async {
    if (_step == 0 && _selectedLanguages.isEmpty) {
      _snack('Pick at least one language 🎵');
      return;
    }
    if (_step == 1 && _selectedArtists.isEmpty) {
      _snack('Pick at least one artist 🎤');
      return;
    }
    if (_step == 2) {
      await _saveAndFinish();
      return;
    }

    await _fadeController.reverse();
    setState(() => _step++);
    _progressController.animateTo((_step + 1) / 3);
    await _fadeController.forward();
  }

  Future<void> _prevStep() async {
    if (_step == 0) return;
    await _fadeController.reverse();
    setState(() => _step--);
    _progressController.animateTo((_step + 1) / 3);
    await _fadeController.forward();
  }

  Future<void> _saveAndFinish() async {
    setState(() => _isSaving = true);
    final prefs = UserPreferences(
      languages:      _selectedLanguages.toList(),
      singers:        _selectedArtists.toList(),
      moods:          _selectedMoods.toList(),
      onboardingDone: true,
    );
    await ref
        .read(userPreferencesProvider.notifier)
        .savePreferences(prefs);
    if (!mounted) return;
    // Pop back — the MainWrapper will show the main app
    Navigator.of(context).pop();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Artists to display — filtered by selected languages ─────────────────

  List<String> get _artistsToShow {
    final artists = <String>[];
    for (final lang in _selectedLanguages) {
      final list = popularArtistsByLanguage[lang] ?? [];
      for (final a in list) {
        if (!artists.contains(a)) artists.add(a);
      }
    }
    // If no language selected yet, show Hindi
    if (artists.isEmpty) {
      artists.addAll(popularArtistsByLanguage['Hindi'] ?? []);
    }
    return artists;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildProgressBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStepContent(isDark),
              ),
            ),
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    const steps = [
      ('🌐', 'Your Languages', 'Which languages do you vibe with?'),
      ('🎤', 'Your Artists',   'Pick artists you love'),
      ('🎭', 'Your Vibe',      'What mood are you usually in?'),
    ];
    final (emoji, title, subtitle) = steps[_step];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skip button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saveAndFinish,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(3, (i) {
              final isActive   = i == _step;
              final isComplete = i < _step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isComplete
                        ? AppColors.green
                        : isActive
                            ? AppColors.pink
                            : Colors.grey.withOpacity(0.3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${_step + 1} of 3',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step content router ────────────────────────────────────────────────────

  Widget _buildStepContent(bool isDark) {
    switch (_step) {
      case 0: return _buildLanguageStep(isDark);
      case 1: return _buildArtistStep(isDark);
      case 2: return _buildMoodStep(isDark);
      default: return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Languages
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLanguageStep(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemCount: availableLanguages.length,
      itemBuilder: (_, i) {
        final lang     = availableLanguages[i];
        final id       = lang['id']!;
        final emoji    = lang['emoji']!;
        final selected = _selectedLanguages.contains(id);

        final accent = _langColor(i);

        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedLanguages.remove(id);
              // Also remove artists for this language
              final langArtists = popularArtistsByLanguage[id] ?? [];
              _selectedArtists.removeAll(langArtists);
            } else {
              _selectedLanguages.add(id);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? accent : (isDark ? Colors.white10 : Colors.white),
              border: Border.all(
                color: selected ? accent : Colors.grey.withOpacity(0.3),
                width: selected ? 2.5 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 8, offset: const Offset(2, 3))]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      id,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Artists
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildArtistStep(bool isDark) {
    final artists = _artistsToShow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '${_selectedArtists.length} selected',
            style: TextStyle(
              color: AppColors.pink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.6,
            ),
            itemCount: artists.length,
            itemBuilder: (_, i) {
              final artist   = artists[i];
              final selected = _selectedArtists.contains(artist);
              final accent   = _artistColor(i);

              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedArtists.remove(artist);
                  } else {
                    _selectedArtists.add(artist);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? accent : (isDark ? Colors.white10 : Colors.white),
                    border: Border.all(
                      color: selected ? accent : Colors.grey.withOpacity(0.3),
                      width: selected ? 2 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(50), // pill shape
                    boxShadow: selected
                        ? [BoxShadow(
                            color: accent.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(2, 3))]
                        : [],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: selected
                              ? Colors.white24
                              : accent.withOpacity(0.15),
                          child: Text(
                            artist.isNotEmpty ? artist[0] : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: selected ? Colors.white : accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            artist,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : (isDark ? Colors.white : AppColors.textPrimary),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Moods
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMoodStep(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.5,
      ),
      itemCount: availableMoods.length,
      itemBuilder: (_, i) {
        final mood     = availableMoods[i];
        final id       = mood['id']!;
        final emoji    = mood['emoji']!;
        final desc     = mood['desc']!;
        final selected = _selectedMoods.contains(id);
        final accent   = _moodColor(i);

        return GestureDetector(
          onTap: () => setState(() {
            if (selected) _selectedMoods.remove(id);
            else _selectedMoods.add(id);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? accent : (isDark ? Colors.white10 : Colors.white),
              border: Border.all(
                color: selected ? accent : Colors.grey.withOpacity(0.3),
                width: selected ? 2.5 : 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 10, offset: const Offset(3, 4))]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const Spacer(),
                      if (selected)
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    id,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white : AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? Colors.white70
                          : (isDark ? Colors.white38 : AppColors.textSecondary),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Footer navigation ──────────────────────────────────────────────────────

  Widget _buildFooter(bool isDark) {
    final isLastStep = _step == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : AppColors.background,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: isDark ? Colors.white38 : Colors.black38,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'BACK',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? AppColors.green : AppColors.pink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.black, width: 2.5),
                  ),
                  elevation: 4,
                  shadowColor: Colors.black54,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        isLastStep ? '🎉  LET\'S GO!' : 'NEXT  →',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Color helpers ──────────────────────────────────────────────────────────

  Color _langColor(int i) {
    const colors = [
      AppColors.pink, AppColors.cyan, AppColors.yellow, AppColors.green,
      AppColors.purple, Color(0xFFFF8C00), Color(0xFF00CED1), Color(0xFFDC143C),
      AppColors.pink, AppColors.cyan, AppColors.green, AppColors.purple,
      AppColors.yellow, Color(0xFFFF6347), Color(0xFF6A5ACD), Color(0xFF20B2AA),
    ];
    return colors[i % colors.length];
  }

  Color _artistColor(int i) {
    const colors = [
      AppColors.cyan, AppColors.pink, AppColors.purple, AppColors.green,
      AppColors.yellow, Color(0xFFFF7043), Color(0xFF26C6DA), Color(0xFFAB47BC),
    ];
    return colors[i % colors.length];
  }

  Color _moodColor(int i) {
    const colors = [
      Color(0xFFFF5722), // Energetic — red-orange
      Color(0xFFE91E63), // Romantic — pink
      Color(0xFF1565C0), // Chill — deep blue
      Color(0xFFFF9800), // Party — amber
      Color(0xFF6A1B9A), // Devotional — purple
      Color(0xFF5D4037), // Retro — brown
      Color(0xFF37474F), // Sad — dark grey
      Color(0xFF2E7D32), // Folk — forest green
    ];
    return colors[i % colors.length];
  }
}
