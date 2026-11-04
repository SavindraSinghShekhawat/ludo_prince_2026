import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import 'profile_service.dart';
import 'package:ludo_prince/utils/app_logger.dart';

enum UserStatus { online, offline, inLobby, inGame }

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  FirebaseDatabase? get _database =>
      firebaseService.isInitialized ? firebaseService.database : null;
  FirebaseAuth? get _auth =>
      firebaseService.isInitialized ? firebaseService.auth : null;
  FirebaseAuth? get auth => _auth;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;

  /// Initialize presence tracking
  Future<void> init() async {
    _connectedSubscription?.cancel();
    _connectedSubscription = null;

    final user = _auth?.currentUser;
    final db = _database;
    if (user == null || db == null) return;

    AppLogger.debug(
      "SocialService: Initializing presence for ${user.isAnonymous ? 'GUEST' : 'USER'} ${user.uid}",
    );
    final presenceRef = db.ref('presence/${user.uid}');
    final connectedRef = db.ref('.info/connected');

    _connectedSubscription = connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        // Set online presence
        presenceRef.update({
          'online': true,
          'lastActive': ServerValue.timestamp,
          'displayName': user.displayName ?? 'Guest',
        });

        // Cleanup on disconnect
        presenceRef.onDisconnect().update({
          'online': false,
          'lastActive': ServerValue.timestamp,
        });
      }
    });
  }

  /// Stop all listeners
  void dispose() {
    _connectedSubscription?.cancel();
    _connectedSubscription = null;
  }

  /// Update presence to a specific state
  Future<void> updatePresence(UserStatus status, {String? gameId}) async {
    final user = _auth?.currentUser;
    final db = _database;
    if (user == null || db == null) return;

    await db.ref('presence/${user.uid}').update({
      'online': status != UserStatus.offline,
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
    final user = _auth?.currentUser;
    final db = _database;
    if (user == null || db == null) return;

    // Strict friendship rule: in-game match invites can only be sent to confirmed friends
    final isFriend = await profileService.isFriend(user.uid, targetUid);
    if (!isFriend) {
      throw Exception(
        'Direct game invites can only be sent to friends. Share your room code to play with others.',
      );
    }

    final inviteRef = db.ref('invites/$targetUid').push();
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
    final authInstance = _auth;
    final db = _database;
    if (authInstance == null || db == null) return const Stream.empty();

    return authInstance.authStateChanges().asyncExpand((user) {
      if (user == null) return const Stream.empty();
      // Return the whole collection stream for better management (deletes/updates)
      return db.ref('invites/${user.uid}').onValue;
    });
  }

  /// Accept/Decline/Clear an invite.
  /// Removes the invite from RTDB immediately upon resolution to prevent stale data accumulation.
  Future<void> respondToInvite(String inviteId, bool accepted) async {
    final user = _auth?.currentUser;
    final db = _database;
    if (user == null || db == null) return;

    // Remove immediately to prevent stale invite buildup
    await db.ref('invites/${user.uid}/$inviteId').remove();
  }

  /// Clear an invite
  Future<void> clearInvite(String inviteId) async {
    final user = _auth?.currentUser;
    final db = _database;
    if (user == null || db == null) return;
    await db.ref('invites/${user.uid}/$inviteId').remove();
  }

  /// Purge all expired invites (> 10 minutes old or accepted) for the current user
  Future<void> cleanStaleInvites() async {
    final user = _auth?.currentUser;
    final db = _database;
    if (user == null || db == null) return;
    try {
      final snap = await db.ref('invites/${user.uid}').get();
      if (!snap.exists || snap.value == null) return;
      final map = Map<String, dynamic>.from(snap.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in map.entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final timestamp = data['timestamp'];
        if (data['status'] == 'accepted' ||
            (timestamp is num && (now - timestamp.toInt()) > 600000)) {
          await db
              .ref('invites/${user.uid}/${entry.key}')
              .remove()
              .catchError((_) {});
        }
      }
    } catch (_) {}
  }

  /// Get status of a user by UID
  Stream<Map<String, dynamic>> watchUserStatus(String uid) {
    final authInstance = _auth;
    final db = _database;
    if (authInstance == null || db == null) {
      return Stream.value({'status': 'offline'});
    }
    return authInstance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value({'status': 'offline'});
      return db.ref('presence/$uid').onValue.map((event) {
        if (event.snapshot.value == null) return {'status': 'offline'};
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      });
    });
  }
}

final socialService = SocialService();
