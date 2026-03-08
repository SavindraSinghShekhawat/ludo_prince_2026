import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state.dart';
import '../models/token.dart';
import '../engine/game_engine.dart';
import 'ludo_controller.dart';
import 'src/firebase_event_provider.dart';
import 'src/game_event_provider.dart';

class MultiplayerGameController extends LudoController {
  final String gameId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _lastAppliedEventId = 0;

  MultiplayerGameController(
    Map<PlayerSlot, PlayerSetupConfig> config, {
    required this.gameId,
    required PlayerSlot localPlayerSlot,
  }) : super(config,
            localPlayerSlot: localPlayerSlot,
            eventProvider: FirebaseEventProvider(gameId: gameId));

  Future<void> initializeFromSnapshot() async {
    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) return;

    final snapshot = data['stateSnapshot'];
    if (snapshot != null) {
      final gameStateJson = snapshot['gameState'] as Map<String, dynamic>;
      _lastAppliedEventId = snapshot['lastEventId'] as int;
      state = GameState.fromJson(gameStateJson);
    }

    // Fetch missing events
    final eventsQuery = await _firestore
        .collection('games')
        .doc(gameId)
        .collection('events')
        .where(FieldPath.documentId,
            isGreaterThan: _lastAppliedEventId.toString().padLeft(5, '0'))
        .orderBy(FieldPath.documentId)
        .get();

    for (var doc in eventsQuery.docs) {
      final event = GameEvent.fromJson(doc.data());
      await _applyEventLocally(event);
      _lastAppliedEventId = int.parse(doc.id);
    }

    if (!isDisposed) streamController.add(state);
  }

  Future<void> _applyEventLocally(GameEvent event) async {
    if (event is RollEvent) {
      await executeRoll(event.diceValue);
    } else if (event is MoveEvent) {
      await executeMove(event.tokenId);
    } else if (event is QuitEvent) {
      final engine = GameEngine();
      final result = engine.quitPlayer(state, event.playerSlot);
      state = result.state;
    }

    _checkSnapshotRequirement();
  }

  void _checkSnapshotRequirement() {
    if (_lastAppliedEventId > 0 && _lastAppliedEventId % 20 == 0) {
      _saveSnapshot();
    }
  }

  Future<void> _saveSnapshot() async {
    await _firestore.collection('games').doc(gameId).update({
      'stateSnapshot': {
        'gameState': state.toJson(),
        'lastEventId': _lastAppliedEventId,
      }
    });
  }

  @override
  void handleGameEvent(GameEvent event) {
    if (event is RollEvent) {
      _lastAppliedEventId++;
    } else if (event is MoveEvent) {
      _lastAppliedEventId++;
    }
    super.handleGameEvent(event);
    _checkSnapshotRequirement();
  }
}
