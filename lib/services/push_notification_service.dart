import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ludo_prince/services/notification_router.dart';
import 'package:ludo_prince/utils/app_logger.dart';

/// Central service managing remote APNs / FCM push notifications for Ludo Prince.
/// Handles device token registration, foreground presentation options,
/// and background/cold launch routing when the app is shut down.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Request notification permissions (iOS & Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      AppLogger.info(
        'PushNotificationService: Permission status: ${settings.authorizationStatus}',
      );

      // 2. Set presentation options for foreground messages
      // We set alert to false because global_listeners renders our custom high-fidelity
      // in-app banner toast and updates the bell badge without duplicate OS banners.
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // 3. Sync device token with current authenticated user
      await _syncToken();

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });

      // Listen for auth state changes to re-sync token when switching accounts
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _syncToken();
        }
      });

      // 4. Handle notifications tapped while app was backgrounded
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info(
          'PushNotificationService: Notification tapped from background: ${message.data}',
        );
        _handleMessage(message);
      });

      // 5. Handle notifications that launched the app from terminated (cold start)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.info(
          'PushNotificationService: App launched from terminated push: ${initialMessage.data}',
        );
        _handleMessage(initialMessage);
      }

      _initialized = true;
      AppLogger.info('PushNotificationService: Initialized successfully');
    } catch (e) {
      AppLogger.error('PushNotificationService: Initialization failed: $e');
    }
  }

  Future<void> _syncToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      AppLogger.debug('PushNotificationService: Failed to get FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      AppLogger.debug('PushNotificationService: Synced FCM token for ${user.uid}');
    } catch (e) {
      AppLogger.error('PushNotificationService: Failed to save FCM token: $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final type = data['type'];
    if (type == 'gameInvite') {
      final payload = jsonEncode({
        'inviteId': data['inviteId'] ?? '',
        'fromName': data['fromName'] ?? 'Someone',
        'gameId': data['gameId'] ?? '',
        'joiningCode': data['joiningCode'] ?? '',
      });
      NotificationRouter.handleNotificationPayload(payload);
    } else if (type == 'friendRequest') {
      NotificationRouter.handleNotificationPayload('friend_request');
    }
  }

  Future<void> onSignOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }).catchError((_) {});
      }
    } catch (_) {}
  }
}

final pushNotificationService = PushNotificationService();
