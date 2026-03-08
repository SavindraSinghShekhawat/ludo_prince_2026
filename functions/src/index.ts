import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

admin.initializeApp();

export const checkTurnTimeout = onSchedule("every 1 minutes", async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  const games = await db.collection("games")
    .where("status", "==", "playing")
    .get();

  for (const gameDoc of games.docs) {
    const game = gameDoc.data();
    const turnStartedAt = game.turnStartedAt;
    const turnTimeSeconds = game.settings?.turnTimeSeconds || 30;

    if (now.seconds - turnStartedAt.seconds > turnTimeSeconds) {
      // Perform auto-turn
      const currentSlot = game.currentTurn;
      const playerRef = gameDoc.ref.collection("players").doc(currentSlot);
      const playerDoc = await playerRef.get();
      const player = playerDoc.data();

      if (!player) continue;

      const missedTurns = (player.missedTurns || 0) + 1;
      const maxMissedTurns = game.settings?.maxMissedTurns || 5;

      if (missedTurns >= maxMissedTurns) {
        await playerRef.update({
          status: "exited",
          missedTurns: missedTurns
        });
      } else {
        await playerRef.update({
          missedTurns: missedTurns
        });
      }

      // Generate random dice and move (simplified logic for Cloud Function)
      // In a real scenario, this would trigger a move event
      const diceValue = Math.floor(Math.random() * 6) + 1;
      const eventCounter = (game.eventCounter || 0) + 1;
      const eventId = eventCounter.toString().padStart(5, "0");

      await gameDoc.ref.collection("events").doc(eventId).set({
        type: "roll",
        playerSlot: currentSlot,
        turnNumber: game.turnNumber,
        diceValue: diceValue,
        auto: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      await gameDoc.ref.collection("events").doc((eventCounter + 1).toString().padStart(5, "0")).set({
        type: "move",
        playerSlot: currentSlot,
        turnNumber: game.turnNumber,
        tokenId: 0, // Fallback to first token for simplicity in auto-play
        auto: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      await gameDoc.ref.update({
        eventCounter: eventCounter + 1,
        // Turn progression would normally be handled by the client or a background trigger
      });
    }
  }
});
