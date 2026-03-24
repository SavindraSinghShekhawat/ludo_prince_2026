import {onValueCreated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";
import {GameDocument} from "./models/GameDocument";
import {MoveEvent} from "./models/GameEvent";

export const handleMoveRequest = onValueCreated(
  {
    ref: "/ludogames/{gameId}/moveRequests/{uid}",
    instance: "ludo-prince-cf74a-default-rtdb",
  },
  async (event) => {
    console.log(`[handleMoveRequest] Triggered for gameId: ${event.params.gameId}, uid: ${event.params.uid}`);
    const gameId = event.params.gameId;
    const uid = event.params.uid;
    const data = event.data?.val();
    if (!data) return;
    const tokenId = (data as { tokenId: number }).tokenId;

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

      const eventCounter = (game.eventCounter || 0) + 1;
      const eventId = String(eventCounter).padStart(5, "0");

      const moveEvent: MoveEvent = {
        type: "move",
        playerSlot: currentTurn,
        tokenId: tokenId,
        turnNumber: game.turnNumber,
        timestamp: ServerValue.TIMESTAMP,
      };

      if (!game.events) {
        game.events = {};
      }
      game.events[eventId] = moveEvent;
      game.eventCounter = eventCounter;

      return game;
    });

    if (result.committed) {
      await admin
        .database()
        .ref(`ludogames/${gameId}/moveRequests/${uid}`)
        .remove();
    }
  },
);
