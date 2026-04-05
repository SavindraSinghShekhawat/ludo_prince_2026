import {onDocumentUpdated} from "firebase-functions/v2/firestore";
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
