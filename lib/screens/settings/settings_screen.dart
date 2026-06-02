import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../components/neo_button.dart';
import '../../services/auth_service.dart';
import '../../services/download_service.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings      = settingsAsync.value;
    final isDark        = settings?.themeMode == ThemeMode.dark;
    final quality       = settings?.audioQuality ?? 'standard';
    final user          = ref.read(authServiceProvider).currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Account section ──────────────────────────────────────────────
          _sectionLabel('ACCOUNT'),
          NeoBox(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(children: [
              _infoRow(Icons.person_outline, 'Email', user?.email ?? 'Not signed in'),
              const Divider(height: 1),
              _infoRow(Icons.fingerprint, 'User ID',
                  user?.id != null
                      ? '${user!.id.substring(0, 8)}…'
                      : 'N/A'),
            ]),
          ),

          // ── Audio quality ─────────────────────────────────────────────────
          _sectionLabel('AUDIO QUALITY'),
          NeoBox(
            color: AppColors.yellow,
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(children: [
              _qualityOption(
                label:    'Standard (128 kbps)',
                subtitle: 'Saves data',
                selected: quality == 'standard',
                onTap:    () => ref
                    .read(settingsProvider.notifier)
                    .setAudioQuality('standard'),
              ),
              const Divider(height: 1, color: Colors.black26),
              _qualityOption(
                label:    'High Quality (320 kbps)',
                subtitle: 'Recommended for headphones',
                selected: quality == 'high',
                onTap:    () => ref
                    .read(settingsProvider.notifier)
                    .setAudioQuality('high'),
              ),
            ]),
          ),

          // ── Appearance ────────────────────────────────────────────────────
          _sectionLabel('APPEARANCE'),
          NeoBox(
            color: AppColors.purple,
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              const Icon(Icons.dark_mode_outlined, size: 28, color: Colors.white),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Dark Mode',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
              ),
              Switch(
                value:     isDark,
                activeColor: AppColors.yellow,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ]),
          ),

          // ── Storage ───────────────────────────────────────────────────────
          _sectionLabel('STORAGE'),
          _StorageSection(),

          const SizedBox(height: 24),

          // ── Sign out ─────────────────────────────────────────────────────
          NeoButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign out?',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pink),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authServiceProvider).signOut();
              }
            },
            color: AppColors.pink,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('SIGN OUT',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(label,
        style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 2,
            color: AppColors.textSecondary)),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    child: Row(children: [
      Icon(icon, size: 22),
      const SizedBox(width: 12),
      Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const Spacer(),
      Text(value,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );

  Widget _qualityOption({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ]),
        ),
      );
}

// ── Storage sub-widget (needs WidgetRef) ───────────────────────────────────

class _StorageSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<_StorageSection> {
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final bytes =
        await ref.read(downloadServiceProvider).getCacheSizeBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return NeoBox(
      color: AppColors.green,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.storage_outlined, size: 26),
          const SizedBox(width: 14),
          const Expanded(
            child: Text('Downloaded Songs',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Text(_fmtBytes(_cacheBytes),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
        ]),
        if (_cacheBytes > 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              await ref
                  .read(downloadServiceProvider)
                  .clearAll(ref);
              _loadSize();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared!')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        AppColors.pink,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Text('CLEAR CACHE',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12)),
            ),
          ),
        ],
      ]),
    );
  }
}
