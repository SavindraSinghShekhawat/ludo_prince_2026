import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/core/widgets/app_notification_host.dart';
import 'package:ludo_prince/models/app_notification.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/services/notification_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TopNotificationToast Widget & Quick Action Tests', () {
    testWidgets('Renders game invite notification with DECLINE and JOIN inline buttons', (tester) async {
      final inviteNotification = AppNotification(
        id: 'invite_101',
        title: 'Room Invitation',
        message: 'Alex invited you to a game',
        type: NotificationType.gameInvite,
        timestamp: DateTime.now(),
        data: {
          'fromName': 'Alex',
          'gameId': 'room_101',
          'joiningCode': 'CODE1',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: NotificationRouter.navigatorKey,
            home: Scaffold(
              body: TopNotificationToast(notification: inviteNotification),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Room Invitation'), findsOneWidget);
      expect(find.text('Alex invited you to a game'), findsOneWidget);
      expect(find.text('DECLINE'), findsOneWidget);
      expect(find.text('JOIN'), findsOneWidget);
    });

    testWidgets('Renders friend request notification with DECLINE and ACCEPT inline buttons', (tester) async {
      final friendNotification = AppNotification(
        id: 'friend_req_202',
        title: 'Friend Request',
        message: 'Sarah wants to be friends',
        type: NotificationType.friendRequest,
        timestamp: DateTime.now(),
        data: {
          'fromUid': 'user_sarah',
          'fromName': 'Sarah',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: NotificationRouter.navigatorKey,
            home: Scaffold(
              body: TopNotificationToast(notification: friendNotification),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Friend Request'), findsOneWidget);
      expect(find.text('Sarah wants to be friends'), findsOneWidget);
      expect(find.text('DECLINE'), findsOneWidget);
      expect(find.text('ACCEPT'), findsOneWidget);
    });

    testWidgets('Tapping DECLINE on game invite dismisses toast immediately', (tester) async {
      final inviteNotification = AppNotification(
        id: 'invite_303',
        title: 'Room Invitation',
        message: 'Leo invited you to play',
        type: NotificationType.gameInvite,
        timestamp: DateTime.now(),
        data: {'gameId': 'room_303'},
      );

      final container = ProviderContainer();
      // Add notification to provider state
      container.read(notificationProvider.notifier).addNotification(inviteNotification);
      expect(container.read(notificationProvider).activeToast?.id, 'invite_303');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: NotificationRouter.navigatorKey,
            home: Scaffold(
              body: TopNotificationToast(notification: inviteNotification),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the DECLINE button
      await tester.tap(find.text('DECLINE'));
      await tester.pump();
      // Let AppSnackBar's 3-second auto-dismiss timer complete
      await tester.pump(const Duration(milliseconds: 3200));

      // Ensure activeToast is cleared and notification is purged from inbox
      expect(container.read(notificationProvider).activeToast, isNull);
      expect(
        container.read(notificationProvider).inbox.any((n) => n.id == 'invite_303'),
        isFalse,
      );
    });
  });
}
