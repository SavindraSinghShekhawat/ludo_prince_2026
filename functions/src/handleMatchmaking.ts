import {onValueCreated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";
import {PlayerMatchInfo} from "./models/Matchmaking";
import {PlayerEntry} from "./models/Player";
import {GameDocument} from "./models/GameDocument";

/**
 * Matchmaking Cloud Function
 * Triggered when a player joins a queue for a specific game mode.
 */
export const handleMatchmaking = onValueCreated(
  {
    ref: "/matchmaking/{mode}/queue/{uid}",
    instance: "ludo-prince-cf74a-default-rtdb",
  },
  async (event) => {
    console.log(`[handleMatchmaking] Triggered for mode: ${event.params.mode}, uid: ${event.params.uid}`);
    const mode = event.params.mode;
    // const uid = event.params.uid; // Triggered by this user

    const queueRef = admin.database().ref(`matchmaking/${mode}/queue`);

    // 1. Get required player count for the mode
    let requiredPlayers = 0;
    switch (mode) {
    case "classic_2p":
      requiredPlayers = 2;
      break;
    case "classic_3p":
      requiredPlayers = 3;
      break;
    case "classic_4p":
    case "team_2v2":
      requiredPlayers = 4;
      break;
    default:
      console.error(`Unknown game mode: ${mode}`);
      return;
    }

    // 2. Read the queue for this mode
    // We order by joinedAt to prioritize people who have been waiting longer
    const queueSnap = await queueRef.orderByChild("joinedAt").limitToFirst(requiredPlayers).get();

    if (queueSnap.numChildren() < requiredPlayers) {
      // Not enough players yet
      return;
    }

    // 3. We have enough players.
    // HOWEVER, to prevent race conditions (multiple functions triggering at once),
    // we should use a transaction or a locking mechanism.
    // In RTDB, we can use a transaction on a "locked" flag or just rely on the first one
    // to successfully remove players from the queue.

    // Better approach for RTDB: Use a transaction on the queue subset or a separate lock path.
    // For simplicity and speed as requested, we'll attempt a multi-path update.
    // current queue status in the update condition (though RTDB multi-path update doesn't
    // support conditions on individual paths like Firestore's write batches).

    // Instead, let's use a transaction on a "processing" node for this mode
    const lockRef = admin.database().ref(`matchmaking/${mode}/processing`);

    try {
      const lockResult = await lockRef.transaction((currentValue) => {
        if (currentValue === true) {
          // Already being processed by another instance
          return;
        }
        return true; // Lock it
      });

      if (!lockResult.committed) {
        return;
      }

      // Re-verify queue after acquiring lock
      const freshQueueSnap = await queueRef.orderByChild("joinedAt").limitToFirst(requiredPlayers).get();
      if (freshQueueSnap.numChildren() < requiredPlayers) {
        await lockRef.set(false); // Release lock
        return;
      }

      const playersInMatch: PlayerMatchInfo[] = [];
      freshQueueSnap.forEach((child) => {
        playersInMatch.push({
          uid: child.key as string,
          ...(child.val() as Partial<PlayerMatchInfo>),
        } as PlayerMatchInfo);
      });

      // 4. Create new game
      const gameRef = admin.database().ref("ludogames").push();
      const gameId = gameRef.key;

      const gameData: GameDocument = {
        status: "playing",
        gameMode: mode.startsWith("team") ? "team" : "classic",
        createdAt: ServerValue.TIMESTAMP,
        currentTurn: "slot1",
        turnNumber: 1,
        turnStartedAt: ServerValue.TIMESTAMP,
        eventCounter: 0,
        players: {},
        settings: {
          turnTimeSeconds: 15,
          maxMissedTurns: 3,
        },
      };

      const updates: Record<string, unknown> = {};

      playersInMatch.forEach((player, index) => {
        let slot = `slot${index + 1}`;

        // Refine slot mapping according to user requirement
        if (mode === "classic_2p") {
          slot = index === 0 ? "slot1" : "slot3";
        } else if (mode === "classic_3p") {
          const threePlayerSlots = ["slot1", "slot3", "slot4"];
          slot = threePlayerSlots[index];
        }

        const playerEntry: PlayerEntry = {
          uid: player.uid,
          name: player.name || `Player ${index + 1}`,
          connected: true,
          joinedAt: ServerValue.TIMESTAMP,
          status: "active",
          missedTurns: 0,
        };

        if (mode === "team_2v2") {
          playerEntry.team = (index === 0 || index === 2) ? "A" : "B";
        }

        gameData.players[slot] = playerEntry;

        // Matchmaking assignments
        updates[`matchmakingAssignments/${player.uid}`] = {
          gameId: gameId,
          assignedAt: ServerValue.TIMESTAMP,
        };

        // Remove from queue
        updates[`matchmaking/${mode}/queue/${player.uid}`] = null;
      });

      // Add the game itself
      updates[`ludogames/${gameId}`] = gameData;

      // Release lock in the same update if possible, or right after
      updates[`matchmaking/${mode}/processing`] = false;

      // 5. Execute atomic update
      await admin.database().ref().update(updates);

      console.log(`Match created: ${gameId} for mode ${mode} with players: ${playersInMatch.map((p) => p.uid).join(", ")}`);
    } catch (error) {
      console.error("Matchmaking error:", error);
      // Ensure lock is released even on error
      await lockRef.set(false);
    }
  }
);
