import 'package:flutter/material.dart';

class LudoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final BoxConstraints? constraints;

  const LudoCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: constraints,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2A3D),
            const Color(0xFF1E1E2C).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
