import {GameEvent} from "../models/GameEvent";

export interface GameDocument {
  eventCounter?: number
  events?: Record<string, GameEvent>
//   players?: Record<string, Player>
  currentTurn?: string
  turnNumber?: number
}
