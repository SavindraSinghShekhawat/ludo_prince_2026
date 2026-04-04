import 'package:flutter/material.dart';
import 'shared_ui.dart';
import '../../utils/colors.dart';

class CustomDialogLayout extends StatelessWidget {
  final Widget header;
  final List<Widget> body;
  final Widget? footer;
  final bool scrollFooter;
  final bool showHeaderDivider;

  const CustomDialogLayout({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.scrollFooter = false,
    this.showHeaderDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: MediaQuery.of(context).orientation == Orientation.portrait
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        showGlow: true,
        glowColor: AppColors.primaryCyan,
        color: AppColors.systemBackground.withValues(alpha: 0.65),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).orientation == Orientation.landscape
                    ? 500
                    : double.infinity,
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
    );
  }
}
