import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  useMemo,
} from "react";
// Note: These Firebase imports are now replaced by Supabase services.
// import { auth, db } from "../config/firebase";
// import { onAuthStateChanged, signOut as firebaseSignOut } from "firebase/auth";
// import { collection, query, where, getDocs, doc, getDoc } from "firebase/firestore";
import { rbacService } from "../services/rbacService"; // For PIN verification
import { authService } from "../features/auth/services/authService"; // For auth state

const AuthContext = createContext(undefined);

export const AuthProvider = ({ children }) => {
  const [firebaseUser, setFirebaseUser] = useState(null); // This now represents the Supabase user
  const [session, setSession] = useState(null); // This is the PIN-verified session
  const [ids, setIds] = useState([]);
  const [authLoading, setAuthLoading] = useState(true);
  const [authError, setAuthError] = useState(null);
  const [lastIdCode, _setLastIdCode] = useState(() => {
    try {
      return localStorage.getItem("lastIdCode") || "";
    } catch (error) {
      console.error("Failed to read lastIdCode:", error);
      return "";
    }
  });

  const setLastIdCode = useCallback((code) => {
    try {
      localStorage.setItem("lastIdCode", code || "");
      _setLastIdCode(code);
    } catch (error) {
      console.error("Failed to save lastIdCode:", error);
    }
  }, []);

  // Load user IDs/profiles
  const loadUserIds = useCallback(async (user) => {
    if (!user) {
      setIds([]);
      return;
    }
    try {
      // Using rbacService which should call a Supabase function
      const userIds = await rbacService.listMyIds();
      setIds(userIds);
      console.log("✅ Loaded user IDs:", userIds.length);
    } catch (error) {
      console.error("❌ Failed to load user IDs:", error);
      setIds([]);
    }
  }, []);

  // Verify PIN securely via server-side function
  const verifyPin = useCallback(async (idCode, pin) => {
    try {
      if (!idCode || !pin) {
        throw new Error("ID Code and PIN are required");
      }
      
      // Call the secure Supabase Edge Function
      const sessionData = await rbacService.verifyIdPin({ idCode, pin });

      if (!sessionData) {
        // Use a generic error message for security
        throw new Error("Invalid credentials");
      }

      setSession(sessionData);
      setLastIdCode(idCode);
      
      console.log("✅ PIN verified, session created:", sessionData);
      return { success: true, session: sessionData };
    } catch (error) {
      console.error("❌ PIN verification failed:", error);
      // Surface only the generic error message
      return { success: false, error: "Invalid credentials" };
    }
  }, [setLastIdCode]);

  // Sign out
  const signOut = useCallback(async () => {
    try {
      await authService.signOut();
      setSession(null);
      setIds([]);
      setLastIdCode("");
      console.log("✅ Signed out successfully");
    } catch (error) {
      console.error("❌ Sign out error:", error);
      throw error;
    }
  }, [setLastIdCode]);

  // Clear session (logout from ID but keep Supabase auth)
  const clearSession = useCallback(() => {
    setSession(null);
    console.log("ℹ️ Session cleared");
  }, []);

  // Initialize auth listener for Supabase
  useEffect(() => {
    setAuthLoading(true);
    const subscription = authService.onAuthStateChange(async (session) => {
      try {
        const user = session?.user ?? null;
        setFirebaseUser(user);
        setAuthError(null);

        if (user) {
          console.log("✅ User authenticated:", user.email);
          await loadUserIds(user);
        } else {
          console.log("ℹ️ No user authenticated");
          setSession(null);
          setIds([]);
        }
      } catch (error) {
        console.error("❌ Error in auth state change:", error);
        setAuthError(error);
      } finally {
        setAuthLoading(false);
      }
    });

    return () => {
      if (subscription && typeof subscription.unsubscribe === 'function') {
        subscription.unsubscribe();
      }
    };
  }, [loadUserIds]);

  const value = useMemo(() => ({
    firebaseUser,
    session,
    ids,
    authLoading,
    authError,
    lastIdCode,
    setLastIdCode,
    setSession,
    setIds,
    verifyPin,
    signOut,
    clearSession,
    loadUserIds,
  }), [
    firebaseUser,
    session,
    ids,
    authLoading,
    authError,
    lastIdCode,
    setLastIdCode,
    verifyPin,
    signOut,
    clearSession,
    loadUserIds,
  ]);

  // Return a loading state while checking authentication.
  if (authLoading) {
    return null; // Or a loading spinner component
  }
  
  // Show error state if auth initialization failed
  if (authError && !firebaseUser) {
    return (
      <div style={{ 
        padding: "40px", 
        textAlign: "center",
        fontFamily: "system-ui, -apple-system, sans-serif" 
      }}>
        <h2 style={{ color: "#dc2626", marginBottom: "16px" }}>
          🔴 Authentication Error
        </h2>
        <p style={{ color: "#6b7280", marginBottom: "24px" }}>
          {authError.message}
        </p>
        <button 
          onClick={() => window.location.reload()}
          style={{
            padding: "12px 24px",
            backgroundColor: "#3b82f6",
            color: "white",
            border: "none",
            borderRadius: "6px",
            fontSize: "16px",
            cursor: "pointer"
          }}
        >
          {/* Replaced with a placeholder for i18n */}
          {"Reload Page"}
        </button>
      </div>
    );
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return context;
};

export default AuthContext;
