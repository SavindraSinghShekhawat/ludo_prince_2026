import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/utils/colors.dart';
import 'app_loading_dots.dart';

class MatchmakingLoader extends StatelessWidget {
  final double size;
  final Color? color;

  const MatchmakingLoader({super.key, this.size = 80, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(3, (index) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      (color ?? AppColors.primaryCyan).withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(2.0, 2.0),
                  duration: 3.seconds,
                  delay: (index * 1.0).seconds,
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 3.seconds);
          }),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    (color ?? Colors.deepPurpleAccent).withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
          Container(
            width: size * 1.1,
            height: size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(
                  color:
                      (color ?? AppColors.imperialAmber).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 5.seconds),
          AppLoadingDots(size: size * 0.6),
          Container(
            width: size * 0.35,
            height: size * 0.35,
            decoration: BoxDecoration(
              color: AppColors.starPlatinum,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.starPlatinumGlow,
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.public,
              size: size * 0.22,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.15, 1.15),
                duration: 1.5.seconds,
                curve: Curves.easeInOut,
              )
              .shimmer(duration: 3.seconds),
        ],
      ),
    );
  }
}
