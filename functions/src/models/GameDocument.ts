import {GameEvent} from "./GameEvent";
import {PlayerEntry} from "./Player";

export interface GameDocument {
  status: string;
  gameMode: string;
  createdAt: object | number;
  currentTurn: string;
  turnNumber: number;
  turnStartedAt: object | number;
  eventCounter: number;
  players: Record<string, PlayerEntry>;
  events?: Record<string, GameEvent>;
  settings: {
    turnTimeSeconds: number;
    maxMissedTurns: number;
  };
}
