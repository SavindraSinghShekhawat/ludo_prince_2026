import '../utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/game_state.dart';
import '../models/token.dart';
import 'firebase_service.dart';

class MatchmakingService {
  FirebaseDatabase get _db => firebaseService.database;
  FirebaseAuth get _auth => firebaseService.auth;

  Future<void> _ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously().timeout(const Duration(seconds: 10));
    }
  }

  Future<String> createGame({
    required int maxPlayers,
    bool isPrivate = true,
    GameMode gameMode = GameMode.classic,
  }) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;

    final gameRef = _db.ref().child('ludogames').push();
    final gameId = gameRef.key!;

    final playerName = user.displayName ??
        "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}";

    try {
      await gameRef.set({
        'status': 'lobby',
        'isPrivate': isPrivate,
        'gameMode': gameMode.name,
        'createdAt': ServerValue.timestamp,
        'hostUid': user.uid,
        'maxPlayers': maxPlayers,
        'currentPlayers': 1,
        'hostLastSeen': ServerValue.timestamp,
        'currentTurn': 'slot1',
        'turnNumber': 1,
        'turnStartedAt': ServerValue.timestamp,
        'eventCounter': 0,
        'settings': {
          'turnTimeSeconds': 10,
          'maxMissedTurns': 5,
        },

        // IMPORTANT: create players atomically with game
        'players': {
          'slot1': {
            'uid': user.uid,
            'name': playerName,
            'missedTurns': 0,
            'connected': true,
            'joinedAt': ServerValue.timestamp,
            'lastSeen': ServerValue.timestamp,
            'status': 'active',
          }
        }
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception("Failed to create game lobby.");
    }

    // setup disconnect handler for host
    final playerRef = gameRef.child('players').child('slot1');
    playerRef.child('connected').onDisconnect().set(false);

    return gameId;
  }

  Future<void> joinGame(String gameId) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;
    final gameRef = _db.ref().child('ludogames').child(gameId);

    final transactionResult = await gameRef.runTransaction((Object? gameData) {
      if (gameData == null) {
        AppLogger.debug("Retrying transaction: lobby not yet visible");
        return Transaction.success(gameData);
      }

      final game = Map<String, dynamic>.from(gameData as Map);

      final status = game['status'];
      final currentPlayers = (game['currentPlayers'] ?? 0) as num;
      final maxPlayers = (game['maxPlayers'] ?? 0) as num;

      if (status != 'lobby') return Transaction.abort();
      if (currentPlayers >= maxPlayers) return Transaction.abort();

      final players = Map<String, dynamic>.from(game['players'] ?? {});
      final slots = PlayerSlotExtension.getSlotsFor(maxPlayers.toInt());

      String? availableSlot;

      for (final slotEnum in slots) {
        final slot = slotEnum.name;
        if (!players.containsKey(slot)) {
          availableSlot = slot;
          break;
        }
      }

      if (availableSlot == null) return Transaction.abort();

      players[availableSlot] = {
        'uid': user.uid,
        'name': user.displayName ??
            "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}",
        'missedTurns': 0,
        'connected': true,
        'joinedAt': ServerValue.timestamp,
        'lastSeen': ServerValue.timestamp,
        'status': 'active',
      };

      game['players'] = players;
      game['currentPlayers'] = currentPlayers + 1;

      return Transaction.success(game);
    });

    if (!transactionResult.committed) {
      throw Exception("Game is full, unavailable, or already started.");
    }
  }

  Future<void> startGame(String gameId) async {
    await _db.ref().child('ludogames').child(gameId).update({
      'status': 'playing',
      'turnStartedAt': ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
  }

  String _getModeQueueName(int maxPlayers, GameMode gameMode) {
    if (gameMode == GameMode.team) {
      return 'team_2v2';
    }
    return 'classic_${maxPlayers}p';
  }

  Future<Stream<String?>> joinQueue(int maxPlayers, GameMode gameMode) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;
    final uid = user.uid;
    final modeQueue = _getModeQueueName(maxPlayers, gameMode);

    final queueRef = _db
        .ref()
        .child('matchmaking')
        .child(modeQueue)
        .child('queue')
        .child(uid);
    final assignmentRef = _db.ref().child('matchmakingAssignments').child(uid);

    // 1. Clear any old assignment
    await assignmentRef.remove();

    // 2. Join the queue
    final playerName = user.displayName ??
        "Guest #${uid.substring(uid.length > 4 ? uid.length - 4 : 0).toUpperCase()}";

    await queueRef.set({
      'joinedAt': ServerValue.timestamp,
      'name': playerName,
    });

    // 3. Setup disconnect handler to remove from queue if player goes offline
    await queueRef.onDisconnect().remove();

    // 4. Return a stream that listens for the assignment
    return assignmentRef.onValue.map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return data['gameId'] as String?;
      }
      return null;
    });
  }

  Future<void> leaveQueue(int maxPlayers, GameMode gameMode) async {
    await _ensureAuthenticated();
    final uid = _auth.currentUser!.uid;
    final modeQueue = _getModeQueueName(maxPlayers, gameMode);

    await _db
        .ref()
        .child('matchmaking')
        .child(modeQueue)
        .child('queue')
        .child(uid)
        .remove();
    await _db.ref().child('matchmakingAssignments').child(uid).remove();
  }

  Future<void> updateHostHeartbeat(String gameId) async {
    await _db.ref().child('ludogames').child(gameId).update({
      'hostLastSeen': ServerValue.timestamp,
    });
  }

  Future<void> deleteLobby(String gameId) async {
    try {
      await _db.ref().child('ludogames').child(gameId).remove();
    } catch (e) {
      AppLogger.error("Error deleting lobby $gameId: $e");
    }
  }

  Stream<DatabaseEvent> watchGame(String gameId) {
    return _db.ref().child('ludogames').child(gameId).onValue;
  }

  Stream<DatabaseEvent> watchPlayers(String gameId) {
    return _db.ref().child('ludogames').child(gameId).child('players').onValue;
  }
}

final matchmakingService = MatchmakingService();
