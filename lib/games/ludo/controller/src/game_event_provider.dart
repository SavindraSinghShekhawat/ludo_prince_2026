import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';

abstract class GameEventProvider {
  Stream<GameEvent> get events;
  void onRollRequested({int? diceValue});
  void onMoveRequested(int tokenId);
  void onSkipRequested();
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
  void onRollRequested({int? diceValue}) {
    // Generate dice value here to ensure it's the source of truth
    final dice = diceValue ?? LudoController.generateDiceValue();
    _controller.add(
      RollEvent(dice, timestamp: DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  void onMoveRequested(int tokenId) {
    _controller.add(
      MoveEvent(tokenId, timestamp: DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  void onSkipRequested() {
    _controller.add(
      SkipEvent(PlayerSlot.slot1, timestamp: DateTime.now().millisecondsSinceEpoch), // slot doesn't matter for local stub
    );
  }

  @override
  void onQuitRequested(PlayerSlot slot) {
    _controller.add(
      QuitEvent(slot, timestamp: DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}

sealed class GameEvent {
  final int timestamp;
  final String? id;

  const GameEvent({required this.timestamp, this.id});

  Map<String, dynamic> toJson();

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    int timestamp = 0;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).millisecondsSinceEpoch;
    } else if (json['timestamp'] is int) {
      timestamp = json['timestamp'] as int;
    }

    final String? eventId = json['id'] as String?;
    final String? playerSlotStr = json['playerSlot'] as String?;
    final PlayerSlot? slot = playerSlotStr != null
        ? PlayerSlot.values.where((e) => e.name == playerSlotStr).firstOrNull
        : null;

    if (type == 'roll') {
      return RollEvent(
        json['diceValue'] as int,
        timestamp: timestamp,
        playerSlot: slot,
        id: eventId,
      );
    } else if (type == 'move') {
      return MoveEvent(
        json['tokenId'] as int,
        timestamp: timestamp,
        autoMove: json['autoMove'] as bool? ?? false,
        playerSlot: slot,
        id: eventId,
      );
    } else if (type == 'quit') {
      return QuitEvent(
        slot ?? PlayerSlot.values.firstWhere((e) => e.name == json['playerSlot']),
        timestamp: timestamp,
        id: eventId,
      );
    } else if (type == 'skip') {
      return SkipEvent(
        slot ?? PlayerSlot.values.firstWhere((e) => e.name == json['playerSlot']),
        timestamp: timestamp,
        isTimeout: json['isTimeout'] as bool? ?? false,
        id: eventId,
      );
    }
    throw Exception('Unknown GameEvent type: $type');
  }
}

class RollEvent extends GameEvent {
  final int diceValue;
  final PlayerSlot? playerSlot;
  RollEvent(this.diceValue, {required super.timestamp, this.playerSlot, super.id});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'roll',
        'diceValue': diceValue,
        'timestamp': timestamp,
        if (playerSlot != null) 'playerSlot': playerSlot!.name,
        if (id != null) 'id': id,
      };
}

class MoveEvent extends GameEvent {
  final int tokenId;
  final bool autoMove;
  final PlayerSlot? playerSlot;
  MoveEvent(
    this.tokenId, {
    required super.timestamp,
    this.autoMove = false,
    this.playerSlot,
    super.id,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'move',
        'tokenId': tokenId,
        'timestamp': timestamp,
        'autoMove': autoMove,
        if (playerSlot != null) 'playerSlot': playerSlot!.name,
        if (id != null) 'id': id,
      };
}

class QuitEvent extends GameEvent {
  final PlayerSlot playerSlot;
  QuitEvent(this.playerSlot, {required super.timestamp, super.id});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'quit',
        'playerSlot': playerSlot.name,
        'timestamp': timestamp,
        if (id != null) 'id': id,
      };
}

class SkipEvent extends GameEvent {
  final PlayerSlot playerSlot;
  final bool isTimeout;
  SkipEvent(
    this.playerSlot, {
    required super.timestamp,
    this.isTimeout = false,
    super.id,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'skip',
        'playerSlot': playerSlot.name,
        'timestamp': timestamp,
        'isTimeout': isTimeout,
        if (id != null) 'id': id,
      };
}
