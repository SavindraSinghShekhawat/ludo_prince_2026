import { onValueCreated, onValueUpdated, onValueWritten } from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import { ServerValue } from "firebase-admin/database";

admin.initializeApp();
const db = admin.database();

// Random delay helper
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

// 1. Lobby Auto-Fill (Random 5-10s window)
export const onLobbyCreated = onValueCreated("/ludogames/{gameId}", async (event) => {
    const gameId = event.params.gameId;
    const gameData = event.data.val();

    console.log(`[BotFill] Lobby Created event for ${gameId}. Status: ${gameData?.status}`);
    if (!gameData || gameData.status !== "lobby" || gameData.isPrivate) {
        console.log(`[BotFill] Ignoring game ${gameId} - Not a public lobby`);
        return;
    }

    // Wait random 5 to 10 seconds
    const waitTime = Math.floor(Math.random() * 5000) + 5000;
    await delay(waitTime);

    const gameRef = db.ref(`/ludogames/${gameId}`);
    
    // Check if the lobby still needs players
    try {
        const snapshot = await gameRef.once('value');
        const currentData = snapshot.val();

        if (!currentData) {
            console.log(`[BotFill] Aborted - Game ${gameId} not found`);
            return;
        }
        if (currentData.status !== "lobby") {
            console.log(`[BotFill] Aborted - Game ${gameId} status is ${currentData.status}`);
            return; 
        }

        const maxPlayers = currentData.maxPlayers || 4;
        const players = currentData.players || {};
        const usedSlots = Object.keys(players);
        
        const actualPlayerCount = usedSlots.length;
        console.log(`[BotFill] Game ${gameId}: ${actualPlayerCount}/${maxPlayers} slots filled`);

        if (actualPlayerCount >= maxPlayers) {
            console.log(`[BotFill] Aborted - Game ${gameId} is full`);
            return;
        }

        const allSlots = maxPlayers === 2 ? ["slot1", "slot3"] : 
                         maxPlayers === 3 ? ["slot1", "slot3", "slot4"] :
                         ["slot1", "slot2", "slot3", "slot4"];

        for (const slot of allSlots) {
            if (!usedSlots.includes(slot)) {
                players[slot] = {
                    uid: `bot_${slot}_${Date.now()}`,
                    name: `Bot ${slot.charAt(4)}`,
                    missedTurns: 0,
                    connected: true, // Serverside bot is always "connected"
                    joinedAt: ServerValue.TIMESTAMP,
                    lastSeen: ServerValue.TIMESTAMP,
                    status: "active",
                    isBot: true
                };
            }
        }

        await gameRef.update({
            players: players,
            currentPlayers: maxPlayers,
            status: "playing",
            turnStartedAt: ServerValue.TIMESTAMP
        });
        
        console.log(`[BotFill] Game ${gameId}: Successfully populated remaining empty slots with bots. Set status to playing.`);
    } catch (e) {
        console.error(`[BotFill] Error filling bots:`, e);
    }
});

