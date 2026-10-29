import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ludo_prince/core/widgets/app_dialog_layout.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/ui/dialogs/invite_dialog.dart';
import 'package:ludo_prince/ui/screens/friends_screen.dart';
import 'package:ludo_prince/ui/screens/lobby_screen.dart';
import 'package:ludo_prince/utils/app_logger.dart';

/// Routes notification clicks (both local tray and background/cold launch) to their ideal destination screens.
class NotificationRouter {
  NotificationRouter._();

  /// Global navigator key attached to the root [MaterialApp].
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static String? _pendingPayload;

  /// Caches a payload when app is launched from terminated state, to be executed once navigator is ready.
  static void setPendingPayload(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      _pendingPayload = payload;
      AppLogger.debug('NotificationRouter: Pending payload set: $payload');
    }
  }

  /// Processes any cached payload once the initial UI frame has mounted.
  static void processPendingNotification() {
    if (_pendingPayload != null) {
      final payload = _pendingPayload;
      _pendingPayload = null;
      // Slight delay to ensure the widget tree and navigator transitions are stable
      Future.delayed(const Duration(milliseconds: 300), () {
        handleNotificationPayload(payload);
      });
    }
  }

  /// Handles incoming notification tap payloads and navigates to the respective screen/dialog.
  static void handleNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;

    final context = navigatorKey.currentContext;
    if (context == null) {
      AppLogger.debug(
        'NotificationRouter: Navigator context not available yet, queuing payload: $payload',
      );
      _pendingPayload = payload;
      return;
    }

    AppLogger.debug('NotificationRouter: Navigating for payload: $payload');

    try {
      if (payload == 'test_game_invite' || payload.startsWith('game_invite')) {
        _routeToGameInvite(context, payload);
      } else if (payload == 'test_friend_request' ||
          payload.startsWith('friend_request')) {
        _routeToFriendRequest(context);
      } else if (payload == 'daily_prime_time' ||
          payload == 'weekend_special' ||
          payload == 'inactivity_3d' ||
          payload == 'inactivity_7d' ||
          payload == 'test_battle_reminder' ||
          payload == 'test_notification') {
        _routeToBattleArena(context);
      } else {
        AppLogger.debug(
          'NotificationRouter: Unrecognized payload "$payload", defaulting to Battle Arena.',
        );
        _routeToBattleArena(context);
      }
    } catch (e, st) {
      AppLogger.error('NotificationRouter: Error routing notification: $e', st);
    }
  }

  /// Directs player to the Room Invitation dialog.
  static void _routeToGameInvite(BuildContext context, String payload) {
    String inviteId = 'test_invite';
    String fromName = 'PrinceAlex';
    String gameId = 'demo_game';
    String joiningCode = 'PRINCE7';

    if (payload.contains('|')) {
      final parts = payload.split('|');
      if (parts.length >= 5) {
        inviteId = parts[1];
        fromName = parts[2];
        gameId = parts[3];
        joiningCode = parts[4];
      }
    } else if (payload.contains('{')) {
      try {
        final jsonStr = payload.substring(payload.indexOf('{'));
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        inviteId = map['inviteId']?.toString() ?? inviteId;
        fromName = map['fromName']?.toString() ?? fromName;
        gameId = map['gameId']?.toString() ?? gameId;
        joiningCode = map['joiningCode']?.toString() ?? joiningCode;
      } catch (_) {}
    }

    AppDialogLayout.show(
      context: context,
      barrierDismissible: false,
      child: InviteDialog(
        inviteId: inviteId,
        fromName: fromName,
        gameId: gameId,
        joiningCode: joiningCode,
      ),
    );
  }

  /// Directs player to the Friends screen to manage friendships and pending requests.
  static void _routeToFriendRequest(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/friends') return;

    Navigator.of(context).push(
      SlideUpPageRoute(
        page: const FriendsScreen(),
        settings: const RouteSettings(name: '/friends'),
      ),
    );
  }

  /// Directs player straight into Battle Online (Matchmaking Arena) for daily/weekend/comeback calls.
  static void _routeToBattleArena(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/lobby') return;

    Navigator.of(context).push(
      ScaleFadePageRoute(
        page: const LobbyScreen(isQuickMatch: true),
        settings: const RouteSettings(name: '/lobby'),
      ),
    );
  }
}
