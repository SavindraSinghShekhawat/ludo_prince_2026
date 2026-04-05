export interface PlayerEntry {
  uid: string;
  name: string;
  connected: boolean;
  joinedAt: object | number;
  status: string;
  skipCount: number;
  team?: string;
  tokens?: Record<string, unknown>;
}
