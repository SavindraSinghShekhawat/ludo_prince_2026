import 'package:ludo_prince/ui/widgets/shared_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/models/app_notification.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'friend_requests_dialog.dart';
import 'invite_dialog.dart';

class NotificationInboxDialog extends ConsumerWidget {
  const NotificationInboxDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final inbox = state.inbox;

    return AppDialogLayout(
      header: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primaryCyan,
            size: 28,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 2.seconds,
                curve: Curves.easeInOut,
              )
              .shimmer(duration: 3.seconds, color: Colors.white24),
          const SizedBox(width: 16),
          Text(
            'NOTIFICATIONS',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
      body: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: inbox.isEmpty
                  ? null
                  : () =>
                      ref.read(notificationProvider.notifier).markAllAsRead(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Mark all as read',
                style: GoogleFonts.outfit(
                  color: inbox.isEmpty ? Colors.white24 : AppColors.primaryCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (inbox.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: Colors.white.withValues(alpha: 0.1),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your inbox is empty',
                    style: GoogleFonts.outfit(
                      color: Colors.white24,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: inbox.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = inbox[index];
                return _buildNotificationItem(context, ref, notification)
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                    .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) {
    final color = _getNotificationColor(n);
    final timeStr = DateFormat('h:mm a').format(n.timestamp);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _handleNotificationClick(context, ref, n);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.isRead
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: n.isRead
                ? Colors.white.withValues(alpha: 0.05)
                : color.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            if (!n.isRead)
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Icon(_getNotificationIcon(n), color: color, size: 22)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: 3.seconds,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: n.isRead ? Colors.white70 : Colors.white,
                            fontSize: 14,
                            fontWeight:
                                n.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: GoogleFonts.outfit(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: n.isRead ? Colors.white38 : Colors.white60,
                      fontSize: 12,
                      fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                margin: const EdgeInsets.only(left: 12),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
                    duration: 1.seconds,
                    begin: 0.4,
                    end: 1.0,
                    curve: Curves.easeInOut,
                  ),
          ],
        ),
      ),
    );
  }

  Color _getNotificationColor(AppNotification n) {
    switch (n.type) {
      case NotificationType.friendRequest:
        return AppColors.primaryCyan;
      case NotificationType.gameInvite:
        return AppColors.imperialAmber;
      case NotificationType.system:
        return AppColors.imperialJade;
    }
  }

  IconData _getNotificationIcon(AppNotification n) {
    switch (n.type) {
      case NotificationType.friendRequest:
        return Icons.person_add_outlined;
      case NotificationType.gameInvite:
        return Icons.games_outlined;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  void _handleNotificationClick(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) {
    ref.read(notificationProvider.notifier).markAsRead(n.id);

    if (n.type == NotificationType.friendRequest) {
      AppDialogLayout.show(
        context: context,
        child: const FriendRequestsDialog(), // Handled by service listener
      );
    } else if (n.type == NotificationType.gameInvite) {
      AppDialogLayout.show(
        context: context,
        barrierDismissible: false,
        child: InviteDialog(
          inviteId: n.id,
          fromName: n.data['fromName'] ?? 'Someone',
          gameId: n.data['gameId'] ?? '',
          joiningCode: n.data['joiningCode'] ?? '',
        ),
      );
    }
  }
}
