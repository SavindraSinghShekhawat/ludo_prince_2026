import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ludo_controller.dart';
import 'game_event_provider.dart';
import '../../models/token.dart';

class FirebaseEventProvider extends GameEventProvider {
  final String gameId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _controller = StreamController<GameEvent>.broadcast();
  StreamSubscription? _subscription;

  FirebaseEventProvider({required this.gameId}) {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _subscription = _firestore
        .collection('games')
        .doc(gameId)
        .collection('events')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _controller.add(GameEvent.fromJson(data));
          }
        }
      }
    });
  }

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  Future<void> onRollRequested() async {
    final diceValue = LudoController.generateDiceValue();
    final gameRef = _firestore.collection('games').doc(gameId);

    await _firestore.runTransaction((transaction) async {
      final gameDoc = await transaction.get(gameRef);
      final eventCounter = (gameDoc.data()?['eventCounter'] as int? ?? 0) + 1;
      final currentTurn = gameDoc.data()?['currentTurn'] as String;
      final turnNumber = gameDoc.data()?['turnNumber'] as int;

      final eventId = eventCounter.toString().padLeft(5, '0');
      final eventRef = gameRef.collection('events').doc(eventId);

      transaction.set(eventRef, {
        'type': 'roll',
        'playerSlot': currentTurn,
        'turnNumber': turnNumber,
        'diceValue': diceValue,
        'timestamp': FieldValue.serverTimestamp(),
      });

      transaction.update(gameRef, {
        'eventCounter': eventCounter,
      });
    });
  }

  @override
  Future<void> onMoveRequested(int tokenId) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    await _firestore.runTransaction((transaction) async {
      final gameDoc = await transaction.get(gameRef);
      final eventCounter = (gameDoc.data()?['eventCounter'] as int? ?? 0) + 1;
      final currentTurn = gameDoc.data()?['currentTurn'] as String;
      final turnNumber = gameDoc.data()?['turnNumber'] as int;

      final eventId = eventCounter.toString().padLeft(5, '0');
      final eventRef = gameRef.collection('events').doc(eventId);

      transaction.set(eventRef, {
        'type': 'move',
        'playerSlot': currentTurn,
        'turnNumber': turnNumber,
        'tokenId': tokenId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      transaction.update(gameRef, {
        'eventCounter': eventCounter,
      });
    });
  }

  @override
  Future<void> onQuitRequested(PlayerSlot slot) async {
    final gameRef = _firestore.collection("games").doc(gameId);

    await _firestore.runTransaction((transaction) async {
      final gameDoc = await transaction.get(gameRef);
      final eventCounter = (gameDoc.data()?["eventCounter"] as int? ?? 0) + 1;
      final turnNumber = gameDoc.data()?["turnNumber"] as int;

      final eventId = eventCounter.toString().padLeft(5, "0");
      final eventRef = gameRef.collection("events").doc(eventId);

      transaction.set(eventRef, {
        "type": "quit",
        "playerSlot": slot.name,
        "turnNumber": turnNumber,
        "timestamp": FieldValue.serverTimestamp(),
      });

      transaction.update(gameRef, {
        "eventCounter": eventCounter,
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
