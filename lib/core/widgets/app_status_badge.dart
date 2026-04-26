import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';

class AppStatusBadge extends StatelessWidget {
  final bool isOnline;
  final double size;

  const AppStatusBadge({
    super.key,
    required this.isOnline,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isOnline ? const Color(0xFF00FF88) : const Color(0xFF5A5A5A);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.systemBackground,
          width: size * 0.15,
        ),
      ),
    ).animate(key: ValueKey(isOnline)).scale(
          duration: 300.ms,
          curve: Curves.easeOutBack,
        );
  }
}
