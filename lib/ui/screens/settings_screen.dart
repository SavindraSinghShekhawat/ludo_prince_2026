import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/providers/audio_provider.dart';
import 'package:ludo_prince/providers/auth_provider.dart';
import 'package:ludo_prince/providers/package_info_provider.dart';
import 'dice_randomness_screen.dart';
import '../widgets/shared_ui.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/ui/dialogs/profile_dialog.dart';
import 'package:ludo_prince/utils/share_helper.dart';
import 'feedback_screen.dart';
import 'package:ludo_prince/services/remote_config_service.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/ui/dialogs/update_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingUpdate = false;

  Future<void> _handleUpdateCheck() async {
    setState(() => _isCheckingUpdate = true);

    try {
      final status = await remoteConfigService.checkUpdate();

      if (mounted) {
        if (status == UpdateStatus.none) {
          AppSnackBar.show(
            context,
            message: "You're already on the latest version!",
            isSuccess: true,
          );
        } else {
          UpdateDialog.show(
            context,
            isForce: status == UpdateStatus.force,
            message: remoteConfigService.updateMessage,
            currentVersion: remoteConfigService.currentVersion,
            newVersion: remoteConfigService.latestVersion,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Failed to check for updates: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);
    final displayName = ref.watch(displayNameProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('SETTINGS')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Section
                _buildSectionHeader("Account"),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    AppDialogLayout.show(
                      context: context,
                      child: const ProfileDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryCyan.withValues(
                            alpha: 0.2,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primaryCyan,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                "Tap to view profile details",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Preferences Section
                _buildSectionHeader("Preferences"),
                const SizedBox(height: 16),
                _buildSettingToggle(
                  title: "Background Music",
                  subtitle: "Relaxing game tunes",
                  icon: audio.isBgmEnabled ? Icons.music_note : Icons.music_off,
                  value: audio.isBgmEnabled,
                  onChanged: (_) => audio.toggleBGM(),
                  accentColor: const Color(
                    0xFFD47AFF,
                  ), // High-Luminance Amethyst
                ),
                const SizedBox(height: 12),
                _buildSettingToggle(
                  title: "Sound Effects",
                  subtitle: "Dice roll & move sounds",
                  icon: audio.isSfxEnabled ? Icons.volume_up : Icons.volume_off,
                  value: audio.isSfxEnabled,
                  onChanged: (_) => audio.toggleSFX(),
                  accentColor: AppColors.primaryCyan, // Brand Cyan
                ),
                const SizedBox(height: 12),
                _buildSettingToggle(
                  title: "Vibration",
                  subtitle: "Haptic feedback on moves",
                  icon: audio.isVibrationEnabled
                      ? Icons.vibration
                      : Icons.phonelink_ring,
                  value: audio.isVibrationEnabled,
                  onChanged: (_) => audio.toggleVibration(),
                  accentColor: const Color(0xFF00FF88), // Spring Jade
                ),
                const SizedBox(height: 32),

                // Community & Support Section
                _buildSectionHeader("Community & Support"),
                const SizedBox(height: 16),
                _buildSettingButton(
                  title: "Invite Friends",
                  subtitle: "Share Ludo Prince with your crew",
                  icon: Icons.share_outlined,
                  accentColor: AppColors.primaryCyan,
                  onTap: () => ShareHelper.shareApp(context),
                ),
                const SizedBox(height: 12),
                _buildSettingButton(
                  title: "Share Feedback",
                  subtitle: "Help us make Ludo Prince better",
                  icon: Icons.feedback_outlined,
                  accentColor: AppColors.imperialJade,
                  onTap: () => Navigator.push(
                    context,
                    FadeThroughPageRoute(page: const FeedbackScreen()),
                  ),
                ),
                const SizedBox(height: 32),

                // Advanced Section
                _buildSectionHeader("Technical"),
                const SizedBox(height: 16),
                _buildSettingButton(
                  title: "Dice Fairness Check",
                  subtitle: "Verify RNG via simulations",
                  icon: Icons.analytics_outlined,
                  accentColor: AppColors.midnightSapphire,
                  onTap: () => Navigator.push(
                    context,
                    FadeThroughPageRoute(
                      page: const DiceRandomnessScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingButton(
                  title: "Check for Update",
                  subtitle: _isCheckingUpdate
                      ? "Searching for latest version..."
                      : "Make sure you're on the best version",
                  icon: Icons.update_rounded,
                  accentColor: AppColors.primaryCyan,
                  isLoading: _isCheckingUpdate,
                  onTap: _isCheckingUpdate ? () {} : _handleUpdateCheck,
                ),
                const SizedBox(height: 48),

                Center(
                  child: ref.watch(packageInfoProvider).when(
                        data: (info) => Text(
                          "Ludo Prince v${info.version}${kReleaseMode ? '' : '+${info.buildNumber}'}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (e, s) => const SizedBox.shrink(),
                      ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          width: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accentColor,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? accentColor.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                key: ValueKey<IconData>(icon),
                color: accentColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          AppToggle(
            value: value,
            onChanged: onChanged,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor,
                      ),
                    )
                  : Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
