import {onValueUpdated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";

export const handlePresence = onValueUpdated({
  ref: "/presence/{uid}",
}, async (event) => {
  const before = event.data.before.val();
  const after = event.data.after.val();

  // Only proceed if the 'online' status changed
  if (before?.online === after?.online) return;

  const uid = event.params.uid;

  // 1. Update online count
  // We only increment/decrement if the online status actually changed to true/false
  const countRef = admin.database().ref("stats/onlineCount");
  try {
    if (after?.online === true && before?.online !== true) {
      await countRef.transaction((currentCount) => (currentCount || 0) + 1);
    } else if (after?.online === false && before?.online === true) {
      await countRef.transaction((currentCount) => Math.max(0, (currentCount || 0) - 1));
    }
  } catch (error) {
    console.error("Error updating online count:", error);
  }

  // 2. If disconnected, handle potential turn skipping
  if (after?.online === false) {
    console.log(`[handlePresence] User ${uid} went offline. Checking for active turns...`);
    // This is a bit expensive to query all ludogames,
    // but we can query ludogames where currentTurn logic might be needed.
    // In a real app, we'd have a mapping of UID to active games.
    // For now, let's assume we have a way to find relevant games or just rely on a timeout function.

    // Better approach: If they just joined a game, the client set up an onDisconnect
    // for ludogames/{gameId}/players/{slot}/connected.
    // We should trigger off THAT instead.
  }
});
