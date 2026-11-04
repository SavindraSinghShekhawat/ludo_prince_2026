import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_dialog_layout.dart';
import 'app_snackbar.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/models/app_notification.dart';
import 'package:ludo_prince/models/friend_request.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/services/notification_router.dart';
import 'package:ludo_prince/services/profile_service.dart';
import 'package:ludo_prince/services/social_service.dart';
import 'package:ludo_prince/ui/screens/lobby_screen.dart';
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
  final AppNotification notification;

  const TopNotificationToast({super.key, required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getNotificationColor(notification);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.up,
      onDismissed: (_) =>
          ref.read(notificationProvider.notifier).dismissToast(),
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () {
            final notifier = ref.read(notificationProvider.notifier);
            notifier.dismissToast();
            _handleNotificationClick(notifier, notification);
          },
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151B).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
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
                                const SizedBox(height: 2),
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
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white24,
                            size: 14,
                          ),
                        ],
                      ),
                      // Quick Inline Actions
                      if (notification.type == NotificationType.friendRequest) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildInlineButton(
                              label: 'DECLINE',
                              icon: Icons.close,
                              color: Colors.white60,
                              bgColor: Colors.white.withValues(alpha: 0.08),
                              borderColor: Colors.white.withValues(alpha: 0.15),
                              onTap: () async {
                                final notifier = ref.read(notificationProvider.notifier);
                                notifier.dismissToast();
                                try {
                                  await profileService.declineFriendRequest(notification.id);
                                  notifier.removeNotification(notification.id);
                                  final rootContext =
                                      NotificationRouter.navigatorKey.currentContext;
                                  if (rootContext != null && rootContext.mounted) {
                                    AppSnackBar.show(
                                      rootContext,
                                      message: 'Friend request declined.',
                                    );
                                  }
                                } catch (_) {}
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildInlineButton(
                              label: 'ACCEPT',
                              icon: Icons.check,
                              color: AppColors.imperialJade,
                              bgColor: AppColors.imperialJade.withValues(alpha: 0.15),
                              borderColor: AppColors.imperialJade.withValues(alpha: 0.4),
                              onTap: () async {
                                final notifier = ref.read(notificationProvider.notifier);
                                notifier.dismissToast();
                                final currentUser = Firebase.apps.isNotEmpty
                                    ? FirebaseAuth.instance.currentUser
                                    : null;
                                final req = FriendRequest(
                                  id: notification.id,
                                  fromUid: notification.data['fromUid'] ?? '',
                                  toUid: notification.data['toUid'] ??
                                      currentUser?.uid ??
                                      '',
                                  status: 'pending',
                                  timestamp: notification.timestamp,
                                );
                                try {
                                  await profileService.acceptFriendRequest(req);
                                  notifier.removeNotification(notification.id);
                                  final rootContext =
                                      NotificationRouter.navigatorKey.currentContext;
                                  if (rootContext != null && rootContext.mounted) {
                                    AppSnackBar.show(
                                      rootContext,
                                      message: 'Friend request accepted!',
                                      isSuccess: true,
                                    );
                                  }
                                } catch (e) {
                                  final rootContext =
                                      NotificationRouter.navigatorKey.currentContext;
                                  if (rootContext != null && rootContext.mounted) {
                                    AppSnackBar.show(
                                      rootContext,
                                      message: 'Failed to accept: $e',
                                      isError: true,
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ] else if (notification.type == NotificationType.gameInvite) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildInlineButton(
                              label: 'DECLINE',
                              icon: Icons.close,
                              color: Colors.white60,
                              bgColor: Colors.white.withValues(alpha: 0.08),
                              borderColor: Colors.white.withValues(alpha: 0.15),
                              onTap: () async {
                                final notifier = ref.read(notificationProvider.notifier);
                                notifier.dismissToast();
                                await socialService.respondToInvite(
                                  notification.id,
                                  false,
                                );
                                notifier.removeNotification(notification.id);
                                final rootContext =
                                    NotificationRouter.navigatorKey.currentContext;
                                  if (rootContext != null && rootContext.mounted) {
                                    AppSnackBar.show(
                                      rootContext,
                                      message: 'Game invite declined.',
                                    );
                                  }
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildInlineButton(
                              label: 'JOIN',
                              icon: Icons.play_arrow_rounded,
                              color: AppColors.imperialAmber,
                              bgColor: AppColors.imperialAmber.withValues(alpha: 0.18),
                              borderColor:
                                  AppColors.imperialAmber.withValues(alpha: 0.5),
                              onTap: () {
                                final notifier = ref.read(notificationProvider.notifier);
                                notifier.dismissToast();
                                _handleNotificationClick(notifier, notification);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ],
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

  static void _handleNotificationClick(
    NotificationNotifier notifier,
    AppNotification n,
  ) async {
    notifier.markAsRead(n.id);
    final rootContext = NotificationRouter.navigatorKey.currentContext;
    if (rootContext == null) return;

    if (n.type == NotificationType.friendRequest) {
      AppDialogLayout.show(
        context: rootContext,
        child: const FriendRequestsDialog(),
      );
    } else if (n.type == NotificationType.gameInvite) {
      AppDialogLayout.show(
        context: rootContext,
        barrierDismissible: false,
        child: InviteDialog(
          inviteId: n.id,
          fromName: n.data['fromName'] ?? 'Someone',
          gameId: n.data['gameId'] ?? '',
          joiningCode: n.data['joiningCode'] ?? '',
        ),
      );
    } else if (n.type == NotificationType.system) {
      Navigator.of(rootContext).push(
        ScaleFadePageRoute(
          page: const LobbyScreen(isQuickMatch: true),
          settings: const RouteSettings(name: '/lobby'),
        ),
      );
    }
  }
}
