import {onValueUpdated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {GameDocument} from "./models/GameDocument";
import {AppLogger} from "./utils/logger";

export const handleGameEnd = onValueUpdated(
  {
    ref: "/games/{gameType}/{gameId}/status",
  },
  async (event) => {
    const status = event.data?.after.val();
    if (status !== "finished") return;

    const gameType = event.params.gameType;
    const gameId = event.params.gameId;
    const gameRef = admin.database().ref(`games/${gameType}/${gameId}`);
    const gameSnap = await gameRef.get();
    const game = gameSnap.val() as GameDocument & { winners?: string[] } | null;

    if (!game || !game.players) {
      AppLogger.debug(`[handleGameEnd] Game not found or no players for gameId: ${gameId}`);
      return;
    }

    AppLogger.debug(`[handleGameEnd] Processing stats for game: ${gameId} in ${gameType}`);

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
          gamesPlayed: FieldValue.increment(1),
          gamesWon: isWinner ?
            FieldValue.increment(1) :
            FieldValue.increment(0),
          lastActive: FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }

    await batch.commit();
    AppLogger.info(`[handleGameEnd] Stats updated successfully for ${playerUids.length} players in game: ${gameId}`);
  }
);
