// src/services/internal/storageService.js

/**
 * Storage Service
 * Encapsulates all interactions with localStorage to ensure
 * type safety and centralized management of side effects.
 */

const KEYS = {
  THEME: 'theme',
  POS_SEARCH_HITS: 'pos_search_hits',
  REMEMBERED_EMAIL: 'rememberedEmail',
  REMEMBERED_PASSWORD: 'rememberedPassword', // Note: Storing passwords is generally insecure; consider removing.
};

export const storageService = {
  // Generic getters/setters (internal use preferred, or specific methods below)
  getItem: (key) => {
    try {
      return localStorage.getItem(key);
    } catch (e) {
      console.warn(`Error reading ${key} from storage`, e);
      return null;
    }
  },
  
  setItem: (key, value) => {
    try {
      localStorage.setItem(key, value);
    } catch (e) {
      console.warn(`Error writing ${key} to storage`, e);
    }
  },

  removeItem: (key) => {
    try {
      localStorage.removeItem(key);
    } catch (e) {
      console.warn(`Error removing ${key} from storage`, e);
    }
  },

  // Specific Accessors
  getTheme: () => localStorage.getItem(KEYS.THEME),
  setTheme: (theme) => localStorage.setItem(KEYS.THEME, theme),

  getPosSearchHits: () => {
    try {
      return JSON.parse(localStorage.getItem(KEYS.POS_SEARCH_HITS) || "{}");
    } catch {
      return {};
    }
  },
  setPosSearchHits: (hits) => {
    try {
      localStorage.setItem(KEYS.POS_SEARCH_HITS, JSON.stringify(hits));
    } catch (e) {
      console.warn("Failed to save search hits", e);
    }
  },

  getRememberedEmail: () => localStorage.getItem(KEYS.REMEMBERED_EMAIL),
  setRememberedEmail: (email) => localStorage.setItem(KEYS.REMEMBERED_EMAIL, email),
  
  // Warning: Insecure
  getRememberedPassword: () => localStorage.getItem(KEYS.REMEMBERED_PASSWORD),
  setRememberedPassword: (pw) => localStorage.setItem(KEYS.REMEMBERED_PASSWORD, pw),
  
  clearCredentials: () => {
    localStorage.removeItem(KEYS.REMEMBERED_EMAIL);
    localStorage.removeItem(KEYS.REMEMBERED_PASSWORD);
  }
};
