import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/friend_request.dart';
import 'package:ludo_prince/utils/app_logger.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    if (query.isEmpty) return [];
    try {
      // Simple search by displayName prefix (case-sensitive in Firestore)
      final snapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
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
    final senderCount = await getFriendsCount(fromUid);
    if (senderCount >= maxFriendsLimit) {
      throw Exception(
        'You have reached the maximum limit of $maxFriendsLimit friends.',
      );
    }

    final targetCount = await getFriendsCount(toUid);
    if (targetCount >= maxFriendsLimit) {
      throw Exception(
        'This player has reached their limit of $maxFriendsLimit friends.',
      );
    }

    // Check if request already exists
    final existing = await _firestore
        .collection('friend_requests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return;

    await _firestore.collection('friend_requests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
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
      return requests;
    });
  }

  Future<void> acceptFriendRequest(FriendRequest request) async {
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

  Future<void> removeFriend(String currentUid, String friendUid) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .delete();

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
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'declined',
      });
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
