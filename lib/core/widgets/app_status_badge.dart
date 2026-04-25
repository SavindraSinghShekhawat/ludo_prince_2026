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
        isOnline ? const Color(0xFF00FF88) : const Color(0xFF9E9E9E);
    final icon = isOnline ? Icons.check : Icons.close;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.systemBackground,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.4),
            blurRadius: isOnline ? 6 : 2,
            spreadRadius: isOnline ? 1 : 0,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.6,
          color: AppColors.systemBackground,
        ),
      ),
    ).animate(key: ValueKey(isOnline)).scale(
          duration: 200.ms,
          curve: Curves.easeOutBack,
        );
  }
}
