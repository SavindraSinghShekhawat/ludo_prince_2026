import {onValueUpdated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {GameDocument} from "./models/GameDocument";

export const handleGameEnd = onValueUpdated(
  {
    ref: "/ludogames/{gameId}/status",
    instance: "ludo-prince-cf74a-default-rtdb",
  },
  async (event) => {
    const status = event.data?.after.val();
    if (status !== "finished") return;

    const gameId = event.params.gameId;
    const gameRef = admin.database().ref(`ludogames/${gameId}`);
    const gameSnap = await gameRef.get();
    const game = gameSnap.val() as GameDocument & { winners?: string[] } | null;

    if (!game || !game.players) {
      console.log(`[handleGameEnd] Game not found or no players for gameId: ${gameId}`);
      return;
    }

    console.log(`[handleGameEnd] Processing stats for game: ${gameId}`);

    const firestore = admin.firestore();
    const batch = firestore.batch();

    const winnerUids = game.winners || [];
    const playerUids = Object.values(game.players).map((p) => p.uid);

    for (const uid of playerUids) {
      if (!uid) continue;

      const userRef = firestore.collection("users").doc(uid);
      const isWinner = winnerUids.includes(uid);

      batch.set(
        userRef,
        {
          gamesPlayed: admin.firestore.FieldValue.increment(1),
          gamesWon: isWinner
            ? admin.firestore.FieldValue.increment(1)
            : admin.firestore.FieldValue.increment(0),
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }

    await batch.commit();
    console.log(`[handleGameEnd] Stats updated successfully for ${playerUids.length} players in game: ${gameId}`);
  }
);
