import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/friend_request.dart';
import '../utils/app_logger.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching user profile: $e');
      return null;
    }
  }

  Future<void> createOrUpdateProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(profile.uid)
          .set(profile.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Error updating user profile: $e');
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

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
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
          List<FriendRequest> requests = [];
          for (var doc in snapshot.docs) {
            final fromUid = doc.data()['from'];
            final profile = await getUserProfile(fromUid);
            requests.add(
              FriendRequest.fromFirestore(doc, fromProfile: profile),
            );
          }
          return requests;
        });
  }

  Future<void> acceptFriendRequest(FriendRequest request) async {
    try {
      // We only update the status to 'accepted'.
      // A Cloud Function trigger will handle the necessary side effects:
      // 1. Adding both users to each other's friends subcollections.
      // 2. Incrementing friendsCount for both users.
      // This solves the permission-denied issues with cross-user writes.
      await _firestore.collection('friend_requests').doc(request.id).update({
        'status': 'accepted',
      });
    } catch (e) {
      AppLogger.error('Error accepting friend request: $e');
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
    // This would ideally use a 'friends' subcollection or array of UIDs
    // For now, let's keep it simple as a foundation.
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
          List<UserProfile> friends = [];
          for (var doc in snapshot.docs) {
            final profile = await getUserProfile(doc.id);
            if (profile != null) friends.add(profile);
          }
          return friends;
        });
  }
}

final profileService = ProfileService();

final friendRequestsProvider =
    StreamProvider.family<List<FriendRequest>, String>((ref, uid) {
      return profileService.getIncomingFriendRequests(uid);
    });
