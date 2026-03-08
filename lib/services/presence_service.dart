import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void setPresence() {
    final user = _auth.currentUser;
    if (user == null) return;

    final presenceRef = _database.ref("presence/${user.uid}");

    _database.ref(".info/connected").onValue.listen((event) {
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
    return _database.ref("presence/$uid/online").onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }
}

final presenceService = PresenceService();
