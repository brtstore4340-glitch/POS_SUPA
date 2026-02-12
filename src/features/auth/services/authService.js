// src/features/auth/services/authService.js
import { supabase, isSupabaseConfigured, supabaseConfigError } from '../../../../supabase/client';

export const authService = {
  /**
   * Signs in a user with their email and password.
   * @param {string} email - The user's email.
   * @param {string} password - The user's password.
   * @returns {Promise<Object>} The session data.
   */
  async signIn(employeeId, password) {
    if (!employeeId || !password) {
      throw new Error("Employee ID and password are required.");
    }
    const syntheticEmail = `${employeeId}@boots-pos.local`;
    const { data, error } = await supabase.auth.signInWithPassword({
      email: syntheticEmail,
      password: password,
    });
    if (error) throw error;
    return data;
  },

  /**
   * Signs out the current user.
   * @returns {Promise<void>}
   */
  async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  },

  /**
   * Gets the current user session.
   * @returns {Promise<Object>} The session object.
   */
  async getSession() {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    return data.session;
  },

  /**
   * Signs in with Google OAuth.
   * @returns {Promise<Object>} The result of the sign-in attempt.
   */
  async signInWithGoogle() {
    if (!isSupabaseConfigured) {
      return { success: false, error: supabaseConfigError || "Supabase is not configured." };
    }

    const redirectTo = typeof window !== "undefined" ? window.location.origin : undefined;

    if (typeof supabase.auth?.signInWithOAuth === "function") {
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: redirectTo ? { redirectTo } : undefined,
      });
      if (error) return { success: false, error: error.message };
      return { success: true, data };
    }

    if (typeof supabase.auth?.signIn === "function") {
      const { data, error } = await supabase.auth.signIn(
        { provider: "google" },
        redirectTo ? { redirectTo } : undefined
      );
      if (error) return { success: false, error: error.message };
      return { success: true, data };
    }

    return { success: false, error: "Supabase auth client does not support OAuth sign-in." };
  },

  /**
   * Listens for changes in the authentication state.
   * @param {Function} callback - The function to call when the auth state changes.
   * @returns {Object} The subscription object.
   */
  onAuthStateChange(callback) {
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      callback(session);
    });
    return subscription;
  }
};
