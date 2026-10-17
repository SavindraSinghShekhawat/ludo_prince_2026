import 'package:flutter/material.dart';
import 'glass_container.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';

class AppDialogLayout extends StatelessWidget {
  final Widget header;
  final List<Widget> body;
  final Widget? footer;
  final bool scrollFooter;
  final bool showHeaderDivider;
  final double borderRadius;

  const AppDialogLayout({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.scrollFooter = false,
    this.showHeaderDivider = true,
    this.borderRadius = 20,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => SafeArea(child: child),
      transitionBuilder: (context, anim1, anim2, transformChild) {
        return ScaleTransition(
          scale: anim1.drive(
            Tween<double>(
              begin: 0.85,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
          ),
          child: FadeTransition(opacity: anim1, child: transformChild),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      minimum: EdgeInsets.symmetric(
        horizontal: isLandscape ? 36 : 20,
        vertical: 24,
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide.none,
        ),
        child: GlassContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: borderRadius,
        showGlow: false,
        color: const Color(0xFF13151B).withValues(alpha: 0.90),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 480,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (showHeaderDivider)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...body,
                      if (footer != null && scrollFooter) ...[
                        const SizedBox(height: 24),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
              if (footer != null && !scrollFooter) ...[
                const SizedBox(height: 24),
                footer!,
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
