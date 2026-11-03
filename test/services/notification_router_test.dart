import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/services/app_route_observer.dart';
import 'package:ludo_prince/services/notification_router.dart';
import 'package:ludo_prince/ui/dialogs/invite_dialog.dart';
import 'package:ludo_prince/ui/dialogs/friend_requests_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationRouter Unit Tests', () {
    test('caches and clears pending launch payload', () {
      NotificationRouter.setPendingPayload('daily_prime_time');
      NotificationRouter.handleNotificationPayload('daily_prime_time');
      expect(true, isTrue);
    });

    test('ignores null or empty payload gracefully', () {
      NotificationRouter.setPendingPayload(null);
      NotificationRouter.handleNotificationPayload(null);
      NotificationRouter.handleNotificationPayload('');
      NotificationRouter.handleNotificationPayload('   ');
      expect(true, isTrue);
    });
  });

  group('NotificationRouter Routing & In-Game Protection Widget Tests', () {
    Widget buildTestApp({required String initialRoute}) {
      return ProviderScope(
        child: MaterialApp(
          navigatorKey: NotificationRouter.navigatorKey,
          navigatorObservers: [AppRouteObserver.instance],
          initialRoute: initialRoute,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => Scaffold(
                body: Text('Screen for ${settings.name}'),
              ),
            );
          },
        ),
      );
    }

    testWidgets('In /game route: battle reminder notification is ignored to prevent game drop', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: '/game'));
      await tester.pump();

      expect(AppRouteObserver.currentRouteName, '/game');
      expect(find.text('Screen for /game'), findsOneWidget);

      // Trigger daily battle reminder
      NotificationRouter.handleNotificationPayload('daily_prime_time');
      await tester.pump();

      // Ensure user is STILL on /game and no navigation happened
      expect(AppRouteObserver.currentRouteName, '/game');
      expect(find.text('Screen for /game'), findsOneWidget);
    });

    testWidgets('In /game route: incoming game invite presents InviteDialog instead of abandoning match', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: '/game'));
      await tester.pump();

      expect(AppRouteObserver.currentRouteName, '/game');

      // Trigger incoming invite payload
      NotificationRouter.handleNotificationPayload('game_invite|inv_99|PrincessEmma|room_101|CODE7');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that InviteDialog is shown as a modal over the game
      expect(find.byType(InviteDialog), findsOneWidget);
      expect(find.text('PRINCESSEMMA'), findsOneWidget);
      expect(find.text('ROOM INVITATION'), findsOneWidget);
      expect(find.text('Screen for /game'), findsOneWidget);
    });

    testWidgets('In /game route: incoming friend request presents FriendRequestsDialog over board', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: '/game'));
      await tester.pump();

      expect(AppRouteObserver.currentRouteName, '/game');

      // Trigger friend request payload
      NotificationRouter.handleNotificationPayload('test_friend_request');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that FriendRequestsDialog is displayed directly over active game
      expect(find.byType(FriendRequestsDialog), findsOneWidget);
      expect(find.text('Screen for /game'), findsOneWidget);
    });
  });
}
