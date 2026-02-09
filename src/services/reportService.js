// src/services/reportService.js
import { supabase } from '../../supabase/client';

export const reportService = {
  /**
   * Fetches the daily sales summary for a given date.
   * @param {string} date - The date in 'YYYY-MM-DD' format.
   * @returns {Promise<Object>} The sales summary.
   */
  async getDailySalesSummary(date) {
    if (!date) {
      throw new Error("Date is required.");
    }
    const { data, error } = await supabase.rpc('get_daily_sales_summary', { p_date: date });
    if (error) throw error;
    return data;
  }
};
