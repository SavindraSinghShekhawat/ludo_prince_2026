import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_dialog_layout.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import '../../models/ludo_notification.dart';
import 'package:ludo_prince/utils/colors.dart';
import '../../ui/dialogs/friend_requests_dialog.dart';
import '../../ui/dialogs/invite_dialog.dart';

class AppNotificationHost extends ConsumerWidget {
  const AppNotificationHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final activeToast = state.activeToast;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: 600.ms,
        reverseDuration: 400.ms,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInBack,
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1.2),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        },
        child: activeToast == null
            ? const SizedBox.shrink(key: ValueKey('empty_toast'))
            : SafeArea(
                key: ValueKey(activeToast.id),
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TopNotificationToast(notification: activeToast),
                ),
              ),
      ),
    );
  }
}

class TopNotificationToast extends ConsumerWidget {
  final LudoNotification notification;

  const TopNotificationToast({super.key, required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.up,
      onDismissed: (_) =>
          ref.read(notificationProvider.notifier).dismissToast(),
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () {
            ref.read(notificationProvider.notifier).dismissToast();
            _handleNotificationClick(context, ref, notification);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C).withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getNotificationColor(
                  notification,
                ).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        notification.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final color = _getNotificationColor(notification);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(_getNotificationIcon(notification), color: color, size: 20),
    );
  }

  Color _getNotificationColor(LudoNotification n) {
    switch (n.type) {
      case NotificationType.friendRequest:
        return AppColors.primaryCyan;
      case NotificationType.gameInvite:
        return AppColors.imperialAmber;
      case NotificationType.system:
        return AppColors.imperialJade;
    }
  }

  IconData _getNotificationIcon(LudoNotification n) {
    switch (n.type) {
      case NotificationType.friendRequest:
        return Icons.person_add_outlined;
      case NotificationType.gameInvite:
        return Icons.games_outlined;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  static void _handleNotificationClick(
    BuildContext context,
    WidgetRef ref,
    LudoNotification n,
  ) async {
    ref.read(notificationProvider.notifier).markAsRead(n.id);

    if (n.type == NotificationType.friendRequest) {
      AppDialogLayout.show(
        context: context,
        child: const FriendRequestsDialog(),
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
