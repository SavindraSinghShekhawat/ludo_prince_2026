import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/services/social_service.dart';
import 'package:ludo_prince/services/profile_service.dart';
import 'package:ludo_prince/services/remote_config_service.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/models/app_notification.dart';
import '../ui/dialogs/update_dialog.dart';

/// Sets up global listeners for invites, friend requests, and update checks.
class GlobalListeners {
  StreamSubscription? _inviteSubscription;
  StreamSubscription? _requestsSubscription;

  void init(BuildContext context) {
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
      if (event.snapshot.exists && event.snapshot.value != null) {
        final invites = Map<String, dynamic>.from(event.snapshot.value as Map);
        final container = ProviderScope.containerOf(context, listen: false);

        for (final entry in invites.entries) {
          final inviteId = entry.key;
          final data = Map<String, dynamic>.from(entry.value as Map);

          if (data['status'] == 'pending') {
            container.read(notificationProvider.notifier).addNotification(
                  AppNotification(
                    id: inviteId,
                    type: NotificationType.gameInvite,
                    title: 'GAME INVITATION',
                    message:
                        '${data['fromName'] ?? 'Someone'} invited you to play Ludo!',
                    data: {
                      'inviteId': inviteId,
                      'fromName': data['fromName'] ?? 'Someone',
                      'gameId': data['gameId'] ?? '',
                      'joiningCode': data['joiningCode'] ?? '',
                    },
                    timestamp: DateTime.now(),
                  ),
                );
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
          final container = ProviderScope.containerOf(context, listen: false);
          for (final req in reqs) {
            container.read(notificationProvider.notifier).addNotification(
                  AppNotification(
                    id: req.id,
                    type: NotificationType.friendRequest,
                    title: 'FRIEND REQUEST',
                    message:
                        '${req.fromProfile?.displayName ?? 'Someone'} wants to be your friend',
                    data: {'fromUid': req.fromUid},
                    timestamp: req.timestamp,
                  ),
                );
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
