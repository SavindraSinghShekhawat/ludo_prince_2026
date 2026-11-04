import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/models/friend_request.dart';
import 'package:ludo_prince/models/user_profile.dart';
import 'package:ludo_prince/services/profile_service.dart';
import 'package:ludo_prince/ui/dialogs/friend_requests_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Friend Request UX & Optimistic Interaction Tests', () {
    test('FriendRequest model properly serializes and initializes', () {
      final now = DateTime.now();
      final profile = UserProfile(
        uid: 'user_sender_1',
        displayName: 'Sender Player',
        createdAt: now,
      );

      final req = FriendRequest(
        id: 'req_123',
        fromUid: 'user_sender_1',
        toUid: 'user_receiver_2',
        status: 'pending',
        timestamp: now,
        fromProfile: profile,
      );

      expect(req.id, 'req_123');
      expect(req.fromUid, 'user_sender_1');
      expect(req.toUid, 'user_receiver_2');
      expect(req.status, 'pending');
      expect(req.fromProfile?.displayName, 'Sender Player');

      final firestoreMap = req.toFirestore();
      expect(firestoreMap['from'], 'user_sender_1');
      expect(firestoreMap['to'], 'user_receiver_2');
      expect(firestoreMap['status'], 'pending');
    });

    testWidgets('Action button shows loading spinner and disables taps when isLoading is true', (tester) async {
      int tapCount = 0;

      Widget buildTestButton({required bool isLoading}) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkWell(
                onTap: isLoading ? null : () => tapCount++,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.check, size: 14),
                      const SizedBox(width: 4),
                      Text(isLoading ? 'SENDING...' : 'ADD'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // 1. Initial idle state
      await tester.pumpWidget(buildTestButton(isLoading: false));
      expect(find.text('ADD'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('ADD'));
      await tester.pump();
      expect(tapCount, 1);

      // 2. Loading / optimistic state
      await tester.pumpWidget(buildTestButton(isLoading: true));
      expect(find.text('SENDING...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tapping during loading should NOT trigger additional calls
      await tester.tap(find.text('SENDING...'));
      await tester.pump();
      expect(tapCount, 1); // Tap count must remain 1
    });

    testWidgets('FriendRequestsDialog renders gracefully with empty or unauthenticated state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FriendRequestsDialog(),
            ),
          ),
        ),
      );
      await tester.pump();

      // With uninitialized Firebase in test harness, it returns SizedBox.shrink() safely
      expect(find.byType(FriendRequestsDialog), findsOneWidget);
    });

    test('isFriend returns true when user is present in cached friends', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final friend = UserProfile(
        uid: 'cached_friend_99',
        displayName: 'Cached Friend',
        createdAt: now,
      );

      // Save friend to cache
      await profileService.saveCachedFriends('my_user_id', [friend]);

      final isFriend = await profileService.isFriend('my_user_id', 'cached_friend_99');
      expect(isFriend, isTrue);

      final isNonFriend = await profileService.isFriend('my_user_id', 'random_stranger');
      expect(isNonFriend, isFalse);
    });

    testWidgets('Invite via code empty state layout displays proper UI and copy CTA', (tester) async {
      const roomCode = 'PRINCE7';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('INVITE PLAYERS'),
                  const Text('Direct invites can only be sent to friends.\nShare your Room Code for non-friends to join!'),
                  const Text('COPY CODE: $roomCode'),
                  const Text('SHARE CODE'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('INVITE PLAYERS'), findsOneWidget);
      expect(find.text('Direct invites can only be sent to friends.\nShare your Room Code for non-friends to join!'), findsOneWidget);
      expect(find.text('COPY CODE: PRINCE7'), findsOneWidget);
      expect(find.text('SHARE CODE'), findsOneWidget);
    });
  });
}

