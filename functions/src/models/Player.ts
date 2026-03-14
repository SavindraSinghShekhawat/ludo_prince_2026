export interface PlayerEntry {
  uid: string;
  name: string;
  connected: boolean;
  joinedAt: object | number;
  status: string;
  missedTurns: number;
  team?: string;
}
