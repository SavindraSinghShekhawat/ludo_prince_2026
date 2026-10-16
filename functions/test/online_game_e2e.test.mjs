import admin from "firebase-admin";
import { LudoEngine } from "../lib/engine/LudoEngine.js";

process.env.FIREBASE_DATABASE_EMULATOR_HOST = process.env.FIREBASE_DATABASE_EMULATOR_HOST || "127.0.0.1:9000";
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "ludo-prince-cf74a",
    databaseURL: "http://127.0.0.1:9000?ns=ludo-prince-cf74a-default-rtdb",
  });
}

const db = admin.database();

const isVerbose = process.env.VERBOSE === "true" || process.env.VERBOSE === "1" || process.argv.includes("--verbose");

function logDetail(...args) {
  if (isVerbose) {
    console.log(...args);
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForCondition(desc, fn, timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const res = await fn();
    if (res) return res;
    await delay(40);
  }
  throw new Error(`Timeout waiting for: ${desc}`);
}

/**
 * Intelligent token selection heuristic matching in-game bot AI:
 * 1. Prioritize finishing a token into home goal
 * 2. On 6, bring waiting tokens out of base
 * 3. Move token furthest advanced towards finish
 */
function chooseBestToken(tokens, validMoves, diceValue) {
  // 1. Can we finish a token?
  const finishMove = validMoves.find((t) => t.state === "homeStretch" && t.position + diceValue === 56);
  if (finishMove) return finishMove;

  // 2. If rolled 6, bring a token out of home if any are at base
  if (diceValue === 6) {
    const homeMove = validMoves.find((t) => t.state === "home");
    if (homeMove) return homeMove;
  }

  // 3. Move token furthest along the board / stretch
  const sorted = [...validMoves].sort((a, b) => b.position - a.position);
  return sorted[0];
}

/**
 * TEST 1: Full live multiplayer match with real Cloud Function PRD random dice rolls
 * and engine moves until a player naturally finishes and wins.
 */
async function testFullRandomGameToVictory() {
  logDetail("\n=======================================================");
  logDetail("🎮 TEST 1: FULL RANDOM GAME TO NATURAL VICTORY");
  logDetail("=======================================================\n");

  const gameId = "full_sim_match_" + Date.now();
  const hostUid = "host_uid_sim1";
  const friendUid = "friend_uid_sim2";
  const gameRef = db.ref(`games/ludo/${gameId}`);

  const tokenCount = 2;

  logDetail(`1. Creating Private Room: ${gameId} with ${tokenCount} tokens per player`);
  await gameRef.set({
    status: "lobby",
    isPrivate: true,
    joiningCode: "554433",
    gameMode: "classic",
    createdAt: Date.now(),
    hostUid: hostUid,
    maxPlayers: 2,
    currentPlayers: 1,
    currentTurn: "slot1",
    turnNumber: 1,
    turnStartedAt: Date.now(),
    eventCounter: 0,
    settings: { turnTimeSeconds: 15, maxSkips: 5 },
    players: {
      slot1: {
        uid: hostUid,
        name: "HostPlayer",
        skipCount: 0,
        sixPity: 2,
        connected: true,
        joinedAt: Date.now(),
        lastActive: Date.now(),
        status: "active",
        tokens: Array.from({ length: tokenCount }, (_, i) => ({
          id: i,
          slot: "slot1",
          position: 0,
          state: "home",
        })),
      },
      slot3: {
        uid: friendUid,
        name: "FriendPlayer",
        skipCount: 0,
        sixPity: 2,
        connected: true,
        joinedAt: Date.now(),
        lastActive: Date.now(),
        status: "active",
        tokens: Array.from({ length: tokenCount }, (_, i) => ({
          id: i,
          slot: "slot3",
          position: 0,
          state: "home",
        })),
      },
    },
  });

  // Start game
  logDetail("2. Starting Game...");
  await gameRef.update({
    status: "playing",
    currentTurn: "slot1",
    turnNumber: 1,
    turnStartedAt: Date.now(),
    turnOrder: ["slot1", "slot3"],
    isDiceRolled: false,
    eventCounter: 0,
    prefetchedSeed: 9876543,
  });

  logDetail("3. Game is 'playing'. Running full game turn loop with server PRD rolls...\n");

  let turnCount = 0;
  const maxTurns = 600;
  let rollsCount = 0;
  let movesCount = 0;
  let skipsCount = 0;
  let extraTurnsCount = 0;

  while (turnCount < maxTurns) {
    const snap = await gameRef.get();
    const game = snap.val();

    if (!game || game.status === "finished") {
      logDetail(`\n🏁 Game naturally finished at turn ${turnCount}!`);
      break;
    }

    turnCount++;
    const currentTurn = game.currentTurn;
    const currentUid = game.players[currentTurn]?.uid;

    if (!currentUid) {
      throw new Error(`Player UID not found for slot ${currentTurn}`);
    }

    // Step A: Roll the dice via Cloud Function
    await db.ref(`games/ludo/${gameId}/actionRequests/${currentUid}`).set({
      type: "roll",
      timestamp: Date.now(),
    });

    await waitForCondition(`Roll processed for ${currentTurn}`, async () => {
      const g = (await gameRef.get()).val();
      return g?.isDiceRolled === true;
    });

    const rolledGame = (await gameRef.get()).val();
    const diceValue = rolledGame.diceValue;
    rollsCount++;

    const playerTokens = rolledGame.players[currentTurn].tokens || [];
    const validMoves = LudoEngine.getValidMoves(playerTokens, diceValue);

    if (validMoves.length > 0) {
      // Step B1: Choose valid token and move via Cloud Function
      const tokenToMove = chooseBestToken(playerTokens, validMoves, diceValue);
      movesCount++;

      await db.ref(`games/ludo/${gameId}/actionRequests/${currentUid}`).set({
        type: "move",
        tokenId: tokenToMove.id,
        timestamp: Date.now(),
      });

      // Wait for move execution
      await waitForCondition(`Move processed for token ${tokenToMove.id}`, async () => {
        const g = (await gameRef.get()).val();
        return g?.isDiceRolled === false || g?.status === "finished";
      });

      const afterMoveGame = (await gameRef.get()).val();
      if (afterMoveGame?.status === "finished") {
        logDetail(`Turn ${turnCount}: [${currentTurn}] rolled ${diceValue} -> Token ${tokenToMove.id} finished the game!`);
        break;
      }

      if (afterMoveGame?.currentTurn === currentTurn) {
        extraTurnsCount++;
      }
    } else {
      // Step B2: No valid moves -> Send skip via Cloud Function
      skipsCount++;
      await db.ref(`games/ludo/${gameId}/actionRequests/${currentUid}`).set({
        type: "skip",
        timestamp: Date.now(),
      });

      // Wait for skip execution
      await waitForCondition(`Skip processed for ${currentTurn}`, async () => {
        const g = (await gameRef.get()).val();
        return g?.isDiceRolled === false && g?.currentTurn !== currentTurn;
      });
    }

    // Periodic progress report in verbose mode
    if (turnCount % 15 === 0) {
      const g = (await gameRef.get()).val();
      const p1Finished = g?.players?.slot1?.tokens?.filter((t) => t.state === "finished").length || 0;
      const p2Finished = g?.players?.slot3?.tokens?.filter((t) => t.state === "finished").length || 0;
      logDetail(`  [Turn ${turnCount}] Rolls: ${rollsCount}, Moves: ${movesCount}, Skips: ${skipsCount} | Finished: Slot1=${p1Finished}/${tokenCount}, Slot3=${p2Finished}/${tokenCount}`);
    }
  }

  const finalSnap = await gameRef.get();
  const finalGame = finalSnap.val();

  if (finalGame?.status !== "finished" || !finalGame?.winners?.length) {
    throw new Error("Game 1 failed to reach natural finished state with winners!");
  }

  logDetail("\n--- GAME 1 RESULTS ---");
  logDetail("✅ Final Status:", finalGame.status);
  logDetail("✅ Winners:", finalGame.winners);
  logDetail("✅ Total Turns:", turnCount);
  logDetail("✅ Total Random Rolls Generated by Cloud Functions:", rollsCount);
  logDetail("✅ Total Moves Applied Authoritatively by Cloud Functions:", movesCount);
  logDetail("✅ Total Skips Handled by Server:", skipsCount);
  logDetail("✅ Extra Turns Awarded (6s/captures/finishes):", extraTurnsCount);

  console.log(`  ✔ Test 1: Full Random Game to Natural Victory (${turnCount} turns, winner: ${finalGame.winners[0]})`);
}

/**
 * TEST 2: Mid-game Forfeit / Resignation edge case
 */
async function testForfeitEdgeCase() {
  logDetail("\n=======================================================");
  logDetail("🚪 TEST 2: MID-MATCH FORFEIT / RESIGNATION HANDLING");
  logDetail("=======================================================\n");

  const gameId = "forfeit_match_" + Date.now();
  const hostUid = "host_uid_forfeit";
  const friendUid = "friend_uid_forfeit";
  const gameRef = db.ref(`games/ludo/${gameId}`);

  logDetail(`1. Setting up match: ${gameId}`);
  await gameRef.set({
    status: "playing",
    isPrivate: true,
    joiningCode: "112233",
    gameMode: "classic",
    createdAt: Date.now(),
    hostUid: hostUid,
    maxPlayers: 2,
    currentPlayers: 2,
    currentTurn: "slot1",
    turnNumber: 1,
    turnStartedAt: Date.now(),
    turnOrder: ["slot1", "slot3"],
    isDiceRolled: false,
    eventCounter: 0,
    players: {
      slot1: {
        uid: hostUid,
        name: "HostPlayer",
        status: "active",
        tokens: [{ id: 0, slot: "slot1", position: 0, state: "home" }],
      },
      slot3: {
        uid: friendUid,
        name: "FriendPlayer",
        status: "active",
        tokens: [{ id: 0, slot: "slot3", position: 0, state: "home" }],
      },
    },
  });

  // Host takes a roll
  logDetail("2. Host rolls dice...");
  await db.ref(`games/ludo/${gameId}/actionRequests/${hostUid}`).set({
    type: "roll",
    timestamp: Date.now(),
  });
  await waitForCondition("Host roll processed", async () => (await gameRef.get()).val()?.isDiceRolled === true);

  // Friend forfeits mid-game
  logDetail("3. Friend forfeits/quits match via Cloud Function...");
  await db.ref(`games/ludo/${gameId}/actionRequests/${friendUid}`).set({
    type: "quit",
    timestamp: Date.now(),
  });

  await waitForCondition("Game finished after forfeit", async () => {
    const g = (await gameRef.get()).val();
    return g?.status === "finished" && g?.winners?.includes("slot1");
  });

  const finalSnap = await gameRef.get();
  const finalGame = finalSnap.val();

  logDetail("✅ Forfeit handled successfully: Status is 'finished'");
  logDetail("✅ Host awarded victory as remaining active player:", finalGame.winners);

  console.log("  ✔ Test 2: Mid-Match Forfeit / Resignation Handling");
}

/**
 * TEST 3: Action states, protocol guards & anti-cheat validations
 */
async function testActionStatesAndGuards() {
  logDetail("\n=======================================================");
  logDetail("🛡️  TEST 3: ACTION STATES & PROTOCOL GUARDS VALIDATION");
  logDetail("=======================================================\n");

  const gameId = "action_guards_" + Date.now();
  const hostUid = "host_uid_guard";
  const friendUid = "friend_uid_guard";
  const gameRef = db.ref(`games/ludo/${gameId}`);

  // Guard 1: In Lobby state, action requests must be ignored
  logDetail("Guard 1: Actions in 'lobby' state must be ignored");
  await gameRef.set({
    status: "lobby",
    isPrivate: true,
    hostUid: hostUid,
    players: {
      slot1: { uid: hostUid, name: "Host", tokens: [{ id: 0, slot: "slot1", position: 0, state: "home" }] },
      slot3: { uid: friendUid, name: "Friend", tokens: [{ id: 0, slot: "slot3", position: 0, state: "home" }] },
    },
  });
  await db.ref(`games/ludo/${gameId}/actionRequests/${hostUid}`).set({ type: "roll", timestamp: Date.now() });
  await delay(300);
  const lobbySnap = (await gameRef.get()).val();
  if (lobbySnap.isDiceRolled) throw new Error("Guard 1 Failed: Rolled dice while in lobby!");
  logDetail("  ✅ Action rejected while in lobby");

  // Transition to playing state
  await gameRef.update({
    status: "playing",
    currentTurn: "slot1",
    turnOrder: ["slot1", "slot3"],
    isDiceRolled: false,
    turnStartedAt: Date.now(),
    settings: { turnTimeSeconds: 15, maxSkips: 3 },
  });

  // Guard 2: Roll out of turn
  logDetail("Guard 2: Player rolling out of turn must be rejected");
  await db.ref(`games/ludo/${gameId}/actionRequests/${friendUid}`).set({ type: "roll", timestamp: Date.now() });
  await delay(300);
  const outOfTurnSnap = (await gameRef.get()).val();
  if (outOfTurnSnap.isDiceRolled) throw new Error("Guard 2 Failed: Slot 3 rolled during Slot 1's turn!");
  logDetail("  ✅ Out-of-turn roll rejected");

  // Guard 3: Move before rolling
  logDetail("Guard 3: Move requested before rolling must be rejected");
  await db.ref(`games/ludo/${gameId}/actionRequests/${hostUid}`).set({ type: "move", tokenId: 0, timestamp: Date.now() });
  await delay(300);
  const moveBeforeRollSnap = (await gameRef.get()).val();
  if (moveBeforeRollSnap.players.slot1.tokens[0].state !== "home") throw new Error("Guard 3 Failed: Token moved before rolling!");
  logDetail("  ✅ Move before roll rejected");

  // Guard 4: Premature timeout
  logDetail("Guard 4: Premature timeout request must be rejected");
  await db.ref(`games/ludo/${gameId}/actionRequests/${hostUid}`).set({ type: "timeout", timestamp: Date.now() });
  await delay(300);
  const prematureTimeoutSnap = (await gameRef.get()).val();
  if ((prematureTimeoutSnap.players.slot1.skipCount || 0) > 0) throw new Error("Guard 4 Failed: Premature timeout accepted!");
  logDetail("  ✅ Premature timeout rejected");

  // Perform valid roll
  logDetail("Guard 5: Double-roll prevention");
  await db.ref(`games/ludo/${gameId}/actionRequests/${hostUid}`).set({ type: "roll", timestamp: Date.now() });
  await waitForCondition("Roll processed", async () => (await gameRef.get()).val()?.isDiceRolled === true);
  const firstRollVal = (await gameRef.get()).val()?.diceValue;

  // Try rolling again in same turn
  await db.ref(`games/ludo/${gameId}/actionRequests/${hostUid}`).set({ type: "roll", timestamp: Date.now() });
  await delay(300);
  const doubleRollSnap = (await gameRef.get()).val();
  if (doubleRollSnap.diceValue !== firstRollVal) throw new Error("Guard 5 Failed: Dice was re-rolled in the same turn!");
  logDetail("  ✅ Double-roll prevented in same turn");

  // Guard 6: Illegal move penalty handling
  logDetail("Guard 6: Illegal move detection (moving home token without rolling 6)");
  await gameRef.update({ diceValue: 2 });
  await db.ref(`games/ludo/${gameId}/actionRequests/${hostUid}`).set({ type: "move", tokenId: 0, timestamp: Date.now() });
  await waitForCondition("Illegal move penalized", async () => {
    const g = (await gameRef.get()).val();
    return g?.currentTurn === "slot3" && g?.players?.slot1?.skipCount === 1;
  });
  logDetail("  ✅ Illegal move penalized as timeout; token kept in home; turn safely passed to Slot 3");

  console.log("  ✔ Test 3: Action States & Protocol Guards Validation (6/6 guards passed)");
}

async function runAllTests() {
  const t0 = Date.now();
  await testFullRandomGameToVictory();
  await testForfeitEdgeCase();
  await testActionStatesAndGuards();

  const duration = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(`\n🏆 All Firebase Functions E2E Tests Passed in ${duration}s!`);
  process.exit(0);
}

runAllTests().catch((err) => {
  console.error("\n❌ E2E ONLINE TESTS FAILED:", err);
  process.exit(1);
});
