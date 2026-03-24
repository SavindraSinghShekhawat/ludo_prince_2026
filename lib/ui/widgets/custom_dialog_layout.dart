import 'package:flutter/material.dart';
import 'shared_ui.dart';

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
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
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
                const Divider(color: Colors.white24, height: 32)
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
