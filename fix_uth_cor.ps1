import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  useMemo,
} from "react";
import { auth, db } from "../config/firebase";
import { onAuthStateChanged, signOut as firebaseSignOut } from "firebase/auth";
import { collection, query, where, getDocs, doc, getDoc } from "firebase/firestore";

const AuthContext = createContext(undefined);

export const AuthProvider = ({ children }) => {
  const [firebaseUser, setFirebaseUser] = useState(null);
  const [session, setSession] = useState(null);
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

  // Load user IDs
  const loadUserIds = useCallback(async (userId) => {
    if (!userId) {
      setIds([]);
      return;
    }

    try {
      const q = query(
        collection(db, "ids"),
        where("userId", "==", userId)
      );
      const snapshot = await getDocs(q);
      const userIds = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setIds(userIds);
      console.log("✅ Loaded user IDs:", userIds.length);
    } catch (error) {
      console.error("❌ Failed to load user IDs:", error);
      setIds([]);
    }
  }, []);

  // Verify PIN
  const verifyPin = useCallback(async (idCode, pin) => {
    try {
      if (!idCode || !pin) {
        throw new Error("ID Code and PIN are required");
      }

      const idDoc = await getDoc(doc(db, "ids", idCode));
      
      if (!idDoc.exists()) {
        throw new Error("Invalid ID Code");
      }

      const data = idDoc.data();
      
      if (data.pin !== pin) {
        throw new Error("Invalid PIN");
      }

      if (data.status !== "active") {
        throw new Error("This ID is not active");
      }

      // Set session
      const sessionData = {
        idCode,
        role: data.role,
        displayName: data.displayName || idCode,
        userId: data.userId,
        menus: data.menus || [],
      };

      setSession(sessionData);
      setLastIdCode(idCode);
      
      console.log("✅ PIN verified, session created:", sessionData);
      return { success: true, session: sessionData };
    } catch (error) {
      console.error("❌ PIN verification failed:", error);
      return { success: false, error: error.message };
    }
  }, [setLastIdCode]);

  // Sign out
  const signOut = useCallback(async () => {
    try {
      await firebaseSignOut(auth);
      setSession(null);
      setIds([]);
      setLastIdCode("");
      console.log("✅ Signed out successfully");
    } catch (error) {
      console.error("❌ Sign out error:", error);
      throw error;
    }
  }, [setLastIdCode]);

  // Clear session (logout from ID but keep Firebase auth)
  const clearSession = useCallback(() => {
    setSession(null);
    console.log("ℹ️ Session cleared");
  }, []);

  // Initialize auth listener
  useEffect(() => {
    let mounted = true;
    
    const unsubscribe = onAuthStateChanged(
      auth,
      async (user) => {
        if (!mounted) return;
        
        try {
          setFirebaseUser(user);
          setAuthError(null);
          
          if (user) {
            console.log("✅ User authenticated:", user.email);
            await loadUserIds(user.uid);
          } else {
            console.log("ℹ️ No user authenticated");
            setSession(null);
            setIds([]);
          }
        } catch (error) {
          console.error("❌ Error in auth state change:", error);
          setAuthError(error);
        } finally {
          if (mounted) {
            setAuthLoading(false);
          }
        }
      },
      (error) => {
        if (!mounted) return;
        
        console.error("❌ Auth state change error:", error);
        setAuthError(error);
        setAuthLoading(false);
      }
    );

    return () => {
      mounted = false;
      unsubscribe();
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
          รีโหลดหน้า
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