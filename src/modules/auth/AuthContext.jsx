/* eslint-disable react-refresh/only-export-components */
import React, { createContext, useCallback, useContext, useEffect, useState } from "react";
import { authService } from '../../features/auth/services/authService';
import { rbacService } from '../../services/rbacService'; // Assuming you have this service for PIN/profile logic

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  
  // New state for multi-step auth
  const [profiles, setProfiles] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState(null);

  // Effect to handle session and user state from Supabase auth
  useEffect(() => {
    const checkSession = async () => {
      try {
        const currentSession = await authService.getSession();
        setSession(currentSession);
        setUser(currentSession?.user ?? null);
        if (currentSession?.user) {
          // If user is logged in, fetch their profiles
          const userProfiles = await rbacService.listMyIds();
          setProfiles(userProfiles);
        }
      } catch (error) {
        console.error("Error getting session:", error);
      } finally {
        setLoading(false);
      }
    };

    checkSession();

    const subscription = authService.onAuthStateChange((newSession) => {
      setSession(newSession);
      setUser(newSession?.user ?? null);
      if (!newSession) {
        // Clear profiles on logout
        setProfiles([]);
        setSelectedProfile(null);
      }
      if (loading) setLoading(false);
    });

    return () => {
      if (subscription && typeof subscription.unsubscribe === 'function') {
        subscription.unsubscribe();
      }
    };
  }, [loading]);

  const login = useCallback(async (email, password) => {
    const sessionData = await authService.signIn(email, password);
    if (sessionData.user) {
        // After login, fetch user profiles (IDs)
        const userProfiles = await rbacService.listMyIds();
        setProfiles(userProfiles);
    }
    return sessionData;
  }, []);

  const logout = useCallback(async () => {
    await authService.signOut();
    setSelectedProfile(null);
    setProfiles([]);
  }, []);

  const verifyPin = useCallback(async (idCode, pin) => {
    // This function will likely need to call a Supabase Edge Function
    // via rbacService to verify the PIN securely without exposing hashes to the client.
    try {
        const verifiedProfile = await rbacService.verifyIdPin({ idCode, pin });
        if (verifiedProfile) {
            setSelectedProfile(verifiedProfile);
            return true;
        }
        return false;
    } catch (error) {
        console.error("PIN verification failed:", error);
        return false;
    }
  }, []);

  const value = {
    session,
    user,
    loading,
    login,
    logout,
    profiles,
    selectedProfile,
    setSelectedProfile,
    verifyPin,
  };

  return <AuthContext.Provider value={value}>{!loading && children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within <AuthProvider />");
  }
  return ctx;
}
