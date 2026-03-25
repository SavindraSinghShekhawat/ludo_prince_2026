import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import '../utils/app_logger.dart';

class PresenceService {
  final FirebaseService _firebaseService = FirebaseService();

  void setPresence() {
    _firebaseService.auth.authStateChanges().listen((user) {
      if (user == null) {
        AppLogger.debug(
            "PresenceService: No user signed in, skipping presence set.");
        return;
      }

      AppLogger.debug("PresenceService: Setting presence for user ${user.uid}");
      final presenceRef = _firebaseService.database.ref("presence/${user.uid}");
      final connectedRef = _firebaseService.database.ref(".info/connected");

      connectedRef.onValue.listen((event) {
        final connected = event.snapshot.value == true;
        AppLogger.debug(
            "PresenceService: Realtime Database connected status: $connected");

        if (connected) {
          presenceRef.onDisconnect().set({
            "online": false,
            "lastSeen": ServerValue.timestamp,
          }).then((_) {
            AppLogger.debug(
                "PresenceService: onDisconnect set for ${user.uid}");
            presenceRef.set({
              "online": true,
              "lastSeen": ServerValue.timestamp,
            });
          });
        }
      });
    });
  }

  Stream<int> getOnlineCount() {
    return _firebaseService.database
        .ref("stats/onlineCount")
        .onValue
        .map((event) {
      return (event.snapshot.value as int?) ?? 0;
    });
  }
}

final presenceService = PresenceService();
