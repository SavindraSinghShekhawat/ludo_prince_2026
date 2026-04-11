import {GameEvent} from "./GameEvent";
import {PlayerEntry} from "./Player";

export interface GameDocument {
  status: string;
  gameMode: string;
  createdAt: object | number;
  currentTurn: string;
  turnOrder: string[];
  turnNumber: number;
  turnStartedAt: object | number;
  diceValue?: number;
  isDiceRolled?: boolean;
  prefetchedRoll?: number;
  consecutiveSixes?: number;
  winners?: string[];
  eventCounter: number;
  players: Record<string, PlayerEntry>;
  events?: Record<string, GameEvent>;
  settings: {
    turnTimeSeconds: number;
    maxSkips: number;
  };
}
