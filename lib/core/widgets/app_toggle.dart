import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentColor;

  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: 300.ms,
        width: 48,
        height: 26,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: value ? accentColor.withValues(alpha: 0.3) : Colors.white24,
            width: 1.5,
          ),
          boxShadow: [
            if (value)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: AnimatedAlign(
          duration: 300.ms,
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? accentColor : Colors.white54,
              boxShadow: [
                if (value)
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
