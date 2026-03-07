import 'dart:async';
import '../ludo_controller.dart';

abstract class GameEventProvider {
  Stream<GameEvent> get events;
  void onRollRequested();
  void onMoveRequested(int tokenId);
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
    _controller.add(RollEvent(diceValue));
  }

  @override
  void onMoveRequested(int tokenId) {
    _controller.add(MoveEvent(tokenId));
  }

  @override
  void dispose() {
    _controller.close();
  }
}

sealed class GameEvent {
  const GameEvent(); // Allow subclasses to have const constructors

  Map<String, dynamic> toJson();

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    if (type == 'roll') {
      return RollEvent(json['diceValue'] as int);
    } else if (type == 'move') {
      return MoveEvent(json['tokenId'] as int);
    }
    throw Exception('Unknown GameEvent type: $type');
  }
}

class RollEvent extends GameEvent {
  final int diceValue;
  RollEvent(this.diceValue);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'roll',
        'diceValue': diceValue,
      };
}

class MoveEvent extends GameEvent {
  final int tokenId;
  MoveEvent(this.tokenId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'move',
        'tokenId': tokenId,
      };
}
