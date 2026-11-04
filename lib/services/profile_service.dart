import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/friend_request.dart';
import 'package:ludo_prince/utils/app_logger.dart';

class ProfileService {
  final FirebaseFirestore? _customFirestore;
  ProfileService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// In-memory fast cache to prevent duplicate Firestore reads
  final Map<String, UserProfile> _profileCache = {};

  Future<UserProfile?> getUserProfile(
    String uid, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _profileCache.containsKey(uid)) {
      return _profileCache[uid];
    }
    try {
      if (_customFirestore == null && Firebase.apps.isEmpty) return null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final profile = UserProfile.fromFirestore(doc);
        _profileCache[uid] = profile;
        return profile;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching user profile: $e');
      return _profileCache[uid];
    }
  }

  /// Caches a profile into memory (e.g. from search, auth, or batch loads)
  void cacheProfile(UserProfile profile) {
    _profileCache[profile.uid] = profile;
  }

  Future<List<UserProfile>> getCachedFriends(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cached_friends_$uid');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        final cached = list
            .map((item) =>
                UserProfile.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        for (final p in cached) {
          _profileCache[p.uid] = p;
        }
        return cached;
      }
    } catch (e) {
      AppLogger.debug('Error reading cached friends: $e');
    }
    return [];
  }

  Future<void> saveCachedFriends(String uid, List<UserProfile> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = friends.map((f) => f.toMap()).toList();
      await prefs.setString('cached_friends_$uid', jsonEncode(list));
    } catch (e) {
      AppLogger.debug('Error saving cached friends: $e');
    }
  }

  Future<void> createOrUpdateProfile(UserProfile profile, {bool isCreate = false}) async {
    _profileCache[profile.uid] = profile;
    try {
      await _firestore
          .collection('users')
          .doc(profile.uid)
          .set(profile.toFirestore(isCreate: isCreate), SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Error updating user profile: $e');
    }
  }

  Future<void> deleteProfile(String uid) async {
    _profileCache.remove(uid);
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      AppLogger.error('Error deleting user profile: $e');
      rethrow;
    }
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    try {
      final List<UserProfile> results = [];

      // 1. Direct search if query matches exact UID
      try {
        final exactDoc =
            await _firestore.collection('users').doc(cleanQuery).get();
        if (exactDoc.exists) {
          final profile = UserProfile.fromFirestore(exactDoc);
          if (!profile.isAnonymous) {
            results.add(profile);
          }
        }
      } catch (_) {}

      // 2. Search by displayName prefix
      final snapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: cleanQuery)
          .where('displayName', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(20)
          .get();

      for (final doc in snapshot.docs) {
        if (!results.any((r) => r.uid == doc.id)) {
          final profile = UserProfile.fromFirestore(doc);
          // Never allow guest/anonymous accounts to appear in friend search results
          if (!profile.isAnonymous) {
            results.add(profile);
          }
        }
      }

      return results;
    } catch (e) {
      AppLogger.error('Error searching users: $e');
      return [];
    }
  }

  Future<void> updateLastActive(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error updating last active: $e');
    }
  }

  // --- Friends Logic Foundation ---

  static const int maxFriendsLimit = 50;

  Future<int> getFriendsCount(String uid) async {
    try {
      final countSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .count()
          .get();
      return countSnap.count ?? 0;
    } catch (_) {
      final cached = await getCachedFriends(uid);
      return cached.length;
    }
  }

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    // 1. Prevent guest accounts from sending friend requests
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      throw Exception('Guest accounts cannot send friend requests. Please link your account!');
    }

    // 2. Fetch all validation data concurrently in parallel for 6x faster round trip
    final results = await Future.wait([
      getUserProfile(toUid),
      getFriendsCount(fromUid),
      getFriendsCount(toUid),
      _firestore
          .collection('users')
          .doc(fromUid)
          .collection('friends')
          .doc(toUid)
          .get(),
      _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: toUid)
          .where('to', isEqualTo: fromUid)
          .where('status', isEqualTo: 'pending')
          .get(),
      _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: fromUid)
          .where('to', isEqualTo: toUid)
          .get(),
    ]);

    final targetProfile = results[0] as UserProfile?;
    final senderCount = results[1] as int;
    final targetCount = results[2] as int;
    final isFriendSnap = results[3] as DocumentSnapshot;
    final reverse = results[4] as QuerySnapshot;
    final existing = results[5] as QuerySnapshot;

    // 3. Prevent sending friend requests to guest accounts
    if (targetProfile != null && targetProfile.isAnonymous) {
      throw Exception('Cannot add guest accounts. This player must link their account first.');
    }

    if (senderCount >= maxFriendsLimit) {
      throw Exception(
        'You have reached the maximum limit of $maxFriendsLimit friends.',
      );
    }

    if (targetCount >= maxFriendsLimit) {
      throw Exception(
        'This player has reached their limit of $maxFriendsLimit friends.',
      );
    }

    // 4. Prevent duplicate if already friends
    if (isFriendSnap.exists) {
      throw Exception('You are already friends with this player!');
    }

    // 5. If target player already sent an incoming request, auto-accept immediately!
    if (reverse.docs.isNotEmpty) {
      final req = FriendRequest.fromFirestore(reverse.docs.first);
      await acceptFriendRequest(req);
      return;
    }

    // 6. Clean up any existing records between fromUid and toUid (e.g. previous declined requests)
    for (final doc in existing.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['status'] == 'pending') {
        return; // Request already pending
      }
      try {
        await doc.reference.delete();
      } catch (_) {}
    }

    // 7. Create the fresh pending friend request
    await _firestore.collection('friend_requests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Cancels an active pending friend request sent by the current player
  Future<void> cancelFriendRequest(String fromUid, String toUid) async {
    try {
      final snap = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: fromUid)
          .where('to', isEqualTo: toUid)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      AppLogger.error('Error canceling friend request: $e');
    }
  }

  /// Stream of active pending friend requests sent by the current player
  Stream<List<FriendRequest>> getOutgoingFriendRequests(String uid) {
    return _firestore
        .collection('friend_requests')
        .where('from', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromFirestore(doc))
            .toList());
  }

  Stream<List<FriendRequest>> getIncomingFriendRequests(String uid) {
    return _firestore
        .collection('friend_requests')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <FriendRequest>[];
      final requests = await Future.wait(
        snapshot.docs.map((doc) async {
          final fromUid = doc.data()['from'] as String? ?? '';
          final profile = await getUserProfile(fromUid) ??
              UserProfile(
                uid: fromUid,
                displayName: fromUid.length >= 4
                    ? 'Player ${fromUid.substring(0, 4)}'
                    : 'Player',
                createdAt: DateTime.now(),
              );
          return FriendRequest.fromFirestore(doc, fromProfile: profile);
        }),
      );
      // Filter out any requests originating from anonymous accounts
      return requests.where((r) => r.fromProfile?.isAnonymous != true).toList();
    });
  }

  Future<void> acceptFriendRequest(FriendRequest request) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      throw Exception(
        'Please link your account (Google/Apple) to accept friend requests.',
      );
    }

    final senderProfile = await getUserProfile(request.fromUid);
    if (senderProfile != null && senderProfile.isAnonymous) {
      throw Exception(
        'This request is from a guest account and cannot be accepted.',
      );
    }

    final myCount = await getFriendsCount(request.toUid);
    if (myCount >= maxFriendsLimit) {
      throw Exception(
        'You have reached the maximum limit of $maxFriendsLimit friends. Remove a friend to accept.',
      );
    }

    final senderCount = await getFriendsCount(request.fromUid);
    if (senderCount >= maxFriendsLimit) {
      throw Exception(
        'This player has reached their limit of $maxFriendsLimit friends.',
      );
    }

    try {
      // 1. Update friend request status to 'accepted'
      await _firestore.collection('friend_requests').doc(request.id).update({
        'status': 'accepted',
      });

      // 2. Optimistic client write to own friends subcollection
      // Permitted by firestore rules: request.auth.uid == userId
      if (request.toUid.isNotEmpty && request.fromUid.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(request.toUid)
            .collection('friends')
            .doc(request.fromUid)
            .set({
          'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      AppLogger.error('Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Checks if two users are currently friends
  Future<bool> isFriend(String currentUid, String otherUid) async {
    if (currentUid.isEmpty || otherUid.isEmpty) return false;
    final cached = await getCachedFriends(currentUid);
    if (cached.any((f) => f.uid == otherUid)) return true;

    try {
      if (_customFirestore == null && Firebase.apps.isEmpty) return false;
      final doc = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(otherUid)
          .get();
      return doc.exists;
    } catch (e) {
      AppLogger.error('Error checking isFriend: $e');
      return false;
    }
  }

  Future<void> removeFriend(String currentUid, String friendUid) async {
    try {
      // 1. Atomically delete mutual friendship documents on both accounts
      final batch = _firestore.batch();
      final ownDoc = _firestore
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid);
      final reciprocalDoc = _firestore
          .collection('users')
          .doc(friendUid)
          .collection('friends')
          .doc(currentUid);

      batch.delete(ownDoc);
      batch.delete(reciprocalDoc);
      await batch.commit();

      // 2. Update local cache for immediate UI reactivity
      final cached = await getCachedFriends(currentUid);
      final updated = cached.where((f) => f.uid != friendUid).toList();
      await saveCachedFriends(currentUid, updated);
    } catch (e) {
      AppLogger.error('Error removing friend: $e');
      rethrow;
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    try {
      // Deleting the document cleans up cloud data and allows players to send new invites
      await _firestore.collection('friend_requests').doc(requestId).delete();
    } catch (e) {
      AppLogger.error('Error declining friend request: $e');
    }
  }

  Stream<List<UserProfile>> getFriends(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        saveCachedFriends(uid, []);
        return <UserProfile>[];
      }
      final profiles = await Future.wait(
        snapshot.docs.map((doc) => getUserProfile(doc.id)),
      );
      final friends = profiles.whereType<UserProfile>().toList();
      saveCachedFriends(uid, friends);
      return friends;
    });
  }
}

final profileService = ProfileService();

final friendRequestsProvider =
    StreamProvider.family<List<FriendRequest>, String>((ref, uid) {
  return profileService.getIncomingFriendRequests(uid);
});

final outgoingFriendRequestsProvider =
    StreamProvider.family<List<FriendRequest>, String>((ref, uid) {
  return profileService.getOutgoingFriendRequests(uid);
});
