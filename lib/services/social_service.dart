import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';

enum UserStatus { online, offline, inLobby, inGame }

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final FirebaseDatabase _database = firebaseService.database;
  final FirebaseAuth _auth = firebaseService.auth;

  /// Initialize presence tracking
  Future<void> init() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final presenceRef = _database.ref('presence/${user.uid}');
    final connectedRef = _database.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        // Set online presence
        presenceRef.set({
          'status': 'online',
          'lastActive': ServerValue.timestamp,
          'displayName': user.displayName ?? 'Guest',
        });

        // Cleanup on disconnect
        presenceRef.onDisconnect().set({
          'status': 'offline',
          'lastActive': ServerValue.timestamp,
        });
      }
    });
  }

  /// Update presence to a specific state
  Future<void> updatePresence(UserStatus status, {String? gameId}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database.ref('presence/${user.uid}').update({
      'status': status.name,
      'gameId': gameId,
      'lastActive': ServerValue.timestamp,
    });
  }

  /// Send an invitation to another user
  Future<void> sendInvite({
    required String targetUid,
    required String gameId,
    required String joiningCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final inviteRef = _database.ref('invites/$targetUid').push();
    await inviteRef.set({
      'fromUid': user.uid,
      'fromName': user.displayName ?? 'Guest',
      'gameId': gameId,
      'joiningCode': joiningCode,
      'timestamp': ServerValue.timestamp,
      'status': 'pending',
    });
  }

  /// Listen for incoming invites
  Stream<DatabaseEvent> watchInvites() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    // Return the whole collection stream for better management (deletes/updates)
    return _database.ref('invites/${user.uid}').onValue;
  }

  /// Accept/Decline/Clear an invite
  Future<void> respondToInvite(String inviteId, bool accepted) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (accepted) {
      await _database.ref('invites/${user.uid}/$inviteId').update({
        'status': 'accepted',
      });
    } else {
      await _database.ref('invites/${user.uid}/$inviteId').remove();
    }
  }

  /// Accept/Decline/Clear an invite
  Future<void> clearInvite(String inviteId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _database.ref('invites/${user.uid}/$inviteId').remove();
  }

  /// Get status of a user by UID
  Stream<Map<String, dynamic>> watchUserStatus(String uid) {
    return _database.ref('presence/$uid').onValue.map((event) {
      if (event.snapshot.value == null) return {'status': 'offline'};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }
}

final socialService = SocialService();
