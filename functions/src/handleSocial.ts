import {onDocumentUpdated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {AppLogger} from "./utils/logger";

/**
 * Triggered when a friend request document is updated.
 * Handles the logic for adding friends when a request is accepted.
 */
export const onFriendRequestUpdated = onDocumentUpdated(
  "friend_requests/{requestId}",
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) return;

    // Check if status changed from 'pending' to 'accepted'
    if (beforeData.status === "pending" && afterData.status === "accepted") {
      const fromUid = afterData.from;
      const toUid = afterData.to;

      if (!fromUid || !toUid) {
        AppLogger.error(`[onFriendRequestUpdated] Missing UIDs for request ${event.params.requestId}`);
        return;
      }

      const firestore = admin.firestore();
      const batch = firestore.batch();

      // 1. Add to both users' friends subcollections
      const fromFriendRef = firestore
        .collection("users")
        .doc(fromUid)
        .collection("friends")
        .doc(toUid);
      const toFriendRef = firestore
        .collection("users")
        .doc(toUid)
        .collection("friends")
        .doc(fromUid);

      const timestamp = FieldValue.serverTimestamp();
      batch.set(fromFriendRef, {addedAt: timestamp});
      batch.set(toFriendRef, {addedAt: timestamp});

      // 2. Update friendsCount for both users
      const fromUserRef = firestore.collection("users").doc(fromUid);
      const toUserRef = firestore.collection("users").doc(toUid);

      batch.update(fromUserRef, {
        friendsCount: FieldValue.increment(1),
        lastActive: timestamp,
      });
      batch.update(toUserRef, {
        friendsCount: FieldValue.increment(1),
        lastActive: timestamp,
      });

      try {
        await batch.commit();
        AppLogger.info(`[onFriendRequestUpdated] Successfully established friendship between ${fromUid} and ${toUid}`);
      } catch (error) {
        AppLogger.error("[onFriendRequestUpdated] Error committing friendship batch:", error);
      }
    }
  }
);

/**
 * Triggered when a friendship record is deleted from users/{userId}/friends/{friendId}.
 * Ensures mutual cleanup: deletes reciprocal document if still present,
 * decrements friendsCount for the affected user, and removes stale friend_requests.
 */
export const onFriendDeleted = onDocumentDeleted(
  "users/{userId}/friends/{friendId}",
  async (event) => {
    const userId = event.params.userId;
    const friendId = event.params.friendId;

    if (!userId || !friendId) return;

    const firestore = admin.firestore();
    AppLogger.info(`[onFriendDeleted] Friend deleted: ${userId} -> ${friendId}`);

    // 1. Decrement friendsCount for userId (clamped to >= 0)
    const userRef = firestore.collection("users").doc(userId);
    try {
      await firestore.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          const currentCount = Number(userDoc.data()?.friendsCount) || 0;
          transaction.update(userRef, {
            friendsCount: Math.max(0, currentCount - 1),
            lastActive: FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      AppLogger.error(`[onFriendDeleted] Failed to decrement friendsCount for ${userId}:`, e);
    }

    // 2. Ensure reciprocal document is also deleted (if not already deleted)
    const reciprocalRef = firestore
      .collection("users")
      .doc(friendId)
      .collection("friends")
      .doc(userId);

    try {
      const reciprocalSnap = await reciprocalRef.get();
      if (reciprocalSnap.exists) {
        AppLogger.info(`[onFriendDeleted] Deleting reciprocal friendship at users/${friendId}/friends/${userId}`);
        await reciprocalRef.delete();
      }
    } catch (e) {
      AppLogger.error("[onFriendDeleted] Failed checking reciprocal friendship:", e);
    }

    // 3. Clean up any historical friend_requests documents between them (in either direction)
    try {
      const requestsSnap = await firestore
        .collection("friend_requests")
        .where("from", "in", [userId, friendId])
        .get();

      const batch = firestore.batch();
      let deleteCount = 0;
      for (const doc of requestsSnap.docs) {
        const data = doc.data();
        if (
          (data.from === userId && data.to === friendId) ||
          (data.from === friendId && data.to === userId)
        ) {
          batch.delete(doc.ref);
          deleteCount++;
        }
      }
      if (deleteCount > 0) {
        await batch.commit();
        AppLogger.info(`[onFriendDeleted] Cleaned up ${deleteCount} friend request(s) between ${userId} and ${friendId}`);
      }
    } catch (e) {
      AppLogger.error("[onFriendDeleted] Failed cleaning up friend requests:", e);
    }
  }
);
