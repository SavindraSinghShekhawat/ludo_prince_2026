import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/audio_provider.dart';
import '../screens/settings_screen.dart';
import '../widgets/shared_ui.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QUICK SETTINGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildQuickToggle(
                context,
                icon: audio.isBgmEnabled ? Icons.music_note : Icons.music_off,
                value: audio.isBgmEnabled,
                onChanged: (_) => audio.toggleBGM(),
                accentColor: Colors.purpleAccent,
              ),
              const SizedBox(height: 12),
              _buildQuickToggle(
                context,
                icon: audio.isSfxEnabled ? Icons.volume_up : Icons.volume_off,
                value: audio.isSfxEnabled,
                onChanged: (_) => audio.toggleSFX(),
                accentColor: Colors.orangeAccent,
              ),
              const SizedBox(height: 12),
              _buildQuickToggle(
                context,
                icon: audio.isVibrationEnabled
                    ? Icons.vibration
                    : Icons.phonelink_ring,
                value: audio.isVibrationEnabled,
                onChanged: (_) => audio.toggleVibration(),
                accentColor: Colors.tealAccent,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("ALL SETTINGS & FEEDBACK",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w900)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickToggle(
    BuildContext context, {
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor.withValues(alpha: 0.7), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              icon == Icons.music_note || icon == Icons.music_off
                  ? "Music"
                  : (icon == Icons.volume_up || icon == Icons.volume_off
                      ? "Sounds"
                      : "Vibration"),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: accentColor,
              activeTrackColor: accentColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
