import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';

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
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateX(_isHovered ? -0.05 : 0.0)
            ..rotateY(_isHovered ? 0.05 : 0.0)
            ..multiply(Matrix4.diagonal3Values(
              _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
              _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
              1.0,
            )),
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
                    color: widget.accentColor.withValues(
                      alpha: widget.isPrimary ? 0.18 : 0.06,
                    ),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(
                        alpha: _isHovered ? 0.15 : 0.08,
                      ),
                      blurRadius: _isHovered ? 50 : 25,
                      spreadRadius: _isHovered ? 4 : 0,
                      offset: const Offset(0, 15),
                    ),
                    if (widget.isPrimary)
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.05),
                        blurRadius: 80,
                        spreadRadius: 10,
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Specular Highlight (The 'Carved Glass' line)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        widget.icon,
                        size: widget.height * 0.9,
                        color: widget.accentColor.withValues(alpha: 0.12),
                      ),
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
                              Icon(
                                widget.icon,
                                color: widget.accentColor,
                                size: widget.height * 0.25,
                              ),
                              if (widget.isComingSoon)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.accentColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.accentColor.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    "COMING SOON",
                                    style: TextStyle(
                                      color: widget.accentColor,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .scale(
                                      begin: const Offset(1, 1),
                                      end: const Offset(1.05, 1.05),
                                      duration: 1.5.seconds,
                                      curve: Curves.easeInOut,
                                    )
                                    .shimmer(
                                      duration: 3.seconds,
                                      color: AppColors.imperialJade.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                            ],
                          ),
                          SizedBox(height: widget.height * 0.1),
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.height * 0.13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: widget.height * 0.08,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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

    // Add a single, clean white shimmer for an elegant light-reflection effect
    card = card.animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 3.seconds,
          delay: 1.seconds,
          color: Colors.white.withValues(alpha: 0.15),
        );

    // Add a very subtle pulse for the primary card to make it feel alive
    if (widget.isPrimary) {
      card = card.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.01, 1.01),
            duration: 4.seconds,
            curve: Curves.easeInOut,
          );
    }

    return card;
  }
}
