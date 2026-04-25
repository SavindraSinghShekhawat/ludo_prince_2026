import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A reusable Ludo-themed loading animation with 4 rotating and pulsating dots.
class AppLoadingDots extends StatelessWidget {
  final double size;
  const AppLoadingDots({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final dotSize = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating container
          Stack(
            children: List.generate(4, (index) {
              final colors = [
                const Color(0xFF2196F3), // Blue
                const Color(0xFFFFC107), // Yellow
                const Color(0xFF4CAF50), // Green
                const Color(0xFFF44336), // Red
              ];

              return RotationTransition(
                turns: AlwaysStoppedAnimation(index * 0.25),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors[index].withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.2, 1.2),
                        duration: 800.ms,
                        delay: (index * 200).ms,
                        curve: Curves.easeInOut,
                      ),
                ),
              );
            }),
          )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 3.seconds, curve: Curves.linear),
        ],
      ),
    );
  }
}
