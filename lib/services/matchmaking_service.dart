import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_state.dart';

class MatchmakingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateShortCode() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded O, 0, I, 1 for clarity
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(6, (index) {
      final charIndex = (random >> (index * 5)) % chars.length;
      return chars[charIndex];
    }).join();
  }

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

    // Generate a unique short code
    String? gameId;
    int attempts = 0;
    while (gameId == null && attempts < 5) {
      final code = _generateShortCode();
      final doc = await _firestore.collection('games').doc(code).get();
      if (!doc.exists) {
        gameId = code;
      }
      attempts++;
    }

    if (gameId == null)
      throw Exception("Failed to generate unique lobby code.");

    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      await gameRef.set({
        'status': 'lobby',
        'isPrivate': isPrivate,
        'gameMode': gameMode.name,
        'createdAt': FieldValue.serverTimestamp(),
        'hostUid': user.uid,
        'maxPlayers': maxPlayers,
        'playerCount': 1,
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
      final gameDoc =
          await transaction.get(_firestore.collection('games').doc(gameId));
      if (!gameDoc.exists) throw Exception("Game not found");

      final status = gameDoc.data()?['status'];
      if (status != 'lobby')
        throw Exception("Game already started or finished");

      final playerCount = gameDoc.data()?['playerCount'] as int;
      final maxPlayers = gameDoc.data()?['maxPlayers'] as int;

      if (playerCount >= maxPlayers) throw Exception("Game is full");

      final playersSnap = await _firestore
          .collection('games')
          .doc(gameId)
          .collection('players')
          .get();
      final usedSlots = playersSnap.docs.map((d) => d.id).toList();

      String? availableSlot;
      for (int i = 1; i <= 4; i++) {
        final slot = 'slot$i';
        if (!usedSlots.contains(slot)) {
          availableSlot = slot;
          break;
        }
      }

      if (availableSlot == null) throw Exception("No available slots");

      transaction.update(_firestore.collection('games').doc(gameId), {
        'playerCount': FieldValue.increment(1),
      });

      transaction.set(
          _firestore
              .collection('games')
              .doc(gameId)
              .collection('players')
              .doc(availableSlot),
          {
            'uid': user.uid,
            'name': user.displayName ??
                "Guest #${user.uid.substring(user.uid.length > 4 ? user.uid.length - 4 : 0).toUpperCase()}",
            'missedTurns': 0,
            'connected': true,
            'joinedAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
            'status': 'active',
          });
    }).timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception("Join game timed out. Are emulators running?");
    });
  }

  Future<void> startGame(String gameId) async {
    await _firestore.collection('games').doc(gameId).update({
      'status': 'playing',
      'turnStartedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception("Start game timed out.");
    });
  }

  Future<String> joinQueue(int maxPlayers, GameMode gameMode) async {
    await _ensureAuthenticated();

    // 1. Try to find an existing public game
    final publicGames = await _firestore
        .collection('games')
        .where('isPrivate', isEqualTo: false)
        .where('status', isEqualTo: 'lobby')
        .where('maxPlayers', isEqualTo: maxPlayers)
        .where('gameMode', isEqualTo: gameMode.name)
        .orderBy('createdAt', descending: false)
        .limit(10) // Get a few to try if one fails
        .get();

    for (var doc in publicGames.docs) {
      try {
        await joinGame(doc.id);
        return doc.id; // Success!
      } catch (e) {
        // Try the next one if this one filled up or failed
        continue;
      }
    }

    // 2. No suitable public game found, create a new one
    return await createGame(
        maxPlayers: maxPlayers, isPrivate: false, gameMode: gameMode);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPlayers(String gameId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .collection('players')
        .snapshots();
  }
}

final matchmakingService = MatchmakingService();
