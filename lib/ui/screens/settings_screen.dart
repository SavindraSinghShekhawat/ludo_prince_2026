import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/audio_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/package_info_provider.dart';
import '../../services/feedback_service.dart';
import 'dice_randomness_screen.dart';
import '../widgets/shared_ui.dart';
import '../dialogs/profile_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _feedbackController = TextEditingController();
  bool _isFeedbackSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isFeedbackSubmitting = true);

    try {
      await ref.read(feedbackServiceProvider).submitFeedback(message);
      if (mounted) {
        _feedbackController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send feedback. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFeedbackSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);
    final displayName = ref.watch(displayNameProvider);

    return AnimatedBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildSectionHeader("Account"),
            InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const ProfileDialog(),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Colors.blueAccent),
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

            // Audio Section
            _buildSectionHeader("Game Audio"),
            const SizedBox(height: 16),
            _buildSettingToggle(
              title: "Background Music",
              subtitle: "Relaxing game tunes",
              icon: audio.isBgmEnabled ? Icons.music_note : Icons.music_off,
              value: audio.isBgmEnabled,
              onChanged: (_) => audio.toggleBGM(),
              accentColor: const Color(0xFF00D1FF), // Azure
            ),
            const SizedBox(height: 12),
            _buildSettingToggle(
              title: "Sound Effects",
              subtitle: "Dice roll & move sounds",
              icon: audio.isSfxEnabled ? Icons.volume_up : Icons.volume_off,
              value: audio.isSfxEnabled,
              onChanged: (_) => audio.toggleSFX(),
              accentColor: const Color(0xFFFFB800), // Gold
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
              accentColor: const Color(0xFF00FFA3), // Emerald
            ),
            const SizedBox(height: 40),

            // Feedback Section
            _buildSectionHeader("Share Feedback"),
            const SizedBox(height: 16),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _feedbackController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isFeedbackSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE5E4E2), // Platinum
                            Color(0xFFB0B4B8), // Silver
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: _isFeedbackSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF1A1A2E)),
                              )
                            : const Text(
                                "SEND TO DEVELOPERS",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(
                                      0xFF1A1A2E), // Dark text on light button
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Developer/Advanced Section
            _buildSectionHeader("Advanced"),
            const SizedBox(height: 16),
            _buildSettingButton(
              title: "Dice Fairness Check",
              subtitle: "Run 100M simulations to verify RNG",
              icon: Icons.analytics_outlined,
              accentColor: Colors.blueAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiceRandomnessScreen()),
              ),
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
    ));
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
      ),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
            activeTrackColor: accentColor.withValues(alpha: 0.3),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
