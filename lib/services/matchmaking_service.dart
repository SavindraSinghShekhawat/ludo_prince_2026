import 'dart:math';
import 'package:ludo_prince/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'firebase_service.dart';
import 'package:ludo_prince/core/constants/firebase_paths.dart';

class MatchmakingService {
  FirebaseDatabase get _db => firebaseService.database;
  FirebaseAuth get _auth => firebaseService.auth;

  Future<void> _ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously().timeout(const Duration(seconds: 10));
      } catch (e) {
        AppLogger.error("[MatchmakingService] Anonymous auth failed: $e");
        throw Exception("Unable to connect to game service. Please check your network connection.");
      }
    }
    if (_auth.currentUser == null) {
      throw Exception("User is not authenticated.");
    }
  }

  Future<String> createGame({
    required int maxPlayers,
    bool isPrivate = true,
    GameMode gameMode = GameMode.classic,
    String? playerName,
    String gameType = 'ludo',
  }) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;

    final gameRef = _db.ref().child(FirebasePaths.gameRoot(gameType)).push();
    final gameId = gameRef.key!;

    final effectiveName = playerName ??
        user.displayName ??
        "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}";

    String? joiningCode;
    if (isPrivate) {
      joiningCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
          .toString();
    }

    try {
      await gameRef.set({
        'status': 'lobby',
        'isPrivate': isPrivate,
        'joiningCode': joiningCode,
        'gameMode': gameMode.name,
        'createdAt': ServerValue.timestamp,
        'hostUid': user.uid,
        'maxPlayers': maxPlayers,
        'currentPlayers': 1,
        'hostLastActive': ServerValue.timestamp,
        'currentTurn': 'slot1',
        'turnNumber': 1,
        'turnStartedAt': ServerValue.timestamp,
        'eventCounter': 0,
        'settings': {'turnTimeSeconds': 15, 'maxSkips': 5},

        // IMPORTANT: create players atomically with game
        'players': {
          'slot1': {
            'uid': user.uid,
            'name': effectiveName,
            'skipCount': 0,
            'sixPity': 0,
            'connected': true,
            'joinedAt': ServerValue.timestamp,
            'lastActive': ServerValue.timestamp,
            'status': 'active',
            'tokens': [
              for (int i = 0; i < 4; i++)
                {'id': i, 'slot': 'slot1', 'position': 0, 'state': 'home'}
            ],
          },
        },
      }).timeout(const Duration(seconds: 10));

      if (isPrivate && joiningCode != null) {
        final codeRef = _db.ref().child(FirebasePaths.privateRoomCode(joiningCode));
        await codeRef.set({
          'gameId': gameId,
          'createdAt': ServerValue.timestamp,
        });
        // Auto-remove private code if host abruptly disconnects
        codeRef.onDisconnect().remove();
      }
    } catch (e) {
      throw Exception("Failed to create game lobby.");
    }

    // setup disconnect handler for host
    final playerRef = gameRef.child('players').child('slot1');
    playerRef.child('connected').onDisconnect().set(false);

    return gameId;
  }

  Future<void> joinGame(String gameId,
      {String? playerName, String gameType = 'ludo'}) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;
    final nameToUse = playerName ??
        user.displayName ??
        "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}";

    final gameRef = _db.ref().child(FirebasePaths.session(gameType, gameId));

    final transactionResult = await gameRef.runTransaction((Object? gameData) {
      if (gameData == null) {
        return Transaction.success(gameData);
      }

      final game = Map<String, dynamic>.from(gameData as Map);
      final status = game['status'];
      final currentPlayers = (game['currentPlayers'] ?? 0) as num;
      final maxPlayers = (game['maxPlayers'] ?? 0) as num;

      if (status != 'lobby') {
        return Transaction.abort(); // Cannot join a game in progress
      }

      final players = Map<String, dynamic>.from(game['players'] ?? {});

      // Check if user is already in the game (idempotency)
      for (final entry in players.entries) {
        final pData = Map<String, dynamic>.from(entry.value as Map);
        if (pData['uid'] == user.uid) {
          return Transaction.success(gameData);
        }
      }

      if (currentPlayers >= maxPlayers) {
        return Transaction.abort(); // Lobby is full
      }

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
        'name': nameToUse,
        'skipCount': 0,
        'missedTurns': 0,
        'sixPity': 0,
        'connected': true,
        'joinedAt': ServerValue.timestamp,
        'lastActive': ServerValue.timestamp,
        'status': 'active',
        'tokens': [
          for (int i = 0; i < 4; i++)
            {'id': i, 'slot': availableSlot, 'position': 0, 'state': 'home'}
        ],
      };

      game['players'] = players;
      game['currentPlayers'] = currentPlayers + 1;

      return Transaction.success(game);
    });

    if (!transactionResult.committed) {
      throw Exception("Lobby is full or game has already started.");
    }
  }

  Future<void> updateGameSettings(
    String gameId,
    int maxPlayers,
    GameMode gameMode, {
    String gameType = 'ludo',
  }) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;
    final gameRef = _db.ref().child(FirebasePaths.session(gameType, gameId));

    final snapshot = await gameRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (data['hostUid'] == user.uid) {
        await gameRef.update({
          'maxPlayers': maxPlayers,
          'gameMode': gameMode.name,
        });
      } else {
        throw Exception("Only the host can modify game settings.");
      }
    }
  }

  Future<void> startGame(String gameId, {String gameType = 'ludo'}) async {
    final gameRef = _db.ref().child(FirebasePaths.session(gameType, gameId));
    final gameSnap = await gameRef.get();

    if (!gameSnap.exists) {
      throw Exception("Game not found.");
    }

    final gameData = Map<String, dynamic>.from(gameSnap.value as Map);
    final joiningCode = gameData['joiningCode'];
    if (joiningCode != null) {
      await _db
          .ref()
          .child(FirebasePaths.privateRoomCode(joiningCode))
          .remove();
    }

    final rawPlayers = Map<String, dynamic>.from(gameData['players'] ?? {});
    final maxPlayers =
        (gameData['maxPlayers'] as num?)?.toInt() ?? rawPlayers.length;
    final gameModeStr = gameData['gameMode'] as String? ?? 'classic';

    // Establish turn order based on valid slots for this player count
    final orderedSlots = PlayerSlotExtension.getSlotsFor(maxPlayers);
    final turnOrder = <String>[];
    for (final slotEnum in orderedSlots) {
      if (rawPlayers.containsKey(slotEnum.name)) {
        turnOrder.add(slotEnum.name);
      }
    }
    // Fallback if some slots are custom
    if (turnOrder.isEmpty) {
      turnOrder.addAll(rawPlayers.keys);
    }

    final updates = <String, dynamic>{
      'status': 'playing',
      'currentTurn': turnOrder.first,
      'turnNumber': 1,
      'turnStartedAt': ServerValue.timestamp,
      'turnOrder': turnOrder,
      'isDiceRolled': false,
      'eventCounter': 0,
      'prefetchedSeed': Random.secure().nextInt(10000000),
    };

    // Guarantee all players have tokens, sixPity, skipCount, and team assignments
    for (final slot in rawPlayers.keys) {
      final pData = Map<String, dynamic>.from(rawPlayers[slot] as Map);
      if (pData['tokens'] == null) {
        updates['players/$slot/tokens'] = [
          for (int i = 0; i < 4; i++)
            {'id': i, 'slot': slot, 'position': 0, 'state': 'home'}
        ];
      }
      if (pData['sixPity'] == null) {
        updates['players/$slot/sixPity'] = 0;
      }
      if (pData['skipCount'] == null) {
        updates['players/$slot/skipCount'] = 0;
      }
      if (gameModeStr == 'team') {
        final isTeamA = (slot == 'slot1' || slot == 'slot3');
        updates['players/$slot/team'] = isTeamA ? 'A' : 'B';
      }
    }

    await gameRef.update(updates).timeout(const Duration(seconds: 10));
  }

  Future<String?> getGameIdFromCode(String code) async {
    try {
      final snapshot = await _db
          .ref()
          .child(FirebasePaths.privateRoomCode(code))
          .get()
          .timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data['gameId'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error("[MatchmakingService] getGameIdFromCode error: $e");
      return null;
    }
  }

  String _getModeQueueName(int maxPlayers, GameMode gameMode) {
    if (gameMode == GameMode.team) {
      return 'team_2v2';
    }
    return 'classic_${maxPlayers}p';
  }

  Future<Stream<String?>> joinQueue(
    int maxPlayers,
    GameMode gameMode, {
    String? playerName,
    String gameType = 'ludo',
  }) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;
    final uid = user.uid;
    final modeQueue = _getModeQueueName(maxPlayers, gameMode);

    final queueRef = _db
        .ref()
        .child(FirebasePaths.matchmakingSlot(gameType, modeQueue, uid));
    final assignmentRef =
        _db.ref().child(FirebasePaths.matchmakingAssignment(uid));

    // 1. Clear any old assignment
    await assignmentRef.remove();

    // 2. Join the queue
    final effectiveName = playerName ??
        user.displayName ??
        "Guest #${uid.substring(uid.length > 4 ? uid.length - 4 : 0).toUpperCase()}";

    await queueRef.set({
      'joinedAt': ServerValue.timestamp,
      'name': effectiveName,
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

  Future<void> leaveQueue(int maxPlayers, GameMode gameMode,
      {String gameType = 'ludo'}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return; // User was never authenticated, so could not be in a queue
      }
      final uid = user.uid;
      final modeQueue = _getModeQueueName(maxPlayers, gameMode);

      await _db
          .ref()
          .child(FirebasePaths.matchmakingSlot(gameType, modeQueue, uid))
          .remove()
          .timeout(const Duration(seconds: 5));
      await _db
          .ref()
          .child(FirebasePaths.matchmakingAssignment(uid))
          .remove()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      AppLogger.debug("[MatchmakingService] leaveQueue skipped/failed: $e");
    }
  }

  Future<void> updateHostHeartbeat(String gameId,
      {String gameType = 'ludo'}) async {
    try {
      await _db.ref().child(FirebasePaths.session(gameType, gameId)).update({
        'hostLastActive': ServerValue.timestamp,
      });
    } catch (e) {
      AppLogger.debug("[MatchmakingService] updateHostHeartbeat failed: $e");
    }
  }

  Future<void> deleteLobby(String gameId,
      {String? joiningCode, String gameType = 'ludo'}) async {
    try {
      if (joiningCode != null && joiningCode.isNotEmpty) {
        await _db
            .ref()
            .child(FirebasePaths.privateRoomCode(joiningCode))
            .remove();
      }
      await _db.ref().child(FirebasePaths.session(gameType, gameId)).remove();
    } catch (e) {
      AppLogger.error("Error deleting lobby $gameId: $e");
    }
  }

  /// Disband an active lobby as host:
  /// Marks room as 'disbanded' so guests can display a polite dialog and exit gracefully,
  /// immediately deletes the room code, and purges the session.
  Future<void> disbandLobby(String gameId,
      {String? joiningCode, String gameType = 'ludo'}) async {
    try {
      final updates = <String, dynamic>{
        '${FirebasePaths.session(gameType, gameId)}/status': 'disbanded',
      };
      if (joiningCode != null && joiningCode.isNotEmpty) {
        updates[FirebasePaths.privateRoomCode(joiningCode)] = null;
      }
      await _db.ref().update(updates);

      // Give guests 1.5s to receive the 'disbanded' event before full deletion
      Future.delayed(const Duration(milliseconds: 1500), () async {
        try {
          await _db.ref().child(FirebasePaths.session(gameType, gameId)).remove();
        } catch (_) {}
      });
    } catch (e) {
      AppLogger.error("[MatchmakingService] Error disbanding lobby $gameId: $e");
    }
  }

  /// Leave an active lobby as a guest:
  /// Atomically removes current player from the players list and decrements player count,
  /// freeing up the slot for others to join.
  Future<void> leaveLobby(String gameId, {String gameType = 'ludo'}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final gameRef = _db.ref().child(FirebasePaths.session(gameType, gameId));

      await gameRef.runTransaction((Object? gameData) {
        if (gameData == null) return Transaction.success(gameData);
        final game = Map<String, dynamic>.from(gameData as Map);
        final players = Map<String, dynamic>.from(game['players'] ?? {});

        String? userSlot;
        for (final entry in players.entries) {
          final p = Map<String, dynamic>.from(entry.value as Map);
          if (p['uid'] == user.uid) {
            userSlot = entry.key;
            break;
          }
        }

        if (userSlot != null) {
          players.remove(userSlot);
          game['players'] = players;
          final current = (game['currentPlayers'] ?? 1) as num;
          game['currentPlayers'] = (current - 1).clamp(0, 4);
        }

        return Transaction.success(game);
      });
    } catch (e) {
      AppLogger.error("[MatchmakingService] Error leaving lobby $gameId: $e");
    }
  }

  Stream<DatabaseEvent> watchGame(String gameId, {String gameType = 'ludo'}) {
    return _db.ref().child(FirebasePaths.session(gameType, gameId)).onValue;
  }

  Stream<DatabaseEvent> watchPlayers(String gameId,
      {String gameType = 'ludo'}) {
    return _db.ref().child(FirebasePaths.players(gameType, gameId)).onValue;
  }
}

final matchmakingService = MatchmakingService();
