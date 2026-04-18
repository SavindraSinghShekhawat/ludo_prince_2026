import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/audio_provider.dart';
import '../screens/settings_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/colors.dart';
import '../widgets/custom_dialog_layout.dart';
import '../widgets/shared_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);

    return CustomDialogLayout(
      header: Center(
        child: Text(
          'QUICK SETTINGS',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ),
      body: [
        _buildQuickToggle(
          context,
          icon: audio.isBgmEnabled ? Icons.music_note : Icons.music_off,
          value: audio.isBgmEnabled,
          onChanged: (_) => audio.toggleBGM(),
          accentColor: const Color(0xFFD47AFF), // High-Luminance Amethyst
          label: "Music",
        ),
        const SizedBox(height: 12),
        _buildQuickToggle(
          context,
          icon: audio.isSfxEnabled ? Icons.volume_up : Icons.volume_off,
          value: audio.isSfxEnabled,
          onChanged: (_) => audio.toggleSFX(),
          accentColor: AppColors.primaryCyan, // Brand Cyan
          label: "Sounds",
        ),
        const SizedBox(height: 12),
        _buildQuickToggle(
          context,
          icon: audio.isVibrationEnabled
              ? Icons.vibration
              : Icons.phonelink_ring,
          value: audio.isVibrationEnabled,
          onChanged: (_) => audio.toggleVibration(),
          accentColor: const Color(0xFF00FF88), // Spring Jade
          label: "Vibration",
        ),
        const SizedBox(height: 24),
        GameButton(
          text: "ALL SETTINGS",
          height: 52,
          fontSize: 16,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickToggle(
    BuildContext context, {
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accentColor,
    required String label,
  }) {
    return AnimatedContainer(
      duration: 300.ms,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
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
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: value ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          LudoToggle(
            value: value,
            onChanged: onChanged,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }
}
