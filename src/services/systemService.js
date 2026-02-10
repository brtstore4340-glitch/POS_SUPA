// src/services/systemService.js
import { supabase } from '../../supabase/client';

export const systemService = {
  /**
   * Checks the connection to Supabase.
   * @returns {Promise<{ status: 'connected' | 'disconnected', error?: any }>}
   */
  checkConnection: async () => {
    try {
      // Perform a lightweight query
      const { error } = await supabase.from('profiles').select('id').limit(1);
      
      if (error && error.message !== 'JWT expired') {
        throw error;
      }
      
      return { status: 'connected' };
    } catch (error) {
      console.error("System health check failed:", error);
      return { status: 'disconnected', error };
    }
  }
};
