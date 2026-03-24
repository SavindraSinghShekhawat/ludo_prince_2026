import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions";

admin.initializeApp();

if (process.env["FUNCTIONS_EMULATOR"] !== "true") {
  setGlobalOptions({region: "europe-west1"});
} else {
  setGlobalOptions({region: "us-central1"});
}

export {handleMoveRequest} from "./handleMoveRequest";
export {handleRollRequest} from "./handleRollRequest";
export {handleMatchmaking} from "./handleMatchmaking";
export {handleGameEnd} from "./handleGameEnd";
export {handlePresence} from "./handlePresence";
