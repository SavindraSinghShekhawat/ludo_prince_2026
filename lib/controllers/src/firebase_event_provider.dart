import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'game_event_provider.dart';
import '../ludo_controller.dart';

class FirebaseEventProvider extends GameEventProvider {
  final String gameId;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final _controller = StreamController<GameEvent>.broadcast();
  late StreamSubscription _subscription;
  final int _startTime;

  FirebaseEventProvider(this.gameId)
      : _startTime = DateTime.now().millisecondsSinceEpoch {
    // Listen for new actions added after the provider was created
    _subscription = _db
        .ref('games/$gameId/actions')
        .orderByChild('timestamp')
        .startAt(_startTime)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        try {
          final gameEvent = GameEvent.fromJson(data);
          _controller.add(gameEvent);
        } catch (e) {
          print("Error parsing game event: $e");
        }
      }
    });
  }

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  void onRollRequested() {
    final diceValue = LudoController.generateDiceValue();
    final event = RollEvent(
      diceValue,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _db.ref('games/$gameId/actions').push().set(event.toJson());
  }

  @override
  void onMoveRequested(int tokenId) {
    final event = MoveEvent(
      tokenId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _db.ref('games/$gameId/actions').push().set(event.toJson());
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
