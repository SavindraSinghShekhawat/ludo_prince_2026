import {onValueCreated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";
import {GameDocument} from "./models/GameDocument";
import {PlayerEntry} from "./models/Player";
import {RollEvent, MoveEvent} from "./models/GameEvent";
import {AppLogger} from "./utils/logger";
import * as crypto from "node:crypto";

function randomInt(min: number, max: number) {
  // Use node:crypto.randomInt for cryptographically secure randomness.
  // This is the gold standard for secure randomness in Node.js.
  const val = crypto.randomInt(min, max);
  AppLogger.debug(`[DiceService] Generated random value: ${val} in range [${min}, ${max})`);
  return val;
}

const CHANCES_FOR_SIX = [0.00, 0.02, 0.05, 0.128, 0.21, 0.34, 0.55, 0.82, 1.00];

function generatePRDDice(seed: number, pity: number): number {
  const safePity = Math.max(0, Math.min(pity, CHANCES_FOR_SIX.length - 1));
  const chanceOfSix = CHANCES_FOR_SIX[safePity];
  const threshold = Math.floor(chanceOfSix * 10000000);

  if (seed < threshold) {
    return 6;
  } else {
    return (seed % 5) + 1;
  }
}

export const handleGameAction = onValueCreated(
  {
    ref: "/ludogames/{gameId}/actionRequests/{uid}",
  },
  async (event) => {
    const gameId = event.params.gameId;
    const uid = event.params.uid;
    const data = event.data.val();

    AppLogger.debug("[handleGameAction] ==================== START ====================");
    AppLogger.debug(`[handleGameAction] Triggered for gameId=${gameId}, uid=${uid}`);
    if (!data) {
      AppLogger.debug("[handleGameAction] No data found. Exiting.");
      return;
    }

    const type = data.type;
    AppLogger.debug(`[handleGameAction] Request type: ${type}`);

    const gameRef = admin.database().ref(`ludogames/${gameId}`);
    const requestRef = admin.database().ref(`ludogames/${gameId}/actionRequests/${uid}`);

    try {
      await gameRef.transaction((game: GameDocument | null) => {
        if (!game) return game; // Return null to trigger server-side fetch if un-cached
        if (game.status !== "playing") return; // Abort if game is truly over

        // 1. Identify player slot
        const players = game.players || {};
        let playerSlot: string | null = null;
        for (const slot in players) {
          if (players[slot].uid === uid) {
            playerSlot = slot;
            break;
          }
        }

        if (!playerSlot) {
          AppLogger.error(`UID ${uid} not found in game ${gameId}`);
          return; // Abort transaction
        }

        const currentTurn = game.currentTurn;

        // Validation based on type
        if (type === "roll") {
          if (playerSlot !== currentTurn) {
            AppLogger.debug(`[handleGameAction] REJECT ROLL: ${playerSlot} tried to roll, but it is ${currentTurn}'s turn.`);
            return;
          }
          if (game.isDiceRolled) {
            AppLogger.debug("[handleGameAction] REJECT ROLL: Dice already rolled this turn.");
            return;
          }

          const pityCount = players[currentTurn].sixPity ?? 2;
          const seed = game.prefetchedSeed ?? randomInt(0, 10000000);
          const dice = generatePRDDice(seed, pityCount);

          if (dice === 6) {
            players[currentTurn].sixPity = 0;
          } else {
            players[currentTurn].sixPity = pityCount + 1;
          }

          AppLogger.info(`[handleGameAction] AUDIT_ROLL: Player ${playerSlot} rolled ${dice} in game ${gameId}`);
          AppLogger.debug(`[handleGameAction] ACCEPT ROLL: Used dice ${dice} (seed: ${seed}, pity: ${pityCount}) for ${playerSlot}`);

          const eventCounter = (game.eventCounter || 0) + 1;
          const eventId = String(eventCounter).padStart(5, "0");

          if (!game.events) game.events = {};
          game.events[eventId] = {
            type: "roll",
            playerSlot: currentTurn,
            diceValue: dice,
            turnNumber: game.turnNumber,
            timestamp: ServerValue.TIMESTAMP,
          } as RollEvent;
          game.eventCounter = eventCounter;
          game.isDiceRolled = true;
          delete game.prefetchedSeed;
          return game;
        } else if (type === "move") {
          if (playerSlot !== currentTurn) {
            AppLogger.debug(`[handleGameAction] REJECT MOVE: ${playerSlot} tried to move, but it is ${currentTurn}'s turn.`);
            return;
          }
          if (!game.isDiceRolled) {
            AppLogger.debug(`[handleGameAction] REJECT MOVE: ${playerSlot} tried to move without rolling.`);
            return;
          }

          AppLogger.debug(`[handleGameAction] ACCEPT MOVE: Token ${data.tokenId} for ${playerSlot}`);

          const eventCounter = (game.eventCounter || 0) + 1;
          const eventId = String(eventCounter).padStart(5, "0");

          if (!game.events) game.events = {};
          game.events[eventId] = {
            type: "move",
            playerSlot: currentTurn,
            tokenId: data.tokenId,
            turnNumber: game.turnNumber,
            timestamp: ServerValue.TIMESTAMP,
          } as MoveEvent;
          game.eventCounter = eventCounter;

          game.isDiceRolled = false;
          game.prefetchedSeed = randomInt(0, 10000000);
          return game;
        } else if (type === "timeout") {
          const now = Date.now();
          const turnStartedAt = (game.turnStartedAt as number) || 0;
          const turnTimeSeconds = (game.settings?.turnTimeSeconds || 15);

          if (now < turnStartedAt + (turnTimeSeconds * 1000) - 500) {
            AppLogger.debug(`[handleGameAction] REJECT TIMEOUT: Too early. now=${now}, turnStartedAt=${turnStartedAt}`);
            return; // Too early
          }

          const currentPlayer = players[currentTurn];
          if (!currentPlayer) {
            AppLogger.debug(`[handleGameAction] REJECT TIMEOUT: current player ${currentTurn} not found.`);
            return;
          }

          AppLogger.debug(`[handleGameAction] ACCEPT TIMEOUT: Skipping turn for ${currentTurn}`);

          // Increment skip count and check for kick
          currentPlayer.skipCount = (currentPlayer.skipCount || 0) + 1;
          let playerKicked = false;
          if (currentPlayer.skipCount >= (game.settings?.maxSkips || 5)) {
            currentPlayer.status = "left";
            playerKicked = true;
          }

          // Find next player
          const turnOrder = game.turnOrder || ["slot1", "slot4", "slot3", "slot2"];
          const winners = game.winners || [];
          let idx = turnOrder.indexOf(currentTurn);
          let nextTurn = currentTurn;

          for (let i = 0; i < turnOrder.length; i++) {
            idx = (idx + 1) % turnOrder.length;
            const candidate = turnOrder[idx];
            if (winners.includes(candidate)) continue;
            if (!players[candidate] || players[candidate].status === "left") continue;
            nextTurn = candidate;
            break;
          }

          const eventTurnNumber = game.turnNumber;
          game.currentTurn = nextTurn;
          game.turnStartedAt = ServerValue.TIMESTAMP;
          game.turnNumber = (game.turnNumber || 0) + 1;
          game.isDiceRolled = false;
          game.prefetchedSeed = randomInt(0, 10000000);

          const eventCounter = (game.eventCounter || 0) + 1;
          const eventId = String(eventCounter).padStart(5, "0");

          if (!game.events) game.events = {};
          game.events[eventId] = {
            type: "skip",
            playerSlot: currentTurn,
            turnNumber: eventTurnNumber,
            timestamp: ServerValue.TIMESTAMP,
          };
          game.eventCounter = eventCounter;

          // Check forfeit winner
          if (playerKicked) {
            const activePlayers = Object.entries(players)
              .filter(([slot, p]) => (p as PlayerEntry).status === "active" && !winners.includes(slot));
            if (activePlayers.length <= 1) {
              game.status = "finished";
              const lastPlayer = activePlayers[0];
              if (lastPlayer) {
                game.winners = game.winners || [];
                game.winners.push(lastPlayer[0]);
              }
            }
          }
          return game;
        }

        return; // Abort if unknown type
      });
      // Clear the request node
      await requestRef.remove();
    } catch (err) {
      AppLogger.error("[handleGameAction] Error:", err);
    }
  }
);
