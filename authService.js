import { auth } from './src/firebase/config.js';
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  updatePassword,
  sendPasswordResetEmail
} from 'firebase/auth';

// Password validation constants
const MIN_PASSWORD_LENGTH = 8;
const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/;

/**
 * Validate password strength
 * @param {string} password - Password to validate
 * @returns {Object} { isValid: boolean, errors: string[] }
 */
export function validatePassword(password) {
  const errors = [];
  
  if (!password) {
    errors.push('Password is required');
    return { isValid: false, errors };
  }
  
  if (password.length < MIN_PASSWORD_LENGTH) {
    errors.push(`Password must be at least ${MIN_PASSWORD_LENGTH} characters long`);
  }
  
  if (!PASSWORD_REGEX.test(password)) {
    errors.push('Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character (@$!%*?&)');
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Sign in with email and password
 * @param {string} email - User email
 * @param {string} password - User password
 * @returns {Promise<Object>} { success: boolean, user?: object, error?: string }
 */
export async function signIn(email, password) {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    return { success: true, user: userCredential.user };
  } catch (error) {
    let errorMessage = 'Failed to sign in';
    
    switch (error.code) {
      case 'auth/user-not-found':
        errorMessage = 'No account found with this email';
        break;
      case 'auth/wrong-password':
        errorMessage = 'Incorrect password';
        break;
      case 'auth/invalid-email':
        errorMessage = 'Invalid email address';
        break;
      case 'auth/user-disabled':
        errorMessage = 'This account has been disabled';
        break;
      case 'auth/too-many-requests':
        errorMessage = 'Too many failed attempts. Please try again later';
        break;
      default:
        errorMessage = error.message;
    }
    
    return { success: false, error: errorMessage };
  }
}

/**
 * Sign up with email and password
 * @param {string} email - User email
 * @param {string} password - User password
 * @param {string} displayName - User display name (optional)
 * @returns {Promise<Object>} { success: boolean, user?: object, error?: string }
 */
export async function signUp(email, password, displayName) {
  // Validate password first
  const passwordValidation = validatePassword(password);
  if (!passwordValidation.isValid) {
    return {
      success: false,
      error: passwordValidation.errors.join('. ')
    };
  }
  
  try {
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    
    // Update display name if provided
    if (displayName && userCredential.user) {
      await userCredential.user.updateProfile({ displayName });
    }
    
    return { success: true, user: userCredential.user };
  } catch (error) {
    let errorMessage = 'Failed to create account';
    
    switch (error.code) {
      case 'auth/email-already-in-use':
        errorMessage = 'An account with this email already exists';
        break;
      case 'auth/invalid-email':
        errorMessage = 'Invalid email address';
        break;
      case 'auth/weak-password':
        errorMessage = 'Password is too weak';
        break;
      default:
        errorMessage = error.message;
    }
    
    return { success: false, error: errorMessage };
  }
}

/**
 * Change password for current user
 * @param {string} newPassword - New password
 * @returns {Promise<Object>} { success: boolean, error?: string }
 */
export async function changePassword(newPassword) {
  const passwordValidation = validatePassword(newPassword);
  if (!passwordValidation.isValid) {
    return {
      success: false,
      error: passwordValidation.errors.join('. ')
    };
  }
  
  try {
    const user = auth.currentUser;
    if (!user) {
      return { success: false, error: 'No user is currently signed in' };
    }
    
    await updatePassword(user, newPassword);
    return { success: true };
  } catch (error) {
    let errorMessage = 'Failed to change password';
    
    switch (error.code) {
      case 'auth/requires-recent-login':
        errorMessage = 'Please sign in again before changing your password';
        break;
      case 'auth/weak-password':
        errorMessage = 'Password is too weak';
        break;
      default:
        errorMessage = error.message;
    }
    
    return { success: false, error: errorMessage };
  }
}

/**
 * Send password reset email
 * @param {string} email - User email
 * @returns {Promise<Object>} { success: boolean, error?: string }
 */
export async function resetPassword(email) {
  try {
    await sendPasswordResetEmail(auth, email);
    return { success: true };
  } catch (error) {
    let errorMessage = 'Failed to send password reset email';
    
    switch (error.code) {
      case 'auth/user-not-found':
        errorMessage = 'No account found with this email';
        break;
      case 'auth/invalid-email':
        errorMessage = 'Invalid email address';
        break;
      default:
        errorMessage = error.message;
    }
    
    return { success: false, error: errorMessage };
  }
}
 
/**
 * Sign out current user
 * @returns {Promise<Object>} { success: boolean, error?: string }
 */
export async function logOut() {
  try {
    await signOut(auth);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}
 
/**
 * Subscribe to auth state changes
 * @param {Function} callback - Callback function to handle auth state changes
 * @returns {Function} Unsubscribe function
 */
export function onAuthStateChange(callback) {
  return onAuthStateChanged(auth, callback);
}

/**
 * Get current user
 * @returns {Object|null} Current user or null
 */
export function getCurrentUser() {
  return auth.currentUser;
}
