import {onValueCreated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";
import {PlayerMatchInfo} from "./models/Matchmaking";
import {PlayerEntry} from "./models/Player";
import {GameDocument} from "./models/GameDocument";
import {AppLogger} from "./utils/logger";
import {randomInt} from "node:crypto";

/**
 * Matchmaking Cloud Function
 * Triggered when a player joins a queue for a specific game mode.
 */
export const handleMatchmaking = onValueCreated(
  {
    ref: "/matchmaking/{gameType}/{mode}/queue/{uid}",
  },
  async (event) => {
    const gameType = event.params.gameType;
    const mode = event.params.mode;
    
    AppLogger.debug(`[handleMatchmaking] Triggered for game: ${gameType}, mode: ${mode}, uid: ${event.params.uid}`);

    const queueRef = admin.database().ref(`matchmaking/${gameType}/${mode}/queue`);

    // 1. Get required player count for the mode
    let requiredPlayers = 0;
    // Common Ludo modes
    if (gameType === "ludo") {
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
          AppLogger.error(`Unknown ludo mode: ${mode}`);
          return;
      }
    } else {
      // Default fallback for other games
      requiredPlayers = 2;
    }

    // 2. Read the queue for this mode
    const queueSnap = await queueRef.orderByChild("joinedAt").limitToFirst(requiredPlayers).get();

    if (queueSnap.numChildren() < requiredPlayers) {
      return;
    }

    const lockRef = admin.database().ref(`matchmaking/${gameType}/${mode}/processing`);

    try {
      const lockResult = await lockRef.transaction((currentValue) => {
        if (currentValue === true) return;
        return true;
      });

      if (!lockResult.committed) return;

      const freshQueueSnap = await queueRef.orderByChild("joinedAt").limitToFirst(requiredPlayers).get();
      if (freshQueueSnap.numChildren() < requiredPlayers) {
        await lockRef.set(false);
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
      const gameRef = admin.database().ref(`games/${gameType}`).push();
      const gameId = gameRef.key;

      const gameData: GameDocument = {
        status: "playing",
        gameMode: mode.startsWith("team") ? "team" : "classic",
        createdAt: ServerValue.TIMESTAMP,
        currentTurn: "slot1",
        turnNumber: 1,
        turnStartedAt: ServerValue.TIMESTAMP,
        turnOrder: [],
        eventCounter: 0,
        players: {},
        isDiceRolled: false,
        prefetchedSeed: randomInt(0, 10000000),
        settings: {
          turnTimeSeconds: 15,
          maxSkips: 5,
        },
      };

      const updates: Record<string, unknown> = {};

      playersInMatch.forEach((player, index) => {
        let slot = `slot${index + 1}`;

        if (gameType === "ludo") {
          if (mode === "classic_2p") {
            slot = index === 0 ? "slot1" : "slot3";
          } else if (mode === "classic_3p") {
            const threePlayerSlots = ["slot1", "slot4", "slot3"];
            slot = threePlayerSlots[index];
          } else {
            const fourPlayerSlots = ["slot1", "slot4", "slot3", "slot2"];
            slot = fourPlayerSlots[index];
          }
        }

        const playerEntry: PlayerEntry = {
          uid: player.uid,
          name: player.name || `Player ${index + 1}`,
          connected: true,
          joinedAt: ServerValue.TIMESTAMP,
          status: "active",
          skipCount: 0,
          sixPity: 2,
        };

        if (mode === "team_2v2") {
          playerEntry.team = (index === 0 || index === 2) ? "A" : "B";
        }

        gameData.players[slot] = playerEntry;
        (gameData.turnOrder as string[]).push(slot);

        updates[`matchmakingAssignments/${player.uid}`] = {
          gameId: gameId,
          gameType: gameType,
          assignedAt: ServerValue.TIMESTAMP,
        };

        updates[`matchmaking/${gameType}/${mode}/queue/${player.uid}`] = null;
      });

      updates[`games/${gameType}/${gameId}`] = gameData;
      updates[`matchmaking/${gameType}/${mode}/processing`] = false;

      await admin.database().ref().update(updates);

      AppLogger.debug(`Match created: ${gameId} in ${gameType} for mode ${mode}`);
    } catch (error) {
      AppLogger.error("Matchmaking error:", error);
      await lockRef.set(false);
    }
  }
);
