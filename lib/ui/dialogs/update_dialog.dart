import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/shared_ui.dart';
import '../widgets/custom_dialog_layout.dart';
import '../../utils/colors.dart';
import '../../utils/app_logger.dart';
import '../../utils/app_keys.dart';

class UpdateDialog extends StatelessWidget {
  final bool isForceUpdate;
  final String message;
  final String currentVersion;
  final String newVersion;

  const UpdateDialog({
    super.key,
    required this.isForceUpdate,
    required this.message,
    required this.currentVersion,
    required this.newVersion,
  });

  Future<void> _launchUpdate() async {
    final String packageName = 'com.paisphere.ludoprince';
    final String appId = '6760012267';

    Uri? url;
    if (Theme.of(navigatorKey.currentContext!).platform ==
        TargetPlatform.android) {
      url = Uri.parse('market://details?id=$packageName');
      AppLogger.debug('[UpdateDialog] Attempting Android Market scheme: $url');
    } else if (Theme.of(navigatorKey.currentContext!).platform ==
        TargetPlatform.iOS) {
      url = Uri.parse('itms-apps://itunes.apple.com/app/id$appId');
      AppLogger.debug('[UpdateDialog] Attempting iOS App Store scheme: $url');
    }

    if (url != null && await canLaunchUrl(url)) {
      AppLogger.info('[UpdateDialog] Launching native store app...');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web URL
      final webUrl = Uri.parse(
        Theme.of(navigatorKey.currentContext!).platform == TargetPlatform.iOS
            ? 'https://apps.apple.com/app/id$appId'
            : 'https://play.google.com/store/apps/details?id=$packageName',
      );

      AppLogger.info(
        '[UpdateDialog] Native scheme failed or unsupported. Falling back to web: $webUrl',
      );

      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        AppLogger.error(
          '[UpdateDialog] Could not launch any update URL (native or web)',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomDialogLayout(
      header: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              isForceUpdate ? 'CRITICAL UPDATE' : 'NEW UPDATE',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
              ),
            ),
          ),
          if (!isForceUpdate)
            Positioned(
              right: -8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
        ],
      ),
      body: [
        const SizedBox(height: 16),
        // Animated Icon
        Center(
          child:
              Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primaryCyan,
                      size: 56,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.12, 1.12),
                    duration: 1500.ms,
                    curve: Curves.easeInOutSine,
                  )
                  .shimmer(
                    duration: 3000.ms,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
        ),
        const SizedBox(height: 24),

        // Version Comparison
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildVersionBadge(currentVersion, label: 'CURRENT'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 20,
              ),
            ),
            _buildVersionBadge(newVersion, label: 'LATEST', isLatest: true),
          ],
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

        const SizedBox(height: 24),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: 12),
      ],
      footer:
          Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameButton(
                    text: 'UPDATE NOW',
                    color: AppColors.primaryCyan,
                    onTap: _launchUpdate,
                    isPrimary: true,
                    width: double.infinity,
                  ),
                  if (!isForceUpdate) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 24,
                        ),
                      ),
                      child: Text(
                        'MAYBE LATER',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              )
              .animate()
              .fadeIn(delay: 700.ms)
              .slideY(begin: 0.2, curve: Curves.easeOutBack),
    );
  }

  Widget _buildVersionBadge(
    String version, {
    required String label,
    bool isLatest = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isLatest
                ? AppColors.primaryCyan.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLatest
                  ? AppColors.primaryCyan.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Text(
            'v$version',
            style: TextStyle(
              color: isLatest ? AppColors.primaryCyan : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> show(
    BuildContext context, {
    required bool isForce,
    required String message,
    required String currentVersion,
    required String newVersion,
  }) {
    return CustomDialogLayout.show(
      context: context,
      barrierDismissible: !isForce,
      child: UpdateDialog(
        isForceUpdate: isForce,
        message: message,
        currentVersion: currentVersion,
        newVersion: newVersion,
      ),
    );
  }
}
