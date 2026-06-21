import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  /// Stored temporarily for Supabase phone OTP verification
  String _pendingPhone = '';


  // ── Email / Password ──────────────────────────────────────────────────────
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

  // ── Google Sign-In (native — no browser redirect) ─────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: no ID token received.');
      }

      final res = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return res.user;
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      rethrow;
    }
  }

  Future<void> signOutGoogle() async {
    await GoogleSignIn.instance.signOut();
  }

  // ── Phone OTP ────────────────────────────────────────────────────────────
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    required void Function(dynamic error) verificationFailed,
  }) async {
    _pendingPhone = phoneNumber;
    try {
      await supabase.auth.signInWithOtp(phone: phoneNumber);
      codeSent('supabase_otp');
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

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut().catchError((_) {});
    await supabase.auth.signOut();
  }

  User? get currentUser    => supabase.auth.currentUser;
  String? get currentUserId => supabase.auth.currentUser?.id;

  /// Returns display name from Google or email prefix
  String get displayName {
    final user = currentUser;
    if (user == null) return 'Guest';
    return user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        user.email?.split('@').first ??
        'User';
  }

  /// Returns avatar URL from Google profile
  String? get avatarUrl {
    return currentUser?.userMetadata?['avatar_url'] as String? ??
        currentUser?.userMetadata?['picture'] as String?;
  }
}
