import {onValueCreated} from "firebase-functions/v2/database";
import {randomInt} from "crypto";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";

export const handleRollRequest = onValueCreated(
  {
    ref: "/ludogames/{gameId}/rollRequests/{uid}",
    region: "europe-west1",
  },
  async (event) => {
    const gameId = event.params.gameId;
    const uid = event.params.uid;

    const gameRef = admin.database().ref(`ludogames/${gameId}`);

    const gameSnap = await gameRef.get();
    const game = gameSnap.val();

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

    await gameRef.child("events").child(eventId).set({
      type: "roll",
      playerSlot: currentTurn,
      diceValue: dice,
      turnNumber: game.turnNumber,
      timestamp: ServerValue.TIMESTAMP,
    });

    await gameRef.update({
      eventCounter: eventCounter,
    });

    await admin
      .database()
      .ref(`ludogames/${gameId}/rollRequests/${uid}`)
      .remove();
  }
);
