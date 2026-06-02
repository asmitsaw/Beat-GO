import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/neo_button.dart';
import '../../components/neo_text_field.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController   = TextEditingController();
  bool _isLoading = false;
  bool _codeSent  = false;
  String? _verificationId;

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
        phoneNumber: phone,
        codeSent: (verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _codeSent   = true;
              _isLoading  = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP sent! Check your messages.')),
            );
          }
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $e')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signInWithOTP(_verificationId!, otp);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('PHONE',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2),
                  textAlign: TextAlign.center),
              const Text('LOGIN',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900,
                      letterSpacing: -2, color: AppColors.yellow),
                  textAlign: TextAlign.center),
              const SizedBox(height: 48),
              if (!_codeSent) ...[
                NeoTextField(
                    controller: _phoneController,
                    hintText: '+1 234 567 8900',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 32),
                NeoButton(
                  onPressed: _isLoading ? () {} : _sendCode,
                  color: AppColors.yellow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: AppColors.textPrimary, strokeWidth: 2.5)
                        : const Text('SEND OTP',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ] else ...[
                NeoTextField(
                    controller: _otpController,
                    hintText: '6-digit code',
                    keyboardType: TextInputType.number),
                const SizedBox(height: 32),
                NeoButton(
                  onPressed: _isLoading ? () {} : _verifyOTP,
                  color: AppColors.cyan,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: AppColors.textPrimary, strokeWidth: 2.5)
                        : const Text('VERIFY & LOGIN',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
