import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID
};

// Validate
const requiredKeys = ['apiKey', 'authDomain', 'projectId', 'storageBucket', 'messagingSenderId', 'appId'];
const missingKeys = requiredKeys.filter(key => !firebaseConfig[key]);

if (missingKeys.length > 0) {
  const errorMsg = `Missing Firebase config: ${missingKeys.join(', ')}`;
  console.error('❌', errorMsg);
  throw new Error(errorMsg);
}

console.log('Firebase Config Debug:', {
  projectId: firebaseConfig.projectId,
  authDomain: firebaseConfig.authDomain,
  hasApiKey: !!firebaseConfig.apiKey,
  region: 'asia-southeast1',
  enableAppCheck: import.meta.env.VITE_ENABLE_APPCHECK === 'true'
});

if (import.meta.env.VITE_ENABLE_APPCHECK !== 'true') {
  console.warn('⚠️ App Check is disabled (VITE_ENABLE_APPCHECK=false).');
}

let app;
let auth;
let db;

try {
  // Initialize Firebase
  app = initializeApp(firebaseConfig);
  
  // Initialize Auth
  auth = getAuth(app);
  
  // Initialize Firestore
  db = getFirestore(app);
  
  console.log('✅ Firebase initialized successfully');
  
  // เชื่อมต่อกับ Emulator (ถ้าอยู่ใน development)
  if (import.meta.env.DEV && import.meta.env.VITE_USE_EMULATOR === 'true') {
    console.log('🔧 Connecting to Firebase Emulators...');
    connectAuthEmulator(auth, 'http://localhost:9099');
    connectFirestoreEmulator(db, 'localhost', 8080);
  }
  
} catch (error) {
  console.error('❌ Firebase initialization error:', error);
  console.error('Error details:', {
    code: error.code,
    message: error.message,
    stack: error.stack
  });
  throw error;
}

export { app, auth, db };