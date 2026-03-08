import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentGameId;

  /// Starts tracking presence for a specific game
  void startTracking(String gameId) {
    _currentGameId = gameId;
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final presenceRef = _db.ref('games/$gameId/presence/$uid');
    final connectedRef = _db.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        presenceRef.onDisconnect().set(ServerValue.timestamp).then((_) {
          presenceRef.set(true);
        });
      }
    });
  }

  /// Stops tracking presence
  void stopTracking() {
    if (_currentGameId == null) return;
    final String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      _db.ref('games/$_currentGameId/presence/$uid').remove();
    }
    _currentGameId = null;
  }
}

final presenceService = PresenceService();
