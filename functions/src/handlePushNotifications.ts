import {onValueCreated} from "firebase-functions/v2/database";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {AppLogger} from "./utils/logger";

/**
 * Helper to dispatch push notifications to a user's registered FCM tokens
 */
async function sendPushToUser(
  targetUid: string,
  payload: {
    title: string;
    body: string;
    data: Record<string, string>;
  }
) {
  try {
    const firestore = admin.firestore();
    const userDoc = await firestore.collection("users").doc(targetUid).get();

    if (!userDoc.exists) {
      AppLogger.debug(`[sendPushToUser] User ${targetUid} not found for push.`);
      return;
    }

    const userData = userDoc.data() || {};
    const tokens: string[] = [];

    if (typeof userData.fcmToken === "string" && userData.fcmToken.trim().length > 0) {
      tokens.push(userData.fcmToken.trim());
    }
    if (Array.isArray(userData.fcmTokens)) {
      for (const t of userData.fcmTokens) {
        if (typeof t === "string" && t.trim().length > 0 && !tokens.includes(t.trim())) {
          tokens.push(t.trim());
        }
      }
    }

    if (tokens.length === 0) {
      AppLogger.debug(`[sendPushToUser] No FCM tokens found for user ${targetUid}.`);
      return;
    }

    AppLogger.info(`[sendPushToUser] Sending push notification to ${tokens.length} token(s) for user ${targetUid}`);

    const messaging = admin.messaging();

    const messageConfig = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data,
      android: {
        priority: "high" as const,
        notification: {
          sound: "default",
          priority: "max" as const,
        },
      },
      apns: {
        headers: {
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: payload.title,
              body: payload.body,
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
    };

    if (tokens.length === 1) {
      try {
        await messaging.send({
          token: tokens[0],
          ...messageConfig,
        });
      } catch (err: unknown) {
        const error = err as { code?: string; message?: string };
        if (
          error.code === "messaging/registration-token-not-registered" ||
          error.code === "messaging/invalid-registration-token"
        ) {
          AppLogger.info(`[sendPushToUser] Cleaning up stale token for ${targetUid}`);
          await userDoc.ref.update({
            fcmToken: admin.firestore.FieldValue.delete(),
          }).catch(() => {});
        } else {
          AppLogger.error(`[sendPushToUser] Failed to send push to single token: ${err}`);
        }
      }
    } else {
      const response = await messaging.sendEachForMulticast({
        tokens,
        ...messageConfig,
      });

      // Cleanup stale tokens
      const badTokens: string[] = [];
      response.responses.forEach((res, idx) => {
        if (!res.success && res.error) {
          if (
            res.error.code === "messaging/registration-token-not-registered" ||
            res.error.code === "messaging/invalid-registration-token"
          ) {
            badTokens.push(tokens[idx]);
          }
        }
      });

      if (badTokens.length > 0) {
        AppLogger.info(`[sendPushToUser] Removing ${badTokens.length} stale tokens for ${targetUid}`);
        await userDoc.ref.update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...badTokens),
        }).catch(() => {});
      }
    }
  } catch (error) {
    AppLogger.error(`[sendPushToUser] Error dispatching push to ${targetUid}:`, error);
  }
}

/**
 * Triggered when a new game invite is written to Realtime Database at /invites/{targetUid}/{inviteId}
 * Sends a real APNs / FCM push notification to wake up the recipient when their app is closed.
 */
export const onInviteCreated = onValueCreated(
  {
    ref: "/invites/{targetUid}/{inviteId}",
  },
  async (event) => {
    const invite = event.data?.val();
    if (!invite || invite.status !== "pending") return;

    const targetUid = event.params.targetUid;
    const fromName = invite.fromName || "A friend";
    const gameId = invite.gameId || "";
    const joiningCode = invite.joiningCode || "";
    const inviteId = event.params.inviteId;

    AppLogger.info(`[onInviteCreated] Dispatching push invite from ${fromName} to ${targetUid} (Game: ${gameId})`);

    await sendPushToUser(targetUid, {
      title: "Game Invitation 🎲",
      body: `${fromName} invited you to play Ludo!`,
      data: {
        type: "gameInvite",
        gameId: String(gameId),
        joiningCode: String(joiningCode),
        fromName: String(fromName),
        inviteId: String(inviteId),
      },
    });
  }
);

/**
 * Triggered when a new friend request document is created in Firestore at friend_requests/{requestId}
 * Sends an APNs / FCM push notification to the recipient even when the app is shut down.
 */
export const onFriendRequestCreated = onDocumentCreated(
  "friend_requests/{requestId}",
  async (event) => {
    const data = event.data?.data();
    if (!data || data.status !== "pending") return;

    const targetUid = data.to;
    const fromUid = data.from;
    const requestId = event.params.requestId;

    if (!targetUid || !fromUid) return;

    // Fetch sender's display name
    let senderName = "A player";
    try {
      const senderDoc = await admin.firestore().collection("users").doc(fromUid).get();
      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        if (senderData?.displayName) {
          senderName = senderData.displayName;
        }
      }
    } catch (err) {
      AppLogger.debug("[onFriendRequestCreated] Could not fetch sender name:", err);
    }

    AppLogger.info(`[onFriendRequestCreated] Dispatching friend request push from ${senderName} to ${targetUid}`);

    await sendPushToUser(targetUid, {
      title: "New Friend Request 👋",
      body: `${senderName} sent you a friend request!`,
      data: {
        type: "friendRequest",
        requestId: String(requestId),
        fromUid: String(fromUid),
      },
    });
  }
);
