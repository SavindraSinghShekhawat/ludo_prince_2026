import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B0B1A), Color(0xFF16162C)],
            ),
          ),
        ),
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
                  Colors.deepPurpleAccent.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
              begin: const Offset(0, 0),
              end: const Offset(40, 40),
              duration: 6.seconds,
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
                  Colors.blueAccent.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
              begin: const Offset(0, 0),
              end: const Offset(-50, -30),
              duration: 8.seconds,
              curve: Curves.easeInOut),
        ),
        child,
      ],
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

  const GlassCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.isPrimary = false,
    this.isComingSoon = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTapDown:
          widget.isComingSoon ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isComingSoon
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onTap();
            },
      onTapCancel:
          widget.isComingSoon ? null : () => setState(() => _isPressed = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(widget.icon,
                      size: 140,
                      color: widget.accentColor.withValues(alpha: 0.12)),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(widget.icon,
                              color: widget.accentColor, size: 40),
                          if (widget.isComingSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    widget.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: widget.accentColor
                                        .withValues(alpha: 0.4),
                                    width: 1),
                              ),
                              child: Text(
                                "COMING SOON",
                                style: TextStyle(
                                  color: widget.accentColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(
                                    begin: const Offset(1, 1),
                                    end: const Offset(1.05, 1.05),
                                    duration: 1.5.seconds,
                                    curve: Curves.easeInOut)
                                .shimmer(
                                    duration: 3.seconds,
                                    color: Colors.white.withValues(alpha: 0.2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(widget.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0)),
                      Text(widget.subtitle,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(target: _isPressed ? 1 : 0)
        .scaleXY(end: 0.95, duration: 100.ms, curve: Curves.easeOut);

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
                    color: widget.accentColor.withValues(alpha: 0.1 * value),
                    blurRadius: 15 + (10 * value),
                    spreadRadius: 2 * value,
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
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    Color? color,
    bool isError = false,
    bool isSuccess = false,
    Duration? duration,
  }) {
    // If there's an existing entry, remove it immediately to show the new one
    // In a more advanced version, we could tell the old one to animate out first.
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
    }

    // Calculate ideal duration if not provided
    // Base 2s + 50ms per character, clamped between 3s and 7s
    final calculatedDuration = duration ??
        Duration(
          milliseconds: (2000 + (message.length * 50)).clamp(3000, 7000),
        );

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _SnackBarContent(
        message: message,
        icon: icon,
        color: color,
        isError: isError,
        isSuccess: isSuccess,
        duration: calculatedDuration,
        onDismissed: () {
          if (_currentEntry?.mounted ?? false) {
            _currentEntry!.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _SnackBarContent extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color? color;
  final bool isError;
  final bool isSuccess;
  final Duration duration;
  final VoidCallback onDismissed;

  const _SnackBarContent({
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
    this.isError = false,
    this.isSuccess = false,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_SnackBarContent> createState() => _SnackBarContentState();
}

class _SnackBarContentState extends State<_SnackBarContent> {
  bool _isVisible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start entrance animation
    Future.microtask(() {
      if (mounted) setState(() => _isVisible = true);
    });

    // Schedule exit animation and dismissal
    _timer = Timer(widget.duration, () {
      if (mounted) {
        setState(() => _isVisible = false);
        // Wait for exit animation to complete (400ms match slideY duration)
        Future.delayed(400.ms, () {
          if (mounted) widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snackBarColor = widget.isError
        ? Colors.redAccent
        : widget.isSuccess
            ? const Color(0xFF00FFA3)
            : widget.color ?? Colors.cyanAccent;

    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Material(
                color: Colors.transparent,
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
                          widget.isError
                              ? Icons.error_outline
                              : widget.isSuccess
                                  ? Icons.check_circle_outline
                                  : widget.icon,
                          color: snackBarColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(target: _isVisible ? 1 : 0).fadeIn(duration: 300.ms).slideY(
                      begin: 1,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
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
