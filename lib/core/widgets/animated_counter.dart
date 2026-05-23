import 'package:flutter/material.dart';

/// Smoothly animates between integer values with a rolling number effect.
/// Used for the online player count on the home screen.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final intValue = animatedValue.round();
        final displayCount = intValue.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
        return Text(
          '$displayCount$suffix',
          style: style,
        );
      },
    );
  }
}
