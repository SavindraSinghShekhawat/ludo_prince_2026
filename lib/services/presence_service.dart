import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';

class PresenceService {
  final FirebaseService _firebaseService = FirebaseService();

  void setPresence() {
    final user = _firebaseService.auth.currentUser;
    if (user == null) return;

    final presenceRef = _firebaseService.database.ref("presence/${user.uid}");

    final connectedRef = _firebaseService.database.ref(".info/connected");
    connectedRef.onValue.listen((event) {
      if (event.snapshot.value == true) {
        presenceRef.onDisconnect().set({
          "online": false,
          "lastSeen": ServerValue.timestamp,
        }).then((_) {
          presenceRef.set({
            "online": true,
            "lastSeen": ServerValue.timestamp,
          });
        });
      }
    });
  }

  Stream<bool> isUserOnline(String uid) {
    return _firebaseService.database
        .ref("presence/$uid/online")
        .onValue
        .map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }
}

final presenceService = PresenceService();
