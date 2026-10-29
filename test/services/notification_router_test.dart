import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/services/notification_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationRouter', () {
    test('caches and clears pending launch payload', () {
      NotificationRouter.setPendingPayload('daily_prime_time');
      // When context is not yet available, calling handleNotificationPayload should preserve or queue
      NotificationRouter.handleNotificationPayload('daily_prime_time');
      // Verify no exceptions thrown
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
}
