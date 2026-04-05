import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";

admin.initializeApp();

if (process.env["FUNCTIONS_EMULATOR"] !== "true") {
  setGlobalOptions({region: "europe-west1"});
} else {
  setGlobalOptions({region: "us-central1"});
}

export {handleGameAction} from "./handleGameAction.js";
export {handleMatchmaking} from "./handleMatchmaking.js";
export {handleGameEnd} from "./handleGameEnd.js";
export {handlePresence} from "./handlePresence.js";
export {onFriendRequestUpdated} from "./handleSocial.js";
