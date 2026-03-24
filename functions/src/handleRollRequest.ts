import {onValueCreated} from "firebase-functions/v2/database";
import {randomInt} from "crypto";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";
import {GameDocument} from "./models/GameDocument";
import {RollEvent} from "./models/GameEvent";

export const handleRollRequest = onValueCreated(
  {
    ref: "/ludogames/{gameId}/rollRequests/{uid}",
    instance: "ludo-prince-cf74a-default-rtdb",
  },
  async (event) => {
    console.log(`[handleRollRequest] Triggered for gameId: ${event.params.gameId}, uid: ${event.params.uid}`);
    const gameId = event.params.gameId;
    const uid = event.params.uid;

    const gameRef = admin.database().ref(`ludogames/${gameId}`);

    const result = await gameRef.transaction((game: GameDocument | null) => {
      if (!game) return null;

      const players = game.players;
      const currentTurn = game.currentTurn;

      let playerSlot: string | null = null;

      for (const slot in players) {
        if (players[slot].uid === uid) {
          playerSlot = slot;
        }
      }

      if (playerSlot !== currentTurn) {
        console.log(`Not player's turn: uid=${uid}, slot=${playerSlot}, currentTurn=${currentTurn}`);
        return; // Abort transaction
      }

      const dice = randomInt(1, 7);
      const eventCounter = (game.eventCounter || 0) + 1;
      const eventId = String(eventCounter).padStart(5, "0");

      const rollEvent: RollEvent = {
        type: "roll",
        playerSlot: currentTurn,
        diceValue: dice,
        turnNumber: game.turnNumber,
        timestamp: ServerValue.TIMESTAMP,
      };

      if (!game.events) {
        game.events = {};
      }
      game.events[eventId] = rollEvent;
      game.eventCounter = eventCounter;

      return game;
    });

    if (result.committed) {
      await admin
        .database()
        .ref(`ludogames/${gameId}/rollRequests/${uid}`)
        .remove();
    }
  }
);
