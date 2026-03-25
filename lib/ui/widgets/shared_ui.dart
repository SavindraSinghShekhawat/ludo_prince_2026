import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/snackbar_provider.dart';
import '../../utils/app_logger.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;
  final bool showParticles;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.showParticles = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark gradient (Deep void)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B0B1A), Color(0xFF16162C)],
            ),
          ),
        ),

        // Tabletop Texture Layer
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: TabletopTexturePainter(
                opacity: 0.04,
              ),
            ),
          ),
        ),

        // Central Spotlight (Focus on the game board area)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),

        // Animated ambient soft glows (Corner accents)
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.deepPurpleAccent.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
              begin: const Offset(0, 0),
              end: const Offset(30, 30),
              duration: 10.seconds,
              curve: Curves.easeInOut),
        ),

        Positioned(
          bottom: -50,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blueAccent.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
              begin: const Offset(0, 0),
              end: const Offset(-40, -20),
              duration: 12.seconds,
              curve: Curves.easeInOut),
        ),

        child,
      ],
    );
  }
}

class TabletopTexturePainter extends CustomPainter {
  final double opacity;
  TabletopTexturePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.0;

    final random = math.Random(123); // Seeded for consistency

    // Draw fine grain/noise
    final List<Offset> points = [];
    for (int i = 0; i < (size.width * size.height * 0.01).toInt(); i++) {
      points.add(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
      );
    }
    canvas.drawPoints(PointMode.points, points, paint);

    // Draw subtle "wood/felt" fibers
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 0.5;

    for (int i = 0; i < 100; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double len = random.nextDouble() * 20 + 5;
      double angle = random.nextDouble() * math.pi;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(angle) * len, y + math.sin(angle) * len),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GameButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final bool isPrimary;

  const GameButton({
    super.key,
    required this.text,
    required this.onTap,
    this.color = Colors.deepPurpleAccent,
    this.icon,
    this.isPrimary = false,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: 100.ms,
        transform: Matrix4.identity()..translate(0.0, _isPressed ? 4.0 : 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.color,
          boxShadow: [
            if (!_isPressed)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                offset: const Offset(0, 6),
                blurRadius: 0,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
              ],
              Text(
                widget.text.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isComingSoon;
  final double height;

  const GlassCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.isPrimary = false,
    this.isComingSoon = false,
    this.height = 160,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: 300.ms,
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateX(_isHovered ? -0.05 : 0.0)
            ..rotateY(_isHovered ? 0.05 : 0.0)
            ..scale(_isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        blurRadius: _isHovered ? 30 : 20,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(widget.icon,
                          size: widget.height * 0.9,
                          color: widget.accentColor.withValues(alpha: 0.12)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(widget.height * 0.15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(widget.icon,
                                  color: widget.accentColor,
                                  size: widget.height * 0.25),
                              if (widget.isComingSoon)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.accentColor
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: widget.accentColor
                                            .withValues(alpha: 0.4),
                                        width: 1),
                                  ),
                                  child: Text(
                                    "COMING SOON",
                                    style: TextStyle(
                                      color: widget.accentColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                )
                                    .animate(
                                        onPlay: (c) => c.repeat(reverse: true))
                                    .scale(
                                        begin: const Offset(1, 1),
                                        end: const Offset(1.05, 1.05),
                                        duration: 1.5.seconds,
                                        curve: Curves.easeInOut)
                                    .shimmer(
                                        duration: 3.seconds,
                                        color: Colors.white
                                            .withValues(alpha: 0.2)),
                            ],
                          ),
                          SizedBox(height: widget.height * 0.1),
                          Text(widget.title,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.height * 0.13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0)),
                          Text(widget.subtitle,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: widget.height * 0.08)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Add a more premium, color-integrated shimmer
    card = card
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 2.5.seconds,
          color: widget.accentColor.withValues(alpha: 0.15),
        )
        .shimmer(
          duration: 3.seconds,
          delay: 1.seconds,
          color: Colors.white.withValues(alpha: 0.1),
        );

    // Add a very subtle pulse for the primary card to make it feel alive
    if (widget.isPrimary) {
      card = card.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.02, 1.02),
            duration: 3.seconds,
            curve: Curves.easeInOut,
          );

      // Add a soft breathing glow
      card = card.animate(onPlay: (c) => c.repeat(reverse: true)).custom(
            duration: 3.seconds,
            builder: (context, value, child) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.15 * value),
                    blurRadius: 15 + (15 * value),
                    spreadRadius: 3 * value,
                  ),
                ],
              ),
              child: child,
            ),
          );
    }

    return card;
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.borderRadius = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: color ?? Colors.white.withValues(alpha: 0.05),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    Color? color,
    bool isError = false,
    bool isSuccess = false,
    Duration? duration,
  }) {
    try {
      final container = ProviderScope.containerOf(context);
      container.read(snackBarProvider.notifier).show(
            message: message,
            icon: icon,
            color: color,
            isError: isError,
            isSuccess: isSuccess,
            duration: duration,
          );
    } catch (e) {
      // Fallback if ProviderScope is not reachable
      AppLogger.error("SnackBar error: $e");
    }
  }
}

class CustomSnackBarHost extends ConsumerWidget {
  const CustomSnackBarHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(snackBarProvider);

    return Positioned(
      bottom: 0, // Lowered because we now use SafeArea and Padding inside
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: 400.ms,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (child, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              if (child != null) child,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: state == null
            ? const SizedBox.shrink()
            : _SnackBarContent(
                key: ValueKey(state.timestamp),
                message: state.message,
                icon: state.icon,
                color: state.color,
                isError: state.isError,
                isSuccess: state.isSuccess,
                onDismissed: () => ref.read(snackBarProvider.notifier).hide(),
              ),
      ),
    );
  }
}

class _SnackBarContent extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;
  final bool isError;
  final bool isSuccess;
  final VoidCallback onDismissed;

  const _SnackBarContent({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
    this.isError = false,
    this.isSuccess = false,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final snackBarColor = isError
        ? Colors.redAccent
        : isSuccess
            ? const Color(0xFF00FFA3)
            : color ?? Colors.cyanAccent;

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.horizontal,
                dismissThresholds: const {
                  DismissDirection.horizontal: 0.1,
                },
                onDismissed: (_) => onDismissed(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: snackBarColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: snackBarColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isError
                              ? Icons.error_outline
                              : isSuccess
                                  ? Icons.check_circle_outline
                                  : icon,
                          color: snackBarColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
          // Expanding "Radar" Rings
          ...List.generate(3, (index) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (color ?? Colors.deepPurpleAccent)
                      .withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(2.0, 2.0),
                  duration: 3.seconds,
                  delay: (index * 1.0).seconds,
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 3.seconds);
          }),

          // Outer pulsing ring
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

          // Secondary rotating gradient ring
          Container(
            width: size * 1.1,
            height: size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(
                color:
                    (color ?? Colors.deepPurpleAccent).withValues(alpha: 0.1),
                width: 1,
              )),
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 5.seconds),

          // Use the shared LudoLoadingDots
          LudoLoadingDots(size: size * 0.6),

          // Center icon or dot
          Container(
            width: size * 0.35,
            height: size * 0.35,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white54,
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.public,
              size: size * 0.22,
              color: Colors.black,
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

/// A reusable Ludo-themed loading animation with 4 rotating and pulsating dots.
class LudoLoadingDots extends StatelessWidget {
  final double size;
  const LudoLoadingDots({super.key, required this.size});

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
