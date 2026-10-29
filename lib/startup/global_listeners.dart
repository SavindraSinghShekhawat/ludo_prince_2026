import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/services/social_service.dart';
import 'package:ludo_prince/services/profile_service.dart';
import 'package:ludo_prince/services/remote_config_service.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/models/app_notification.dart';
import 'package:ludo_prince/providers/game_reminder_provider.dart';
import 'package:ludo_prince/services/game_reminder_sync_service.dart';
import 'package:ludo_prince/services/notification_service.dart';
import '../ui/dialogs/update_dialog.dart';

/// Sets up global listeners for invites, friend requests, and update checks.
class GlobalListeners {
  StreamSubscription? _inviteSubscription;
  StreamSubscription? _requestsSubscription;

  void init(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(gameReminderSyncServiceProvider).recordAppActivity();

    // Check for App Updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (remoteConfigService.updateStatus != UpdateStatus.none) {
        UpdateDialog.show(
          context,
          isForce: remoteConfigService.updateStatus == UpdateStatus.force,
          message: remoteConfigService.updateMessage,
          currentVersion: remoteConfigService.currentVersion,
          newVersion: remoteConfigService.latestVersion,
        );
      }
    });

    // Global listener for game invites
    _inviteSubscription = socialService.watchInvites().listen((event) {
      if (!context.mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final invites = Map<String, dynamic>.from(event.snapshot.value as Map);
        final container = ProviderScope.containerOf(context, listen: false);
        final reminderSettings = container.read(gameReminderProvider);

        if (!reminderSettings.gameInvitesEnabled) return;

        for (final entry in invites.entries) {
          final inviteId = entry.key;
          final data = Map<String, dynamic>.from(entry.value as Map);

          if (data['status'] == 'pending') {
            final fromName = data['fromName'] ?? 'Someone';
            final gameId = data['gameId'] ?? '';
            final joiningCode = data['joiningCode'] ?? '';

            final isNew = !container.read(notificationProvider).inbox.any(
                  (n) => n.id == inviteId,
                );

            container.read(notificationProvider.notifier).addNotification(
                  AppNotification(
                    id: inviteId,
                    type: NotificationType.gameInvite,
                    title: 'GAME INVITATION',
                    message: '$fromName invited you to play Ludo!',
                    data: {
                      'inviteId': inviteId,
                      'fromName': fromName,
                      'gameId': gameId,
                      'joiningCode': joiningCode,
                    },
                    timestamp: DateTime.now(),
                  ),
                );

            if (isNew) {
              notificationService.showImmediateNotification(
                id: inviteId.hashCode,
                title: '⚔️ Game Invitation',
                body: '$fromName invited you to play Ludo!',
                payload: 'game_invite|$inviteId|$fromName|$gameId|$joiningCode',
              );
            }
          }
        }
      }
    });

    // Global listener for friend requests
    _requestsSubscription = socialService.auth.authStateChanges().listen((
      user,
    ) {
      if (user != null) {
        profileService.getIncomingFriendRequests(user.uid).listen((reqs) {
          if (!context.mounted) return;
          final container = ProviderScope.containerOf(context, listen: false);
          final reminderSettings = container.read(gameReminderProvider);

          if (!reminderSettings.friendRequestsEnabled) return;

          for (final req in reqs) {
            final senderName = req.fromProfile?.displayName ?? 'Someone';
            final isNew = !container.read(notificationProvider).inbox.any(
                  (n) => n.id == req.id,
                );

            container.read(notificationProvider.notifier).addNotification(
                  AppNotification(
                    id: req.id,
                    type: NotificationType.friendRequest,
                    title: 'FRIEND REQUEST',
                    message: '$senderName wants to be your friend',
                    data: {'fromUid': req.fromUid},
                    timestamp: req.timestamp,
                  ),
                );

            if (isNew) {
              notificationService.showImmediateNotification(
                id: req.id.hashCode,
                title: '👑 Friend Request',
                body: '$senderName wants to be your friend!',
                payload: 'friend_request|${req.id}|$senderName',
              );
            }
          }
        });
      }
    });
  }

  void dispose() {
    _inviteSubscription?.cancel();
    _requestsSubscription?.cancel();
  }
}
