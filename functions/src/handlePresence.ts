import {onValueUpdated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";

export const handlePresence = onValueUpdated({
  ref: "/presence/{uid}",
}, async (event) => {
  const before = event.data.before.val();
  const after = event.data.after.val();

  // Only proceed if the 'online' status changed
  if (before?.online === after?.online) return;

  const countRef = admin.database().ref("stats/onlineCount");

  try {
    await countRef.transaction((currentCount) => {
      const count = currentCount || 0;
      if (after?.online === true) {
        return count + 1;
      } else if (after?.online === false) {
        return Math.max(0, count - 1);
      }
      return count;
    });
  } catch (error) {
    console.error("Error updating online count:", error);
  }
});
