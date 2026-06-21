import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme/app_colors.dart';
import '../../components/neo_box.dart';
import '../../components/neo_button.dart';
import '../../services/music_service.dart' hide debugPrint;

class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  bool _isEnabled = false;
  bool _loading = true;
  bool _isNative = false;
  String _selectedPreset = 'Flat';

  double _bassBoost = 0.0; // Bass Boost level (0.0 to 10.0)

  // Decibel limits
  double _minDb = -15.0;
  double _maxDb = 15.0;

  // Equalizer Bands data
  List<_EqBandInfo> _bands = [];

  // Presets definition
  static const Map<String, List<double>> _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Booster': [5.0, 3.0, 0.0, 0.0, -1.0],
    'Vocal Booster': [-2.0, 0.0, 3.0, 4.0, 1.0],
    'Pop': [-1.0, 2.0, 3.0, 1.0, -1.0],
    'Rock': [4.0, 2.0, -1.0, 2.0, 5.0],
    'Electronic': [3.0, 1.5, 0.0, 1.0, 3.0],
  };

  @override
  void initState() {
    super.initState();
    _initEqualizer();
  }

  Future<void> _initEqualizer() async {
    final eq = ref.read(musicServiceProvider).equalizer;

    // Check if we are running on native Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final params = await eq.parameters;
        final enabled = await eq.enabledStream.first.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => false,
        );

        if (mounted) {
          setState(() {
            _isEnabled = enabled;
            _minDb = params.minDecibels;
            _maxDb = params.maxDecibels;
            _isNative = true;
            _bands = params.bands.map((b) {
              return _EqBandInfo(
                index: b.index,
                label: '${(b.centerFrequency / 1000).toStringAsFixed(0)}k Hz',
                centerFreq: b.centerFrequency,
                userGain: b.gain,
                nativeBand: b,
              );
            }).toList();
            _loading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('Failed to load native Android equalizer: $e');
      }
    }

    // Fallback/Simulated Mode (Web, iOS, Desktop)
    if (mounted) {
      setState(() {
        _isNative = false;
        _isEnabled = true; // Simulated is always enabled for UI feedback
        _minDb = -15.0;
        _maxDb = 15.0;
        _bands = [
          _EqBandInfo(index: 0, label: '60 Hz', centerFreq: 60, userGain: 0.0),
          _EqBandInfo(index: 1, label: '230 Hz', centerFreq: 230, userGain: 0.0),
          _EqBandInfo(index: 2, label: '910 Hz', centerFreq: 910, userGain: 0.0),
          _EqBandInfo(index: 3, label: '4k Hz', centerFreq: 4000, userGain: 0.0),
          _EqBandInfo(index: 4, label: '14k Hz', centerFreq: 14000, userGain: 0.0),
        ];
        _loading = false;
      });
    }
  }

  Future<void> _toggleEqualizer(bool value) async {
    if (_isNative) {
      final eq = ref.read(musicServiceProvider).equalizer;
      try {
        await eq.setEnabled(value);
      } catch (e) {
        debugPrint('Error toggling equalizer: $e');
      }
    }
    setState(() {
      _isEnabled = value;
    });
  }

  Future<void> _updateBandGain(int index, double userGain) async {
    final band = _bands[index];
    band.userGain = userGain;

    // Apply Bass Boost offset if it's a bass band
    double finalGain = userGain;
    if (index == 0) {
      finalGain = (userGain + _bassBoost).clamp(_minDb, _maxDb);
    } else if (index == 1) {
      finalGain = (userGain + _bassBoost * 0.6).clamp(_minDb, _maxDb);
    }

    if (_isNative && band.nativeBand != null) {
      try {
        await band.nativeBand!.setGain(finalGain);
      } catch (e) {
        debugPrint('Error setting native band gain: $e');
      }
    }
    setState(() {
      _selectedPreset = 'Custom';
    });
  }

  Future<void> _applyPreset(String presetName) async {
    final presetGains = _presets[presetName];
    if (presetGains == null) return;

    for (int i = 0; i < _bands.length && i < presetGains.length; i++) {
      _bands[i].userGain = presetGains[i];
      double finalGain = presetGains[i];
      if (i == 0) {
        finalGain = (presetGains[i] + _bassBoost).clamp(_minDb, _maxDb);
      } else if (i == 1) {
        finalGain = (presetGains[i] + _bassBoost * 0.6).clamp(_minDb, _maxDb);
      }

      if (_isNative && _bands[i].nativeBand != null) {
        try {
          await _bands[i].nativeBand!.setGain(finalGain);
        } catch (_) {}
      }
    }
    setState(() {
      _selectedPreset = presetName;
    });
  }

  Future<void> _updateBassBoost(double value) async {
    _bassBoost = value;
    // Re-apply gains for the bass bands (indexes 0 and 1)
    if (_bands.length > 1) {
      await _updateBandGain(0, _bands[0].userGain);
      await _updateBandGain(1, _bands[1].userGain);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('EQUALIZER'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pink))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Warning for simulated platforms ──────────────────────────
                if (!_isNative)
                  NeoBox(
                    color: AppColors.yellow,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Platform Notice',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Audio DSP effects are only supported on Android. Equalizer adjustments are simulated on this device.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Equalizer Switch ──────────────────────────────────────────
                NeoBox(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Equalizer State',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isEnabled,
                        activeThumbColor: AppColors.pink,
                        activeTrackColor: AppColors.pink.withValues(alpha: 0.3),
                        onChanged: _isNative ? _toggleEqualizer : null,
                      ),
                    ],
                  ),
                ),

                // ── Presets Grid ──────────────────────────────────────────────
                _sectionLabel('PRESETS'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: _presets.keys.map((name) {
                    final isSelected = _selectedPreset == name;
                    return NeoButton(
                      onPressed: () {
                        if (_isEnabled) _applyPreset(name);
                      },
                      color: _isEnabled
                          ? (isSelected ? AppColors.pink : AppColors.cyan)
                          : Colors.grey,
                      child: Center(
                        child: Text(
                          name.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Bass Boost Slider ─────────────────────────────────────────
                _sectionLabel('BASS BOOST'),
                NeoBox(
                  color: AppColors.green,
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '🔥 Sub Bass & Punch',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '+${_bassBoost.toStringAsFixed(1)} dB',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.textPrimary,
                          inactiveTrackColor: Colors.black12,
                          thumbColor: AppColors.yellow,
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _bassBoost,
                          min: 0.0,
                          max: 10.0,
                          onChanged: _isEnabled ? _updateBassBoost : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Band Sliders (Visualizer style) ───────────────────────────
                _sectionLabel('FREQUENCY BANDS'),
                NeoBox(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: SizedBox(
                    height: 220,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_bands.length, (i) {
                        final band = _bands[i];
                        return Opacity(
                          opacity: _isEnabled ? 1.0 : 0.4,
                          child: Column(
                            children: [
                              // Gain DB value label
                              Text(
                                '${band.userGain > 0 ? "+" : ""}${band.userGain.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Slider
                              Expanded(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppColors.pink,
                                      inactiveTrackColor: Colors.black12,
                                      thumbColor: AppColors.cyan,
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                      ),
                                    ),
                                    child: Slider(
                                      value: band.userGain,
                                      min: _minDb,
                                      max: _maxDb,
                                      onChanged: _isEnabled
                                          ? (v) => _updateBandGain(i, v)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Freq Label
                              Text(
                                band.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 2,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _EqBandInfo {
  final int index;
  final String label;
  final double centerFreq;
  double userGain;
  final AndroidEqualizerBand? nativeBand;

  _EqBandInfo({
    required this.index,
    required this.label,
    required this.centerFreq,
    required this.userGain,
    this.nativeBand,
  });
}
