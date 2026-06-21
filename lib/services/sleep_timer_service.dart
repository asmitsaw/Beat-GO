import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'music_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Sleep Timer Service
// ══════════════════════════════════════════════════════════════════════════════

class SleepTimerState {
  final Duration? remaining; // null = not active
  final Duration? total;

  const SleepTimerState({this.remaining, this.total});

  bool get isActive => remaining != null;
  double get progress =>
      (total != null && remaining != null && total!.inSeconds > 0)
          ? remaining!.inSeconds / total!.inSeconds
          : 0.0;
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _countdownTimer;

  @override
  SleepTimerState build() => const SleepTimerState();

  void start(Duration duration) {
    _countdownTimer?.cancel();
    state = SleepTimerState(remaining: duration, total: duration);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final prev = state.remaining;
      if (prev == null || prev.inSeconds <= 0) {
        t.cancel();
        _pause();
        state = const SleepTimerState();
        return;
      }
      state = SleepTimerState(
        remaining: prev - const Duration(seconds: 1),
        total: state.total,
      );
    });
  }

  void cancel() {
    _countdownTimer?.cancel();
    state = const SleepTimerState();
  }

  void _pause() {
    // Pause via the player directly
    try {
      ref.read(musicServiceProvider).pause();
    } catch (_) {}
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState>(
        SleepTimerNotifier.new);
