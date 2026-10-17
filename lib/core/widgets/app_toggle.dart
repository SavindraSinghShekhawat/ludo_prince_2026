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
        duration: 250.ms,
        width: 46,
        height: 25,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value
              ? accentColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: value
                ? accentColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        child: AnimatedAlign(
          duration: 250.ms,
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? accentColor : const Color(0xFF9E9EAF),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
