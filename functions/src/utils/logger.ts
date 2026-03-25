import * as logger from "firebase-functions/logger";

/**
 * A centralized logger for Cloud Functions.
 */
export const AppLogger = {
  /**
   * Logs a message only in debug/emulator environments.
   */
  debug: (message: unknown, ...args: unknown[]) => {
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      logger.debug(message, ...args);
    }
  },

  /**
   * Logs an info message.
   */
  info: (message: unknown, ...args: unknown[]) => {
    logger.info(message, ...args);
  },

  /**
   * Logs an error message.
   */
  error: (message: unknown, ...args: unknown[]) => {
    logger.error(message, ...args);
  },
};
