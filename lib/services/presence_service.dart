import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import '../utils/app_logger.dart';

class PresenceService {
  final FirebaseService _firebaseService = FirebaseService();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;

  void setPresence() {
    // Basic leak prevention: cancel existing auth listener if this is called multiple times
    _authSubscription?.cancel();

    _authSubscription = _firebaseService.auth.authStateChanges().listen((user) {
      // CRITICAL: Cancel the database listener whenever auth state changes
      // to prevent permission-denied errors for the previous user's session.
      _connectedSubscription?.cancel();
      _connectedSubscription = null;

      if (user == null) {
        AppLogger.debug(
            "PresenceService: No user signed in, skipping presence set.");
        return;
      }

      AppLogger.debug(
          "PresenceService: Setting presence for ${user.isAnonymous ? 'GUEST' : 'USER'} ${user.uid}");
      final presenceRef = _firebaseService.database.ref("presence/${user.uid}");
      final connectedRef = _firebaseService.database.ref(".info/connected");

      _connectedSubscription = connectedRef.onValue.listen((event) {
        final connected = event.snapshot.value == true;
        AppLogger.debug(
            "PresenceService: Realtime Database status onValue: connected=$connected");

        if (connected) {
          AppLogger.debug(
              "PresenceService: User ${user.uid} is connected to RTDB. Setting up onDisconnect.");
          presenceRef.onDisconnect().update({
            "online": false,
            "lastActive": ServerValue.timestamp,
          }).then((_) {
            AppLogger.debug(
                "PresenceService: onDisconnect set for ${user.uid}");
            presenceRef.update({
              "online": true,
              "lastActive": ServerValue.timestamp,
            });
          });
        }
      });
    });
  }

  void dispose() {
    AppLogger.debug("PresenceService: Disposing and cancelling listeners.");
    _authSubscription?.cancel();
    _connectedSubscription?.cancel();
    _authSubscription = null;
    _connectedSubscription = null;
  }

  Stream<int> getOnlineCount() {
    return _firebaseService.auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(0);

      return _firebaseService.database
          .ref("stats/onlineCount")
          .onValue
          .map((event) {
        return (event.snapshot.value as num?)?.toInt() ?? 0;
      });
    });
  }
}

final presenceService = PresenceService();
