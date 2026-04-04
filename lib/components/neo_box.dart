import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A foundational container for the neobrutalism design system
/// providing thick borders and hard drop shadows.
class NeoBox extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double borderWidth;
  final Offset shadowOffset;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? width;
  final double? height;

  const NeoBox({
    super.key,
    required this.child,
    this.color,
    this.borderWidth = 3.0,
    this.shadowOffset = const Offset(4.0, 4.0),
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.background,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.border,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            offset: shadowOffset,
            blurRadius: 0, // Hard shadow
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
