import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ludo_prince/utils/colors.dart';
import 'app_loading_dots.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool isPrimary;
  final bool isSmall;
  final bool isLoading;
  final String? loadingText;
  final double? fontSize;
  final double? height;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onTap,
    this.color = AppColors.starPlatinum,
    this.icon,
    this.isPrimary = false,
    this.fontSize,
    this.isSmall = false,
    this.isLoading = false,
    this.loadingText,
    this.height,
    this.width,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double buttonHeight = widget.height ?? (widget.isSmall ? 40 : 60);
    final bool isDarkText = widget.color.computeLuminance() > 0.5;
    final Color contentColor =
        isDarkText ? AppColors.systemBackground : Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLoading && widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: 200.ms,
        curve: Curves.easeOut,
        height: buttonHeight,
        width: widget.width,
        constraints: BoxConstraints(minWidth: widget.isLoading ? 60 : 120),
        transform: Matrix4.identity()
          ..scale(_isPressed && !widget.isLoading ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.isLoading ? 30 : 15),
          color: widget.color,
          border: widget.isPrimary
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : Border.all(
                  color: Colors.black.withValues(alpha: 0.1),
                  width: 1.0,
                ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            if (widget.isLoading)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 3,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onTap,
            borderRadius: BorderRadius.circular(widget.isLoading ? 30 : 15),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isLoading ? 0 : (widget.isSmall ? 16 : 24),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Text/Icon Layer
                  AnimatedOpacity(
                    opacity: widget.isLoading ? 0.0 : 1.0,
                    duration: 250.ms,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: contentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          widget.text.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: contentColor,
                            fontSize:
                                widget.fontSize ?? (widget.isSmall ? 12 : 18),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                          duration: 4.seconds,
                          color: isDarkText
                              ? Colors.black.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                  ),
                  // Loading Layer
                  if (widget.isLoading)
                    AppLoadingDots(
                      size: widget.isSmall ? 24 : 35,
                    ).animate().fadeIn(duration: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
