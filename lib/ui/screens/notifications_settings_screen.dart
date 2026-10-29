import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/providers/game_reminder_provider.dart';
import 'package:ludo_prince/services/game_reminder_sync_service.dart';
import 'package:ludo_prince/ui/widgets/shared_ui.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gameReminderProvider);
    final notifier = ref.read(gameReminderProvider.notifier);
    final syncService = ref.read(gameReminderSyncServiceProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('NOTIFICATIONS')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToggleCard(
                  title: "Game Invites",
                  subtitle: "When friends invite you to play",
                  icon: Icons.sports_esports_outlined,
                  value: settings.gameInvitesEnabled,
                  onChanged: (val) => notifier.setGameInvitesEnabled(val),
                  accentColor: AppColors.primaryCyan,
                ),
                const SizedBox(height: 12),
                _buildToggleCard(
                  title: "Friend Requests",
                  subtitle: "When other players add you as a friend",
                  icon: Icons.person_add_outlined,
                  value: settings.friendRequestsEnabled,
                  onChanged: (val) => notifier.setFriendRequestsEnabled(val),
                  accentColor: const Color(0xFFD47AFF), // Amethyst
                ),
                const SizedBox(height: 12),
                _buildToggleCard(
                  title: "Game Reminders",
                  subtitle: "Daily match calls & activity reminders",
                  icon: Icons.notifications_active_outlined,
                  value: settings.dailyReminderEnabled,
                  onChanged: (val) => notifier.setDailyReminderEnabled(val),
                  accentColor: AppColors.imperialAmber,
                ),
                if (!kReleaseMode) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Icon(
                        Icons.bug_report_outlined,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "DEBUG TEST OPTIONS",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTestOptionRow(
                    context: context,
                    title: "Test Game Invite",
                    subtitle: "Simulate incoming match invitation",
                    icon: Icons.sports_esports_outlined,
                    onTap: () async {
                      await syncService.sendTestGameInvite();
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: "Test game invite sent to tray!",
                          isSuccess: true,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTestOptionRow(
                    context: context,
                    title: "Test Friend Request",
                    subtitle: "Simulate new player friend request",
                    icon: Icons.person_add_outlined,
                    onTap: () async {
                      await syncService.sendTestFriendRequest();
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: "Test friend request sent to tray!",
                          isSuccess: true,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTestOptionRow(
                    context: context,
                    title: "Test Game Reminder",
                    subtitle: "Simulate 8:00 PM evening battle call",
                    icon: Icons.notifications_active_outlined,
                    onTap: () async {
                      await syncService.sendTestBattleReminder();
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: "Test game reminder sent to tray!",
                          isSuccess: true,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
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
                  ? accentColor.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 24),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
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

  Widget _buildTestOptionRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: Colors.white70),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.send_rounded,
                size: 16,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
