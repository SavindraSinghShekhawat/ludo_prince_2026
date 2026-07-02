import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'game_event_provider.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/core/constants/firebase_paths.dart';

class FirebaseEventProvider extends GameEventProvider {
  final String gameId;
  final String gameType;
  final FirebaseDatabase _db = firebaseService.database;
  final _controller = StreamController<GameEvent>.broadcast();
  StreamSubscription? _subscription;

  FirebaseEventProvider({required this.gameId, this.gameType = 'ludo'});

  void startListening(String startAfterId) {
    if (_subscription != null) return;

    final eventsRef = _db.ref().child(FirebasePaths.events(gameType, gameId));

    _subscription = eventsRef
        .orderByKey()
        .startAt(startAfterId)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.exists) {
        if (event.snapshot.key == startAfterId) {
          return; // skip the one we started after
        }

        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _controller.add(GameEvent.fromJson(data));
      }
    });
  }

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  Future<void> onRollRequested({int? diceValue}) async {
    final uid = firebaseService.auth.currentUser!.uid;

    await _db
        .ref()
        .child(FirebasePaths.session(gameType, gameId))
        .child('actionRequests')
        .child(uid)
        .set({'type': 'roll', 'timestamp': ServerValue.timestamp});
  }

  @override
  Future<void> onMoveRequested(int tokenId) async {
    final uid = firebaseService.auth.currentUser!.uid;

    await _db
        .ref()
        .child(FirebasePaths.session(gameType, gameId))
        .child('actionRequests')
        .child(uid)
        .set({
      'type': 'move',
      'tokenId': tokenId,
      'timestamp': ServerValue.timestamp,
    });
  }

  @override
  Future<void> onQuitRequested(PlayerSlot slot) async {
    final uid = firebaseService.auth.currentUser!.uid;

    await _db
        .ref()
        .child(FirebasePaths.session(gameType, gameId))
        .child('actionRequests')
        .child(uid)
        .set({'type': 'quit', 'timestamp': ServerValue.timestamp});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
