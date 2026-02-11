// src/services/authService.js
import { supabase } from '../../supabase/client';

export const signInWithEmployeeId = async (employeeId, password) => {
  const syntheticEmail = `${employeeId}@boots-pos.local`;
  const { data, error } = await supabase.auth.signInWithPassword({
    email: syntheticEmail,
    password: password,
  });

  if (error) {
    throw error;
  }
  return data;
};

export const signOut = async () => {
  const { error } = await supabase.auth.signOut();
  if (error) {
    throw error;
  }
};

export const resetPassword = async (email) => {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/reset-password`, // Redirect to a page where user can set new password
  });
  if (error) {
    throw error;
  }
  return { success: true };
};

export const updatePassword = async (newPassword) => {
  const { data, error } = await supabase.auth.updateUser({ password: newPassword });
  if (error) {
    throw error;
  }
  return data;
};

export const getSession = async () => {
  const { data, error } = await supabase.auth.getSession();
  if (error) {
    throw error;
  }
  return data.session;
};

export const getUser = async () => {
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error) {
    throw error;
  }
  return user;
};