// 2. Server-Side Turn auto-play and Disconnect check
export const onTurnChanged = onValueUpdated("/ludogames/{gameId}/turnStartedAt", async (event) => {
    const gameId = event.params.gameId;
    const turnStartedAtStr = event.data.after.val();
    
    // Wait 10 seconds for user to play (or bot to play via this exact mechanism)
    // Actually, we should just fire immediately if it's a bot's turn, but human gets 10s.
    // Let's read the game state immediately to check whose turn it is
    let gameSnap = await db.ref(`/ludogames/${gameId}`).once('value');
    let gameData = gameSnap.val();
    
    if (!gameData || gameData.status !== "playing") return;

    const currentTurn = gameData.currentTurn;
    const currentPlayer = gameData.players[currentTurn];
    
    if (!currentPlayer) return;

    // If bot, wait 1-2s for realism. If human, wait 10s.
    const isBot = currentPlayer.isBot;
    const isDisconnectedHuman = !isBot && currentPlayer.connected === false;
    
    const waitTime = isBot ? 1500 : (isDisconnectedHuman ? 0 : 10500); // 10s + 500ms grace period
    if (waitTime > 0) {
        await delay(waitTime);
    }
    
    // Check if the original turn hasn't been completed during our delay
    gameSnap = await db.ref(`/ludogames/${gameId}`).once('value');
    gameData = gameSnap.val();
    
    if (!gameData || gameData.status !== "playing" || gameData.turnStartedAt !== turnStartedAtStr) {
        // Someone played within the time limit. All good.
        return;
    }

    // Still the same turn! Time's up. The user or disconnected player missed their turn.
    // Increment missedTurns for human
    if (!isBot) {
        let missedCount = (currentPlayer.missedTurns || 0) + 1;
        const maxMissed = gameData.settings?.maxMissedTurns || 5;
        
        if (missedCount >= maxMissed) {
            await db.ref(`/ludogames/${gameId}/players/${currentTurn}`).update({
                status: "exited",
                missedTurns: missedCount
            });
            // End turn/game for booted player via a quit event
            await triggerEvent(gameId, currentTurn, gameData.turnNumber, gameData.eventCounter, {
                type: 'quit',
                playerSlot: currentTurn
            });
            return;
        } else {
            await db.ref(`/ludogames/${gameId}/players/${currentTurn}/missedTurns`).set(missedCount);
        }
    }

    // Force roll
    const diceValue = Math.floor(Math.random() * 6) + 1;
    let eventCounter = gameData.eventCounter || 0;
    
    await triggerEvent(gameId, currentTurn, gameData.turnNumber, eventCounter, {
        type: 'roll',
        playerSlot: currentTurn,
        diceValue: diceValue
    });
    
    // Now execute move. Since backend is stateless to exact board pieces, 
    // we use a special "autoMove: true" flag which tells the frontend LudoController
    // to strictly apply BotAI or pick a valid token automatically without validating token ID.
    // Wait for roll animation
    await delay(1000);
    
    // Re-fetch to see if game ended early or something (not strictly necessary but safe)
    gameSnap = await db.ref(`/ludogames/${gameId}`).once('value');
    eventCounter = gameSnap.val().eventCounter || eventCounter + 1;

    await triggerEvent(gameId, currentTurn, gameSnap.val().turnNumber, eventCounter, {
        type: 'move',
        playerSlot: currentTurn,
        tokenId: 0, // Fallback dummy ID
        autoMove: true // Important for frontend to recognize this is a forced generic move
    });
});

// Helper to push an event via transaction
async function triggerEvent(gameId: string, currentTurn: string, turnNumber: number, eventCounter: number, eventData: any) {
    const gameRef = db.ref(`/ludogames/${gameId}`);
    return gameRef.transaction((gameData) => {
        if (gameData === null) return null;
        if (!gameData) return; 
        
        const newCounter = (gameData.eventCounter || eventCounter) + 1;
        const newEventId = newCounter.toString().padStart(5, '0');
        
        if (!gameData.events) gameData.events = {};
        
        gameData.events[newEventId] = {
            ...eventData,
            turnNumber: gameData.turnNumber, // keep consistent with state
            timestamp: ServerValue.TIMESTAMP
        };
        
        gameData.eventCounter = newCounter;
        console.log(`[BotFill] Game ${gameId}: Triggered ${eventData.type} event (ID: ${newEventId}) for turn ${turnNumber}.`);
        return gameData;
    });
}

// 3. Cleanup logic for Host Disconnect during matchmaking
export const onPlayerDisconnectStatus = onValueWritten("/ludogames/{gameId}/players/{slotId}/connected", async (event) => {
    const gameId = event.params.gameId;
    const connected = event.data.after.val();
    
    if (connected === false) {
        // Player went offline
        const gameSnap = await db.ref(`/ludogames/${gameId}`).once('value');
        const gameData = gameSnap.val();
        if (gameData && gameData.status === "lobby") {
            // Is it the host?
            if (gameData.hostUid === gameData.players[event.params.slotId]?.uid) {
                // Host left during lobby, destroy the game
                await db.ref(`/ludogames/${gameId}`).remove();
            }
        }
    }
});
