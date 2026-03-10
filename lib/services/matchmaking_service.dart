import 'package:flutter/foundation.dart';
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

  Future<String> createGame(
      {required int maxPlayers,
      bool isPrivate = true,
      GameMode gameMode = GameMode.classic}) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;

    final gameRef = _db.ref().child('ludogames').push();
    final gameId = gameRef.key!;

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
        // We will store winners or stateSnapshot here if needed
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception("Failed to create game lobby.");
    }

    final playerRef = gameRef.child('players').child('slot1');
    await playerRef.set({
      'uid': user.uid,
      'name': user.displayName ??
          "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}",
      'missedTurns': 0,
      'connected': true,
      'joinedAt': ServerValue.timestamp,
      'lastSeen': ServerValue.timestamp,
      'status': 'active',
    });

    // Set up disconnect handler for the host
    playerRef.child('connected').onDisconnect().set(false);

    // Also disconnect handler for the entire game if host leaves during lobby phase
    // But since it's conditional on 'status' == 'lobby', we can't do that perfectly with onDisconnect.
    // However, we can hook it up so that when the host's connected status changes, the cloud function figures out if lobby needs deletion.

    return gameId;
  }

  Future<void> joinGame(String gameId) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;
    final gameRef = _db.ref().child('ludogames').child(gameId);

    final transactionResult = await gameRef.runTransaction((Object? gameData) {
      if (gameData == null) {
        return Transaction.abort();
      }

      Map<String, dynamic> game = Map<String, dynamic>.from(gameData as Map);
      final status = game['status'];
      final currentPlayers = game['currentPlayers'] as int;
      final maxPlayers = game['maxPlayers'] as int;

      if (status != 'lobby') return Transaction.abort();
      if (currentPlayers >= maxPlayers) return Transaction.abort();

      game['currentPlayers'] = currentPlayers + 1;
      return Transaction.success(game);
    });

    if (!transactionResult.committed) {
      throw Exception("Game is full, unavailable, or already started.");
    }

    // Determine available slot
    final playersSnap = await gameRef.child('players').get();
    final playersValue = playersSnap.value as Map<dynamic, dynamic>? ?? {};
    final usedSlots = playersValue.keys.cast<String>().toList();

    String? availableSlot;
    // We can extract maxPlayers from the snapshot
    final gameSnapshot =
        transactionResult.snapshot.value as Map<dynamic, dynamic>;
    final maxPlayers = gameSnapshot['maxPlayers'] as int;
    final slots = PlayerSlotExtension.getSlotsFor(maxPlayers);

    for (final slotEnum in slots) {
      final slot = slotEnum.name;
      if (!usedSlots.contains(slot)) {
        availableSlot = slot;
        break;
      }
    }

    if (availableSlot == null) {
      // Revert increment
      await gameRef.child('currentPlayers').set(ServerValue.increment(-1));
      throw Exception("No available slots");
    }

    final playerRef = gameRef.child('players').child(availableSlot);
    await playerRef.set({
      'uid': user.uid,
      'name': user.displayName ??
          "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}",
      'missedTurns': 0,
      'connected': true,
      'joinedAt': ServerValue.timestamp,
      'lastSeen': ServerValue.timestamp,
      'status': 'active',
    });

    playerRef.child('connected').onDisconnect().set(false);
  }

  Future<void> startGame(String gameId) async {
    await _db.ref().child('ludogames').child(gameId).update({
      'status': 'playing',
      'turnStartedAt': ServerValue.timestamp,
    }).timeout(const Duration(seconds: 10));
  }

  Future<String> joinQueue(int maxPlayers, GameMode gameMode) async {
    await _ensureAuthenticated();
    final uid = _auth.currentUser!.uid;

    final query = _db
        .ref()
        .child('ludogames')
        .orderByChild('status')
        .equalTo('lobby')
        .limitToFirst(20);

    final snapshot = await query.get();
    if (snapshot.exists) {
      final games = snapshot.value as Map<dynamic, dynamic>;
      for (var entry in games.entries) {
        final gameId = entry.key as String;
        final gameData = entry.value as Map<dynamic, dynamic>;

        if (gameData['isPrivate'] == true) continue;
        if (gameData['maxPlayers'] != maxPlayers) continue;
        if (gameData['gameMode'] != gameMode.name) continue;
        if (gameData['hostUid'] == uid) continue; // Don't join own lobby

        try {
          await joinGame(gameId);
          return gameId;
        } catch (e) {
          // If join fails, attempt the next one
        }
      }
    }

    // No active lobby found or join failed, create a new one
    return await createGame(
        maxPlayers: maxPlayers, isPrivate: false, gameMode: gameMode);
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
      debugPrint("Error deleting lobby $gameId: $e");
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
