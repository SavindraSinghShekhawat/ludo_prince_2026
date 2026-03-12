import {onValueCreated} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {ServerValue} from "firebase-admin/database";

export const handleMoveRequest = onValueCreated(
  {
    ref: "/ludogames/{gameId}/moveRequests/{uid}",
    region: "europe-west1",
  },
  async (event) => {
    const gameId = event.params.gameId;
    const uid = event.params.uid;
    const data = event.data?.val();

    const tokenId = data.tokenId;

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

    const eventCounter = (game.eventCounter || 0) + 1;
    const eventId = String(eventCounter).padStart(5, "0");

    await gameRef.child("events").child(eventId).set({
      type: "move",
      playerSlot: currentTurn,
      tokenId: tokenId,
      turnNumber: game.turnNumber,
      timestamp: ServerValue.TIMESTAMP,
    });

    await gameRef.update({
      eventCounter: eventCounter,
    });

    await admin
      .database()
      .ref(`ludogames/${gameId}/moveRequests/${uid}`)
      .remove();
  },
);
