import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';

// ── Providers ──────────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Emits the current Supabase User on every auth state change.
final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((event) => event.session?.user);
});

// ── Service ────────────────────────────────────────────────────────────────
class AuthService {
  /// Stored temporarily for Supabase phone OTP verification (requires phone in verify call).
  String _pendingPhone = '';

  // ── Email / Password ──
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    final res = await supabase.auth
        .signInWithPassword(email: email, password: password);
    return res.user;
  }

  Future<User?> createUserWithEmailAndPassword(
      String email, String password) async {
    final res =
        await supabase.auth.signUp(email: email, password: password);
    return res.user;
  }

  // ── Google OAuth (redirect-based; works on mobile after URL scheme setup) ──
  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.retrobeats://login-callback',
    );
  }

  // ── Phone OTP ──
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    required void Function(dynamic error) verificationFailed,
  }) async {
    _pendingPhone = phoneNumber;
    try {
      await supabase.auth.signInWithOtp(phone: phoneNumber);
      codeSent('supabase_otp'); // verificationId is not used by Supabase
    } catch (e) {
      verificationFailed(e);
    }
  }

  Future<User?> signInWithOTP(
      String verificationId, String smsCode) async {
    final res = await supabase.auth.verifyOTP(
      type: OtpType.sms,
      token: smsCode,
      phone: _pendingPhone,
    );
    return res.user;
  }

  // ── Sign Out ──
  Future<void> signOut() async => supabase.auth.signOut();

  User? get currentUser => supabase.auth.currentUser;
  String? get currentUserId => supabase.auth.currentUser?.id;
}
