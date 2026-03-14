import {onValueWritten} from "firebase-functions/v2/database";
import {randomInt} from "crypto";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";
import {GameDocument} from "./models/GameDocument";
import {RollEvent} from "./models/GameEvent";

const REGION = "europe-west1";

export const handleRollRequest = onValueWritten(
  {
    ref: "/ludogames/{gameId}/rollRequests/{uid}",
    instance: "ludo-prince-cf74a-default-rtdb",
    region: REGION,
  },
  async (event) => {
    console.log(`[handleRollRequest] Triggered for gameId: ${event.params.gameId}, uid: ${event.params.uid}`);
    const gameId = event.params.gameId;
    const uid = event.params.uid;

    if (!event.data?.after.exists()) {
      console.log("[handleRollRequest] Request was deleted. Skipping.");
      return;
    }

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

    await gameRef.child("events").child(eventId).set(rollEvent);

    await gameRef.update({
      eventCounter: eventCounter,
    });

    await admin
      .database()
      .ref(`ludogames/${gameId}/rollRequests/${uid}`)
      .remove();
  }
);
