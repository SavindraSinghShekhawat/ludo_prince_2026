import 'dart:async';

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
    _controller.add(RollEvent());
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

sealed class GameEvent {}

class RollEvent extends GameEvent {}

class MoveEvent extends GameEvent {
  final int tokenId;
  MoveEvent(this.tokenId);
}
