import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
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

    return AnimatedContainer(
      duration: 200.ms,
      curve: Curves.easeOut,
      height: buttonHeight,
      width: widget.width,
      constraints: BoxConstraints(minWidth: widget.isLoading ? 60 : 120),
      transform: Matrix4.diagonal3Values(
        _isPressed && !widget.isLoading ? 0.97 : 1.0,
        _isPressed && !widget.isLoading ? 0.97 : 1.0,
        1.0,
      ),
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
          onHighlightChanged: widget.isLoading
              ? null
              : (isHovering) => setState(() => _isPressed = isHovering),
          borderRadius: BorderRadius.circular(widget.isLoading ? 30 : 15),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isLoading ? 0 : (widget.isSmall ? 16 : 24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: widget.isLoading ? 0.0 : 1.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: contentColor,
                          size: widget.isSmall ? 18 : 22,
                        ),
                        SizedBox(width: widget.isSmall ? 6 : 8),
                      ],
                      Text(
                        widget.text,
                        style: GoogleFonts.outfit(
                          color: contentColor,
                          fontSize:
                              widget.fontSize ?? (widget.isSmall ? 14 : 16),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isLoading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLoadingDots(size: widget.isSmall ? 24 : 35),
                      if (widget.loadingText != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.loadingText!,
                          style: GoogleFonts.outfit(
                            color: contentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
