import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/token.dart';

class MatchmakingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    final gameRef = _firestore.collection('ludogames').doc();
    final gameId = gameRef.id;

    try {
      await gameRef.set({
        'status': 'lobby',
        'isPrivate': isPrivate,
        'gameMode': gameMode.name,
        'createdAt': FieldValue.serverTimestamp(),
        'hostUid': user.uid,
        'maxPlayers': maxPlayers,
        'currentPlayers': 1,
        'hostLastSeen': FieldValue.serverTimestamp(),
        'currentTurn': 'slot1',
        'turnNumber': 1,
        'turnStartedAt': FieldValue.serverTimestamp(),
        'eventCounter': 0,
        'settings': {
          'turnTimeSeconds': 30,
          'maxMissedTurns': 5,
        },
        'winnerSlots': [],
        'stateSnapshot': null,
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception("Failed to create game lobby.");
    }

    await gameRef.collection('players').doc('slot1').set({
      'uid': user.uid,
      'name': user.displayName ??
          "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}",
      'missedTurns': 0,
      'connected': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    return gameId;
  }

  Future<void> joinGame(String gameId) async {
    await _ensureAuthenticated();
    final user = _auth.currentUser!;

    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('ludogames').doc(gameId);
      final gameDoc = await transaction.get(docRef);

      if (!gameDoc.exists) throw Exception("Game not found");

      final data = gameDoc.data()!;
      final status = data['status'];
      final currentPlayers = data['currentPlayers'] as int;
      final maxPlayers = data['maxPlayers'] as int;
      final hostLastSeen = data['hostLastSeen'] as Timestamp?;

      // 1. Verify conditions inside transaction
      if (status != 'lobby') throw Exception("Game already started");

      if (hostLastSeen != null) {
        final now = DateTime.now();
        if (now.difference(hostLastSeen.toDate()).inSeconds > 60) {
          throw Exception("Lobby host is inactive");
        }
      }

      if (currentPlayers >= maxPlayers) throw Exception("Game is full");

      // 2. Determine first available slot
      final playersSnap = await docRef.collection('players').get();
      final usedSlots = playersSnap.docs.map((d) => d.id).toList();

      String? availableSlot;
      final slots = PlayerSlotExtension.getSlotsFor(maxPlayers);
      for (final slotEnum in slots) {
        final slot = slotEnum.name;
        if (!usedSlots.contains(slot)) {
          availableSlot = slot;
          break;
        }
      }

      if (availableSlot == null) throw Exception("No available slots");

      // 3. Update lobby and create player doc
      transaction.update(docRef, {
        'currentPlayers': FieldValue.increment(1),
      });

      transaction.set(docRef.collection('players').doc(availableSlot), {
        'uid': user.uid,
        'name': user.displayName ??
            "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}",
        'missedTurns': 0,
        'connected': true,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    }).timeout(const Duration(seconds: 15));
  }

  Future<void> startGame(String gameId) async {
    await _firestore.collection('ludogames').doc(gameId).update({
      'status': 'playing',
      'turnStartedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
  }

  Future<String> joinQueue(int maxPlayers, GameMode gameMode) async {
    await _ensureAuthenticated();

    // 1. Search Active Lobby (Single Query)
    final sixtySecondsAgo =
        DateTime.now().subtract(const Duration(seconds: 60));

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final querySnapshot = await _firestore
        .collection('ludogames')
        .where('isPrivate', isEqualTo: false)
        .where('status', isEqualTo: 'lobby')
        .where('maxPlayers', isEqualTo: maxPlayers)
        .where('gameMode', isEqualTo: gameMode.name)
        .where('hostLastSeen',
            isGreaterThan: Timestamp.fromDate(sixtySecondsAgo))
        .where('hostUid', isNotEqualTo: uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final gameId = querySnapshot.docs.first.id;
      try {
        await joinGame(gameId);
        return gameId;
      } catch (e) {
        // If join fails (e.g. lobby filled up during transaction), proceed to create lobby
      }
    }

    // 2. No active lobby found or join failed, create a new one
    return await createGame(
        maxPlayers: maxPlayers, isPrivate: false, gameMode: gameMode);
  }

  Future<void> updateHostHeartbeat(String gameId) async {
    await _firestore.collection('ludogames').doc(gameId).update({
      'hostLastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteLobby(String gameId) async {
    try {
      final lobbyRef = _firestore.collection('ludogames').doc(gameId);
      final batch = _firestore.batch();

      // Delete all possible player slots (predictable IDs slot1-slot4)
      // This avoids a Firestore read to fetch the slots.
      for (int i = 1; i <= 4; i++) {
        batch.delete(lobbyRef.collection('players').doc('slot$i'));
      }

      // Delete the lobby document itself
      batch.delete(lobbyRef);

      await batch.commit();
    } catch (e) {
      debugPrint("Error deleting lobby $gameId: $e");
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String gameId) {
    return _firestore.collection('ludogames').doc(gameId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPlayers(String gameId) {
    return _firestore
        .collection('ludogames')
        .doc(gameId)
        .collection('players')
        .snapshots();
  }
}

final matchmakingService = MatchmakingService();
