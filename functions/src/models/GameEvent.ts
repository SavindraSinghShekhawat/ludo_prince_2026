export type GameEventType = "roll" | "move" | "quit" | "skip";

export interface GameEvent {
  type: GameEventType;
  playerSlot: string;
  turnNumber: number;
  timestamp: number | object;
}

export interface RollEvent extends GameEvent {
  type: "roll";
  diceValue: number;
}

export interface MoveEvent extends GameEvent {
  type: "move";
  tokenId: number;
}

export interface QuitEvent extends GameEvent {
  type: "quit";
}
