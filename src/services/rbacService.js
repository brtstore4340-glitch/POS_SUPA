// src/services/rbacService.js
import { supabase } from '../../supabase/client';

/**
 * Invokes a Supabase Edge Function.
 * @param {string} functionName - The name of the function to invoke.
 * @param {Object} payload - The payload to send to the function.
 * @returns {Promise<Object>} The data returned from the function.
 */
async function invokeFunction(functionName, payload) {
  const { data, error } = await supabase.functions.invoke(functionName, {
    body: payload,
  });
  if (error) throw error;
  return data;
}

export const rbacService = {
  async listMyIds() {
    return invokeFunction('listMyIds');
  },

  async verifyIdPin(payload) {
    return invokeFunction('verifyIdPin', payload);
  },

  async createId(payload) {
    return invokeFunction('createId', payload);
  },

  async updateId(payload) {
    return invokeFunction('updateId', payload);
  },

  async resetPin(payload) {
    return invokeFunction('resetPin', payload);
  },

  async setPin(payload) {
    return invokeFunction('setPin', payload);
  },

  async searchIds(payload) {
    return invokeFunction('searchIds', payload);
  },

  async getAuditLogs(payload) {
    return invokeFunction('getAuditLogs', payload);
  }
};



