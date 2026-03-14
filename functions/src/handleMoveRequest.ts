import {onValueWritten} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";
import {GameDocument} from "./models/GameDocument";
import {MoveEvent} from "./models/GameEvent";

const REGION = "europe-west1";

export const handleMoveRequest = onValueWritten(
  {
    ref: "/ludogames/{gameId}/moveRequests/{uid}",
    instance: "ludo-prince-cf74a-default-rtdb",
    region: REGION,
  },
  async (event) => {
    console.log(`[handleMoveRequest] Triggered for gameId: ${event.params.gameId}, uid: ${event.params.uid}`);
    const gameId = event.params.gameId;
    const uid = event.params.uid;
    const data = event.data?.after.val();
    if (!data) {
      console.log("[handleMoveRequest] Request was deleted. Skipping.");
      return;
    }
    const tokenId = (data as { tokenId: number }).tokenId;

    const gameRef = admin.database().ref(`ludogames/${gameId}`);
    const gameSnap = await gameRef.get();
    const game = gameSnap.val() as GameDocument | null;

    if (!game) return;

    const players = game.players;
    const currentTurn = game.currentTurn;

    let playerSlot: string | null = null;

    for (const slot in players) {
      if (players[slot].uid === uid) {
        playerSlot = slot;
      }
    }

    if (playerSlot !== currentTurn) {
      console.log("Not player's turn");
      return;
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

    await gameRef.child("events").child(eventId).set(moveEvent);

    await gameRef.update({
      eventCounter: eventCounter,
    });

    await admin
      .database()
      .ref(`ludogames/${gameId}/moveRequests/${uid}`)
      .remove();
  },
);
