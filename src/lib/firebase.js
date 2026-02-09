import { app, auth, db, firebaseConfig } from "../config/firebase";
import { GoogleAuthProvider } from "firebase/auth";
import { getFunctions, connectFunctionsEmulator } from "firebase/functions";
import { initializeAppCheck, ReCaptchaV3Provider } from "firebase/app-check";

const firebaseRegion = import.meta.env.VITE_FIREBASE_REGION || "asia-southeast1";
const functions = getFunctions(app, firebaseRegion);

if (import.meta.env.DEV && import.meta.env.VITE_USE_EMULATOR === "true") {
  try {
    connectFunctionsEmulator(functions, "localhost", 5001);
  } catch (_err) {
    // ignore emulator connection failures (already connected, etc.)
    void _err;
  }
}

const googleProvider = new GoogleAuthProvider();

let appCheck = null;
if (typeof window !== "undefined" && import.meta.env.VITE_ENABLE_APPCHECK === "true") {
  const siteKey = import.meta.env.VITE_APPCHECK_SITE_KEY;
  if (siteKey) {
    try {
      appCheck = initializeAppCheck(app, {
        provider: new ReCaptchaV3Provider(siteKey),
        isTokenAutoRefreshEnabled: true,
      });
    } catch (_err) {
      // ignore duplicate appCheck initialization
      void _err;
    }
  } else if (import.meta.env.DEV) {
    console.warn("VITE_ENABLE_APPCHECK=true but VITE_APPCHECK_SITE_KEY is empty.");
  }
}

export { app, auth, db, functions, googleProvider, appCheck, firebaseConfig };
