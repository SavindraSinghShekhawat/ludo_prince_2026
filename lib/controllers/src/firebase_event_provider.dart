import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../ludo_controller.dart';
import 'game_event_provider.dart';
import '../../services/firebase_service.dart';
import '../../models/token.dart';

class FirebaseEventProvider extends GameEventProvider {
  final String gameId;
  final FirebaseDatabase _db = firebaseService.database;
  final _controller = StreamController<GameEvent>.broadcast();
  StreamSubscription? _subscription;

  FirebaseEventProvider({required this.gameId});

  void startListening(String startAfterId) {
    if (_subscription != null) return;

    final eventsRef =
        _db.ref().child('ludogames').child(gameId).child('events');

    _subscription = eventsRef
        .orderByKey()
        .startAt(startAfterId)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.exists) {
        if (event.snapshot.key == startAfterId)
          return; // skip the one we started after

        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _controller.add(GameEvent.fromJson(data));
      }
    });
  }

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  Future<void> onRollRequested() async {
    final diceValue = LudoController.generateDiceValue();
    final gameRef = _db.ref().child('ludogames').child(gameId);

    await gameRef.runTransaction((Object? gameData) {
      if (gameData == null) return Transaction.success(gameData);

      Map<String, dynamic> game = Map<String, dynamic>.from(gameData as Map);
      final eventCounter = (game['eventCounter'] as int? ?? 0) + 1;
      final currentTurn = game['currentTurn'] as String;
      final turnNumber = game['turnNumber'] as int;

      final eventId = eventCounter.toString().padLeft(5, '0');

      if (game['events'] == null) {
        game['events'] = <String, dynamic>{};
      }
      game['events'][eventId] = {
        'type': 'roll',
        'playerSlot': currentTurn,
        'turnNumber': turnNumber,
        'diceValue': diceValue,
        'timestamp': ServerValue.timestamp,
      };

      game['eventCounter'] = eventCounter;
      // We aren't doing turn progression in the transaction, only event logging!
      // Actually turn progression happens in handleGameEvent locally.
      return Transaction.success(game);
    });
  }

  @override
  Future<void> onMoveRequested(int tokenId) async {
    final gameRef = _db.ref().child('ludogames').child(gameId);

    await gameRef.runTransaction((Object? gameData) {
      if (gameData == null) return Transaction.success(gameData);

      Map<String, dynamic> game = Map<String, dynamic>.from(gameData as Map);
      final eventCounter = (game['eventCounter'] as int? ?? 0) + 1;
      final currentTurn = game['currentTurn'] as String;
      final turnNumber = game['turnNumber'] as int;

      final eventId = eventCounter.toString().padLeft(5, '0');

      if (game['events'] == null) {
        game['events'] = <String, dynamic>{};
      }
      game['events'][eventId] = {
        'type': 'move',
        'playerSlot': currentTurn,
        'turnNumber': turnNumber,
        'tokenId': tokenId,
        'timestamp': ServerValue.timestamp,
      };

      game['eventCounter'] = eventCounter;
      return Transaction.success(game);
    });
  }

  @override
  Future<void> onQuitRequested(PlayerSlot slot) async {
    final gameRef = _db.ref().child('ludogames').child(gameId);

    await gameRef.runTransaction((Object? gameData) {
      if (gameData == null) return Transaction.success(gameData);

      Map<String, dynamic> game = Map<String, dynamic>.from(gameData as Map);
      final eventCounter = (game['eventCounter'] as int? ?? 0) + 1;
      final turnNumber = game['turnNumber'] as int;

      final eventId = eventCounter.toString().padLeft(5, '0');

      if (game['events'] == null) {
        game['events'] = <String, dynamic>{};
      }
      game['events'][eventId] = {
        'type': 'quit',
        'playerSlot': slot.name,
        'turnNumber': turnNumber,
        'timestamp': ServerValue.timestamp,
      };

      game['eventCounter'] = eventCounter;
      return Transaction.success(game);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
