import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'neo_box.dart';

class NeoButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  final double borderWidth;

  const NeoButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = AppColors.yellow,
    this.borderWidth = 3.0,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(
          _isPressed ? 4.0 : 0.0,
          _isPressed ? 4.0 : 0.0,
          0.0,
        ),
        child: NeoBox(
          color: widget.color,
          borderWidth: widget.borderWidth,
          shadowOffset: _isPressed ? Offset.zero : const Offset(4.0, 4.0),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
