import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class LogoWidget extends StatelessWidget {
  final double fontSize;
  final bool showCrown;

  const LogoWidget({
    super.key,
    this.fontSize = 28,
    this.showCrown = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCrown)
          SizedBox(
            height: fontSize * 1.5,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Backlight Glow
                Container(
                  width: fontSize * 1.8,
                  height: fontSize * 1.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.amber.withValues(alpha: 0.4),
                        Colors.amber.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.3, 1.3),
                      duration: 2.seconds,
                      curve: Curves.easeInOutSine,
                    )
                    .blur(
                        begin: const Offset(10, 10), end: const Offset(20, 20)),

                // Sparkles / Particles (Platinum Stream)
                ...List.generate(6, (index) {
                  final delay = index * 500;
                  // Organic jitter and curved paths
                  final double xOffset = (index - 2.5) * 14.0;

                  return Positioned(
                    top: fontSize * 0.45, // Originating from the crown's body
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(xOffset, 0),
                        child: Icon(
                          Icons.star,
                          color: const Color(0xFFE5E4E2)
                              .withValues(alpha: 0.8), // Platinum
                          size: 4 + (index % 4 * 3),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .fadeIn(delay: delay.ms, duration: 600.ms)
                            .scale(begin: Offset.zero, end: const Offset(1, 1))
                            .moveY(
                                begin: 0,
                                end: -180,
                                duration: 3.5.seconds,
                                curve: Curves.easeOutQuad)
                            .moveX(
                                begin: 0,
                                end: (index % 2 == 0 ? 20 : -20),
                                duration: 3.5.seconds)
                            .fadeOut(
                                delay: (delay + 2200).ms, duration: 1000.ms),
                      ),
                    ),
                  );
                }),

                // The Crown itself
                Image.asset(
                  'assets/crown.png',
                  width: fontSize * 1.5,
                  height: fontSize * 1.5,
                  fit: BoxFit.contain,
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0,
                      end: -10,
                      duration: 2.5.seconds,
                      curve: Curves.easeInOutSine,
                    )
                    .rotate(
                      begin: -0.06,
                      end: 0.06,
                      duration: 3.seconds,
                      curve: Curves.easeInOutSine,
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      delay: 2.seconds,
                      duration: 3.seconds,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
              ],
            ),
          ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFE5E4E2), // Platinum base
              Color(0xFFFFFFFF), // White highlight
              Color(0xFFBCC6CC), // Silver/Metallic
              Color(0xFFE5E4E2), // Return to base
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            "LUDO PRINCE",
            style: GoogleFonts.outfit(
              textStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.0,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 3.seconds, color: Colors.white.withValues(alpha: 0.4)),
      ],
    );
  }
}
