import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/neo_button.dart';
import '../../components/neo_text_field.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import 'phone_auth_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _snack('Please fill all fields');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signInWithEmailAndPassword(email, password);
      // authStateProvider stream will automatically redirect to MainWrapper
    } catch (e) {
      if (mounted) _snack('Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) _snack('Google sign-in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              // Logo
              const Text('RETRO',
                  style: TextStyle(
                      fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -3),
                  textAlign: TextAlign.center),
              const Text('BEATS',
                  style: TextStyle(
                      fontSize: 56, fontWeight: FontWeight.w900,
                      letterSpacing: -3, color: AppColors.pink),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('your retro music player',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 56),

              // Fields
              NeoTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              NeoTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: true),
              const SizedBox(height: 32),

              // Login
              NeoButton(
                onPressed: _isLoading ? () {} : _login,
                color: AppColors.yellow,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: AppColors.textPrimary, strokeWidth: 2.5)
                      : const Text('LOGIN',
                          style: TextStyle(fontWeight: FontWeight.w900,
                              fontSize: 16, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 12),

              // Register
              NeoButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                color: AppColors.cyan,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('CREATE ACCOUNT',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 12),

              // Social login row
              Row(children: [
                Expanded(
                  child: NeoButton(
                    onPressed: _isLoading ? () {} : _googleSignIn,
                    color: Colors.white,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Google',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const PhoneAuthScreen())),
                    color: AppColors.purple,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Phone',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
