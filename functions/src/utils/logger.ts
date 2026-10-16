import * as logger from "firebase-functions/logger";

/**
 * A centralized logger for Cloud Functions.
 */
export const AppLogger = {
  /**
   * Logs a message only in debug/emulator environments when VERBOSE is enabled.
   */
  debug: (message: unknown, ...args: unknown[]) => {
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      if (process.env.VERBOSE === "true" || process.env.VERBOSE === "1") {
        logger.debug(message, ...args);
      }
    } else {
      logger.debug(message, ...args);
    }
  },

  /**
   * Logs an info message (suppressed in emulator tests unless VERBOSE is enabled).
   */
  info: (message: unknown, ...args: unknown[]) => {
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      if (process.env.VERBOSE === "true" || process.env.VERBOSE === "1") {
        logger.info(message, ...args);
      }
    } else {
      logger.info(message, ...args);
    }
  },

  /**
   * Logs an error message.
   */
  error: (message: unknown, ...args: unknown[]) => {
    logger.error(message, ...args);
  },
};
