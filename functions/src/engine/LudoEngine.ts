import { Token, PlayerEntry } from "../models/Player";

export class LudoEngine {
  static safeRelativeSpots = [0, 8, 13, 21, 26, 34, 39, 47];

  static isSafeSpot(relativePosition: number): boolean {
    return this.safeRelativeSpots.includes(relativePosition);
  }

  static getAbsolutePosition(slot: string, relativePosition: number): number {
    if (relativePosition > 51) return -1;
    let startAbsolute = 0;
    switch (slot) {
    case "slot4": startAbsolute = 0; break;
    case "slot3": startAbsolute = 13; break;
    case "slot2": startAbsolute = 26; break;
    case "slot1": startAbsolute = 39; break;
    }
    return (startAbsolute + relativePosition) % 52;
  }

  static isValidMove(token: Token, dice: number): boolean {
    if (token.state === "home") {
      return dice === 6;
    }
    if (token.state === "finished") {
      return false;
    }
    return token.position + dice <= 56;
  }

  static getValidMoves(tokens: Token[], dice: number): Token[] {
    if (!tokens) return [];
    return tokens.filter(t => this.isValidMove(t, dice));
  }

  static advanceOneStep(token: Token): Token {
    const newPos = token.position + 1;

    if (token.state === "board") {
      if (newPos > 50) {
        return { ...token, state: "homeStretch", position: newPos };
      }
      return { ...token, position: newPos };
    }

    if (token.state === "homeStretch") {
      if (newPos === 56) {
        return { ...token, state: "finished", position: newPos };
      }
      return { ...token, position: newPos };
    }

    return token;
  }

  static applyMove(
    players: Record<string, PlayerEntry>,
    slot: string,
    tokenId: number,
    dice: number,
    gameMode: string
  ): { players: Record<string, PlayerEntry>, hasCaptured: boolean } {
    
    const newPlayers = JSON.parse(JSON.stringify(players)) as Record<string, PlayerEntry>;
    const player = newPlayers[slot];
    if (!player || !player.tokens) return { players: newPlayers, hasCaptured: false };

    const token = player.tokens.find(t => t.id === tokenId);
    if (!token) return { players: newPlayers, hasCaptured: false };

    // Move token out of home
    if (token.state === "home" && dice === 6) {
      token.state = "board";
      token.position = 0;
    } else {
      // Step it forward
      for (let i = 0; i < dice; i++) {
        const advanced = this.advanceOneStep(token);
        token.state = advanced.state;
        token.position = advanced.position;
      }
    }

    let hasCaptured = false;

    // Check Capture
    if (token.state === "board" && !this.isSafeSpot(token.position)) {
      const absPos = this.getAbsolutePosition(slot, token.position);

      for (const [pSlot, p] of Object.entries(newPlayers)) {
        if (pSlot === slot) continue;

        // Team mode check
        if (gameMode === "team") {
          const isTeammate = 
            (slot === "slot1" && pSlot === "slot3") ||
            (slot === "slot3" && pSlot === "slot1") ||
            (slot === "slot2" && pSlot === "slot4") ||
            (slot === "slot4" && pSlot === "slot2");
          if (isTeammate) continue;
        }

        if (!p.tokens) continue;

        for (const t of p.tokens) {
          if (t.state === "board") {
            const oppAbs = this.getAbsolutePosition(pSlot, t.position);
            if (oppAbs === absPos) {
              hasCaptured = true;
              t.state = "home";
              t.position = -1;
            }
          }
        }
      }
    }

    return { players: newPlayers, hasCaptured };
  }
}
