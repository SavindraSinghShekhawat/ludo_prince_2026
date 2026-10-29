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

    const rawWinners = game.winners || [];
    const winnerUids = new Set<string>();

    if (rawWinners.length > 0) {
      if (game.gameMode === "team") {
        // 2v2 Team Mode (4 players): The 2 players on the winning team both win
        const firstWinnerSlot = rawWinners[0];
        const isTeamA = firstWinnerSlot === "slot1" || firstWinnerSlot === "slot3";
        const winningSlots = isTeamA ? ["slot1", "slot3"] : ["slot2", "slot4"];

        for (const slot of winningSlots) {
          const slotPlayer = game.players[slot];
          if (slotPlayer?.uid) {
            winnerUids.add(slotPlayer.uid);
          }
        }
      } else {
        // Free-for-All (Classic, Quick, Master, etc.): Exactly 1 winner (1st place)
        const firstWinner = rawWinners[0];
        const slotPlayer = game.players[firstWinner];
        if (slotPlayer?.uid) {
          winnerUids.add(slotPlayer.uid);
        } else {
          winnerUids.add(firstWinner);
        }
      }
    }

    const playerUids = Object.values(game.players)
      .map((p) => p.uid)
      .filter((uid): uid is string => Boolean(uid));

    for (const uid of playerUids) {
      const userRef = firestore.collection("users").doc(uid);
      const isWinner = winnerUids.has(uid);

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

    // Immediately remove ephemeral game events (rolls, moves, animations) to stop storage accumulation
    await admin.database().ref(`gameEvents/${gameType}/${gameId}`).remove().catch((e) => {
      AppLogger.debug(`[handleGameEnd] Events cleanup notice: ${e}`);
    });

    // Tag the session with endedAt so the scheduled garbage collector can delete it after the victory screen
    await gameRef.update({
      endedAt: admin.database.ServerValue.TIMESTAMP,
    }).catch(() => {});
  }
);
