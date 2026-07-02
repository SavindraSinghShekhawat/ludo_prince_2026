export type TokenState = "home" | "board" | "homeStretch" | "finished";

export interface Token {
  id: number;
  slot: string;
  position: number;
  state: TokenState;
}

export interface PlayerEntry {
  uid: string;
  name: string;
  connected: boolean;
  joinedAt: object | number;
  status: string;
  skipCount: number;
  sixPity?: number;
  team?: string;
  tokens?: Token[];
}
