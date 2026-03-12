import * as admin from "firebase-admin";
import {GameEvent} from "../models/GameEvent";
import {GameDocument} from "../models/GameDocument";

/**
 * Writes a game event into the RTDB event log using a transaction.
 * Ensures event ordering and prevents race conditions.
 *
 * @param {string} gameId ID of the game
 * @param {GameEvent} event Event payload to append to the events log
 */
export async function writeGameEvent(gameId: string, event: GameEvent) {
  const gameRef = admin.database().ref(`ludogames/${gameId}`);

  await gameRef.transaction((game: GameDocument | null) => {
    if (!game) return game;

    const counter = (game.eventCounter || 0) + 1;
    const eventId = String(counter).padStart(5, "0");

    if (!game.events) {
      game.events = {};
    }

    game.events[eventId] = event;
    game.eventCounter = counter;

    return game;
  });
}
