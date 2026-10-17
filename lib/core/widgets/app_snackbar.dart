import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/providers/snackbar_provider.dart';
import 'package:ludo_prince/utils/app_logger.dart';

class AppSnackBar {
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
      AppLogger.error("SnackBar error: $e");
    }
  }
}

class AppSnackBarHost extends ConsumerWidget {
  const AppSnackBarHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(snackBarProvider);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: 400.ms,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (child, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: [...previousChildren, if (child != null) child],
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
        ? const Color(0xFFFF5252)
        : isSuccess
            ? const Color(0xFF00E676)
            : color ?? AppColors.primaryCyan;

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
                dismissThresholds: const {DismissDirection.horizontal: 0.1},
                onDismissed: (_) => onDismissed(),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13151B).withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: snackBarColor.withValues(alpha: 0.12),
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
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  letterSpacing: 0.4,
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
          ),
        ),
      ),
    );
  }
}
