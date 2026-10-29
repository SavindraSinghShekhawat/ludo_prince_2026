import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {AppLogger} from "./utils/logger";

/**
 * Scheduled garbage collector that runs once a week to sweep stale/orphaned cloud data:
 * 1. Finished or disbanded games older than 3 minutes (after victory screen is viewed).
 * 2. Abandoned lobbies older than 15 minutes.
 * 3. Orphaned private room codes whose linked game no longer exists.
 * 4. Stale matchmaking assignments older than 15 minutes.
 * 5. Stale match invites older than 10 minutes.
 */
export const cleanupStaleData = onSchedule(
  {
    schedule: "every sunday 00:00",
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    const db = admin.database();
    const now = Date.now();
    AppLogger.info("[cleanupStaleData] Starting automated stale data sweep...");

    try {
      // 1. Clean games & gameEvents
      const gamesSnap = await db.ref("games/ludo").get();
      if (gamesSnap.exists() && gamesSnap.hasChildren()) {
        const games = gamesSnap.val() as Record<string, Record<string, unknown>>;
        const toDeleteGames: Record<string, null> = {};
        const toDeleteEvents: Record<string, null> = {};
        const toDeleteCodes: Record<string, null> = {};

        for (const [gameId, game] of Object.entries(games)) {
          const status = game["status"] as string | undefined;
          const createdAt = typeof game["createdAt"] === "number" ? game["createdAt"] : 0;
          const endedAt = typeof game["endedAt"] === "number" ? game["endedAt"] : 0;
          const hostLastActive = typeof game["hostLastActive"] === "number" ? game["hostLastActive"] : createdAt;
          const joiningCode = game["joiningCode"] as string | undefined;

          // Finished games > 3 minutes old
          if (status === "finished") {
            const age = endedAt > 0 ? now - endedAt : now - createdAt;
            if (age > 180000) {
              toDeleteGames[`games/ludo/${gameId}`] = null;
              toDeleteEvents[`gameEvents/ludo/${gameId}`] = null;
            }
          } else if (status === "disbanded" || status === "abandoned") {
            // Disbanded or abandoned games > 1 minute old
            toDeleteGames[`games/ludo/${gameId}`] = null;
            toDeleteEvents[`gameEvents/ludo/${gameId}`] = null;
            if (joiningCode) {
              toDeleteCodes[`privateRoomCodes/${joiningCode}`] = null;
            }
          } else if (status === "lobby") {
            // Lobbies abandoned for > 15 minutes
            const idleTime = now - hostLastActive;
            if (idleTime > 900000) {
              toDeleteGames[`games/ludo/${gameId}`] = null;
              toDeleteEvents[`gameEvents/ludo/${gameId}`] = null;
              if (joiningCode) {
                toDeleteCodes[`privateRoomCodes/${joiningCode}`] = null;
              }
            }
          } else if (status === "playing") {
            // Stalled in-progress games with no action for > 45 minutes
            const turnStartedAt = typeof game["turnStartedAt"] === "number" ? game["turnStartedAt"] : createdAt;
            if (now - turnStartedAt > 2700000) {
              toDeleteGames[`games/ludo/${gameId}`] = null;
              toDeleteEvents[`gameEvents/ludo/${gameId}`] = null;
            }
          }
        }

        const gameUpdates = {...toDeleteGames, ...toDeleteEvents, ...toDeleteCodes};
        if (Object.keys(gameUpdates).length > 0) {
          await db.ref().update(gameUpdates);
          AppLogger.info(`[cleanupStaleData] Purged ${Object.keys(toDeleteGames).length} stale games/events`);
        }
      }

      // 2. Clean orphaned private room codes
      const codesSnap = await db.ref("privateRoomCodes").get();
      if (codesSnap.exists() && codesSnap.hasChildren()) {
        const codes = codesSnap.val() as Record<string, { gameId?: string; createdAt?: number }>;
        const deadCodes: Record<string, null> = {};

        for (const [code, val] of Object.entries(codes)) {
          const createdAt = typeof val?.createdAt === "number" ? val.createdAt : 0;
          if (now - createdAt > 1800000) {
            // Older than 30 mins
            deadCodes[`privateRoomCodes/${code}`] = null;
          } else if (val?.gameId) {
            const gameCheck = await db.ref(`games/ludo/${val.gameId}/status`).get();
            if (!gameCheck.exists() || gameCheck.val() !== "lobby") {
              deadCodes[`privateRoomCodes/${code}`] = null;
            }
          }
        }

        if (Object.keys(deadCodes).length > 0) {
          await db.ref().update(deadCodes);
          AppLogger.info(`[cleanupStaleData] Purged ${Object.keys(deadCodes).length} orphaned room codes`);
        }
      }

      // 3. Clean matchmaking assignments older than 15 minutes
      const assignmentsSnap = await db.ref("matchmakingAssignments").get();
      if (assignmentsSnap.exists() && assignmentsSnap.hasChildren()) {
        const assignments = assignmentsSnap.val() as Record<string, { assignedAt?: number }>;
        const deadAssignments: Record<string, null> = {};

        for (const [uid, val] of Object.entries(assignments)) {
          const assignedAt = typeof val?.assignedAt === "number" ? val.assignedAt : 0;
          if (now - assignedAt > 900000) {
            deadAssignments[`matchmakingAssignments/${uid}`] = null;
          }
        }

        if (Object.keys(deadAssignments).length > 0) {
          await db.ref().update(deadAssignments);
          AppLogger.info(`[cleanupStaleData] Purged ${Object.keys(deadAssignments).length} stale assignments`);
        }
      }

      // 4. Clean invites older than 10 minutes
      const invitesSnap = await db.ref("invites").get();
      if (invitesSnap.exists() && invitesSnap.hasChildren()) {
        const allInvites = invitesSnap.val() as Record<string, Record<string, { timestamp?: number; status?: string }>>;
        const deadInvites: Record<string, null> = {};

        for (const [targetUid, userInvites] of Object.entries(allInvites)) {
          if (!userInvites || typeof userInvites !== "object") continue;
          for (const [inviteId, invite] of Object.entries(userInvites)) {
            const ts = typeof invite?.timestamp === "number" ? invite.timestamp : 0;
            if (invite?.status === "accepted" || (now - ts > 600000)) {
              deadInvites[`invites/${targetUid}/${inviteId}`] = null;
            }
          }
        }

        if (Object.keys(deadInvites).length > 0) {
          await db.ref().update(deadInvites);
          AppLogger.info(`[cleanupStaleData] Purged ${Object.keys(deadInvites).length} stale invites`);
        }
      }

      AppLogger.info("[cleanupStaleData] Stale data sweep completed successfully.");
    } catch (error) {
      AppLogger.error("[cleanupStaleData] Sweep failed with error:", error);
    }
  }
);
