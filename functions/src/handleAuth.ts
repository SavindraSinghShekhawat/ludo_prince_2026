import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {AppLogger} from "./utils/logger";

/**
 * Authoritative server-side Cloud Function to merge anonymous guest statistics
 * into an authenticated permanent user account upon sign-in / registration.
 *
 * Security Model:
 * 1. Requires an authenticated caller (the new permanent user).
 * 2. Requires a cryptographically signed Firebase ID token of the anonymous guest session.
 * 3. Verifies via admin.auth().verifyIdToken that the caller legitimately controlled the guest session.
 * 4. Merges stats strictly from the server-side Firestore guest document, never from client input.
 * 5. Uses a Firestore transaction and marks the guest profile as merged to prevent replay attacks.
 */
export const mergeGuestAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated to merge an account.");
  }

  const callerUid = request.auth.uid;
  const guestIdToken = request.data?.guestIdToken;

  if (!guestIdToken || typeof guestIdToken !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid guestIdToken.");
  }

  // 1. Verify the guest ID token cryptographically
  let decodedGuestToken;
  try {
    decodedGuestToken = await admin.auth().verifyIdToken(guestIdToken);
  } catch (err) {
    AppLogger.error(`[mergeGuestAccount] Failed to verify guest token: ${err}`);
    throw new HttpsError("unauthenticated", "Invalid or expired guest session token.");
  }

  const guestUid = decodedGuestToken.uid;

  // If the guest UID and caller UID are identical (e.g. in-place account linking), nothing to merge
  if (guestUid === callerUid) {
    AppLogger.info(`[mergeGuestAccount] Guest UID matches caller UID (${callerUid}); no merge needed.`);
    return {success: true, merged: false, message: "Same user account."};
  }

  // Verify that the guest account was actually anonymous
  if (decodedGuestToken.firebase?.sign_in_provider !== "anonymous") {
    AppLogger.error(`[mergeGuestAccount] Attempted to merge non-anonymous account ${guestUid} into ${callerUid}`);
    throw new HttpsError("permission-denied", "Source account must be an anonymous guest account.");
  }

  const firestore = admin.firestore();
  const guestRef = firestore.collection("users").doc(guestUid);
  const callerRef = firestore.collection("users").doc(callerUid);

  try {
    const result = await firestore.runTransaction(async (transaction) => {
      const guestDoc = await transaction.get(guestRef);
      if (!guestDoc.exists) {
        return {
          success: false,
          merged: false,
          gamesPlayedAdded: 0,
          gamesWonAdded: 0,
          message: "Guest profile not found.",
        };
      }

      const guestData = guestDoc.data() || {};
      if (guestData.isMerged) {
        return {
          success: false,
          merged: false,
          gamesPlayedAdded: 0,
          gamesWonAdded: 0,
          message: "Guest stats have already been merged.",
        };
      }

      const played = typeof guestData.gamesPlayed === "number" ? guestData.gamesPlayed : 0;
      const won = typeof guestData.gamesWon === "number" ? guestData.gamesWon : 0;

      // Transfer stats if guest had played games
      if (played > 0 || won > 0) {
        transaction.set(
          callerRef,
          {
            gamesPlayed: FieldValue.increment(played),
            gamesWon: FieldValue.increment(won),
            lastActive: FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
      }

      // Mark the guest document as merged
      transaction.update(guestRef, {
        isMerged: true,
        mergedTo: callerUid,
        mergedAt: FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        merged: true,
        gamesPlayedAdded: played,
        gamesWonAdded: won,
        message: "Successfully merged guest stats.",
      };
    });

    // Clean up the anonymous auth user & guest document in background
    try {
      await guestRef.delete();
      await admin.auth().deleteUser(guestUid);
    } catch (cleanupErr) {
      AppLogger.debug(`[mergeGuestAccount] Cleanup notice for ${guestUid}: ${cleanupErr}`);
    }

    AppLogger.info(
      `[mergeGuestAccount] Successfully merged guest ${guestUid} into user ${callerUid} ` +
      `(+${result.gamesPlayedAdded ?? 0} played, +${result.gamesWonAdded ?? 0} won).`
    );

    return result;
  } catch (error) {
    AppLogger.error(`[mergeGuestAccount] Transaction failed: ${error}`);
    throw new HttpsError("internal", "Failed to merge guest account statistics.");
  }
});
