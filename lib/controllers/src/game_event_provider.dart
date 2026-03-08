import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ludo_controller.dart';
import '../../models/token.dart';

abstract class GameEventProvider {
  Stream<GameEvent> get events;
  void onRollRequested();
  void onMoveRequested(int tokenId);
  void onQuitRequested(PlayerSlot slot);
  void dispose();
}

/// A simplified event provider for local multiplayer.
/// In the future, this could be extended to handle Socket.io events.
class LocalEventProvider extends GameEventProvider {
  final _controller = StreamController<GameEvent>.broadcast();

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  void onRollRequested() {
    // Generate dice value here to ensure it's the source of truth
    final diceValue = LudoController.generateDiceValue();
    _controller.add(RollEvent(
      diceValue,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void onMoveRequested(int tokenId) {
    _controller.add(MoveEvent(
      tokenId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void onQuitRequested(PlayerSlot slot) {
    _controller.add(QuitEvent(
      slot,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void dispose() {
    _controller.close();
  }
}

sealed class GameEvent {
  final int timestamp;

  const GameEvent({required this.timestamp});

  Map<String, dynamic> toJson();

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    int timestamp = 0;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).millisecondsSinceEpoch;
    } else if (json['timestamp'] is int) {
      timestamp = json['timestamp'] as int;
    }

    if (type == 'roll') {
      return RollEvent(
        json['diceValue'] as int,
        timestamp: timestamp,
      );
    } else if (type == 'move') {
      return MoveEvent(
        json['tokenId'] as int,
        timestamp: timestamp,
      );
    } else if (type == 'quit') {
      return QuitEvent(
        PlayerSlot.values.firstWhere((e) => e.name == json['playerSlot']),
        timestamp: timestamp,
      );
    }
    throw Exception('Unknown GameEvent type: $type');
  }
}

class RollEvent extends GameEvent {
  final int diceValue;
  RollEvent(this.diceValue, {required int timestamp})
      : super(timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'roll',
        'diceValue': diceValue,
        'timestamp': timestamp,
      };
}

class MoveEvent extends GameEvent {
  final int tokenId;
  MoveEvent(this.tokenId, {required int timestamp})
      : super(timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'move',
        'tokenId': tokenId,
        'timestamp': timestamp,
      };
}

class QuitEvent extends GameEvent {
  final PlayerSlot playerSlot;
  QuitEvent(this.playerSlot, {required int timestamp})
      : super(timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'quit',
        'playerSlot': playerSlot.name,
        'timestamp': timestamp,
      };
}
