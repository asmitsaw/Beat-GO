import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'neo_box.dart';

class NeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const NeoTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return NeoBox(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      borderRadius: 8.0,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.normal,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
