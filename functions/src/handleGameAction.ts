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

const CHANCES_FOR_SIX = [0.00, 0.02, 0.05, 0.133077, 0.21, 0.34, 0.55, 0.82, 1.00];

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
    ref: "/games/{gameType}/{gameId}/actionRequests/{uid}",
  },
  async (event) => {
    const gameType = event.params.gameType;
    const gameId = event.params.gameId;
    const uid = event.params.uid;
    const data = event.data.val();

    AppLogger.debug("[handleGameAction] ==================== START ====================");
    AppLogger.debug(`[handleGameAction] Triggered for game=${gameType}, gameId=${gameId}, uid=${uid}`);
    if (!data) {
      AppLogger.debug("[handleGameAction] No data found. Exiting.");
      return;
    }

    const type = data.type;
    AppLogger.debug(`[handleGameAction] Request type: ${type}`);

    const gameRef = admin.database().ref(`games/${gameType}/${gameId}`);
    const requestRef = admin.database().ref(`games/${gameType}/${gameId}/actionRequests/${uid}`);

    try {
      const txResult = await gameRef.transaction((game: GameDocument | null) => {
        AppLogger.debug(`[handleGameAction] transaction callback started`);
        if (!game) {
          AppLogger.debug(`[handleGameAction] ABORT: game ${gameId} not found.`);
          return game; // return null to successfully commit null, preventing abort log suppression
        }
        if (game.status !== "playing") {
          AppLogger.debug(`[handleGameAction] ABORT: game ${gameId} status is ${game.status}`);
          return game;
        }

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
          return game;
        }

        const currentTurn = game.currentTurn;

        // Validation based on type
        if (type === "roll") {
          if (playerSlot !== currentTurn) {
            AppLogger.debug(`[handleGameAction] REJECT ROLL: ${playerSlot} tried to roll, but it is ${currentTurn}'s turn.`);
            return game;
          }
          if (game.isDiceRolled) {
            AppLogger.debug("[handleGameAction] REJECT ROLL: Dice already rolled this turn.");
            return game;
          }

          const pityCount = players[currentTurn].sixPity ?? 2;
          const seed = game.prefetchedSeed ?? randomInt(0, 10000000);

          let dice = 1;
          if (gameType === "ludo") {
            dice = generatePRDDice(seed, pityCount);
          } else {
            dice = (seed % 6) + 1; // Generic roll
          }

          if (gameType === "ludo") {
            if (dice === 6) {
              players[currentTurn].sixPity = 0;
            } else {
              players[currentTurn].sixPity = pityCount + 1;
            }
          }

          AppLogger.info(`[handleGameAction] AUDIT_ROLL: Player ${playerSlot} rolled ${dice} in game ${gameId}`);

          const eventCounter = (game.eventCounter || 0) + 1;
          
          game._latestEvent = {
            type: "roll",
            playerSlot: currentTurn,
            diceValue: dice,
            turnNumber: game.turnNumber || 0,
            timestamp: ServerValue.TIMESTAMP,
          } as RollEvent;
          game.eventCounter = eventCounter;
          game.diceValue = dice;
          game.isDiceRolled = true;
          delete game.prefetchedSeed;
          return game;
        } else if (type === "move") {
          if (playerSlot !== currentTurn) {
            AppLogger.debug(`[handleGameAction] REJECT MOVE: ${playerSlot} tried to move, but it is ${currentTurn}'s turn.`);
            return game;
          }
          if (!game.isDiceRolled) {
            AppLogger.debug(`[handleGameAction] REJECT MOVE: ${playerSlot} tried to move without rolling.`);
            return game;
          }

          AppLogger.debug(`[handleGameAction] ACCEPT MOVE: Token ${data.tokenId} for ${playerSlot}`);

          const eventCounter = (game.eventCounter || 0) + 1;

          game._latestEvent = {
            type: "move",
            playerSlot: currentTurn,
            tokenId: data.tokenId,
            turnNumber: game.turnNumber || 0,
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
            return game;
          }

          const currentPlayer = players[currentTurn];
          if (!currentPlayer) {
            AppLogger.debug(`[handleGameAction] REJECT TIMEOUT: current player ${currentTurn} not found.`);
            return game;
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

          const eventTurnNumber = game.turnNumber || 0;
          game.currentTurn = nextTurn;
          game.turnStartedAt = ServerValue.TIMESTAMP;
          game.turnNumber = (game.turnNumber || 0) + 1;
          game.isDiceRolled = false;
          game.prefetchedSeed = randomInt(0, 10000000);

          const eventCounter = (game.eventCounter || 0) + 1;

          game._latestEvent = {
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
        } else if (type === "quit") {
          const currentPlayer = players[playerSlot];
          if (!currentPlayer) return game;

          AppLogger.debug(`[handleGameAction] ACCEPT QUIT: ${playerSlot} quit`);
          currentPlayer.status = "left";

          const eventCounter = (game.eventCounter || 0) + 1;
          const eventTurnNumber = game.turnNumber || 0;

          game._latestEvent = {
            type: "quit",
            playerSlot: playerSlot,
            turnNumber: eventTurnNumber,
            timestamp: ServerValue.TIMESTAMP,
          };
          game.eventCounter = eventCounter;

          // If it was their turn, skip to next player
          if (game.currentTurn === playerSlot) {
            const turnOrder = game.turnOrder || ["slot1", "slot4", "slot3", "slot2"];
            const winners = game.winners || [];
            let idx = turnOrder.indexOf(game.currentTurn);
            let nextTurn = game.currentTurn;

            for (let i = 0; i < turnOrder.length; i++) {
              idx = (idx + 1) % turnOrder.length;
              const candidate = turnOrder[idx];
              if (winners.includes(candidate)) continue;
              if (!players[candidate] || players[candidate].status === "left") continue;
              nextTurn = candidate;
              break;
            }

            game.currentTurn = nextTurn;
            game.turnStartedAt = ServerValue.TIMESTAMP;
            game.turnNumber = (game.turnNumber || 0) + 1;
            game.isDiceRolled = false;
            game.prefetchedSeed = randomInt(0, 10000000);
          }

          // Check if game is finished
          const winners = game.winners || [];
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
          return game;
        }

        return game;
      });
      
      // Process post-transaction event persistence
      if (txResult.committed && txResult.snapshot.exists()) {
        const newGame = txResult.snapshot.val();
        if (newGame._latestEvent) {
          const eventId = String(newGame.eventCounter).padStart(5, "0");
          const updates: any = {};
          
          // Append the event to gameEvents node
          updates[`gameEvents/${gameType}/${gameId}/${eventId}`] = newGame._latestEvent;
          // Atomically remove _latestEvent from the game object
          updates[`games/${gameType}/${gameId}/_latestEvent`] = null;
          // Also cleanup the old events node if it exists (legacy compatibility)
          if (newGame.events !== undefined) {
             updates[`games/${gameType}/${gameId}/events`] = null;
          }
          
          await admin.database().ref().update(updates);
        }
      }

      // Clear the request node
      await requestRef.remove();
    } catch (err) {
      AppLogger.error("[handleGameAction] Error:", err);
    }
  }
);
