// src/services/menuService.js
import { supabase } from '../../supabase/client';

/**
 * Fetches dynamic menu items from the 'ui_menus' table.
 * @returns {Promise<Array>} A promise that resolves to an array of menu items.
 */
export async function fetchMenus() {
  try {
    const { data, error } = await supabase
      .from('ui_menus')
      .select('*')
      .order('order', { ascending: true });

    if (error) {
      console.error('Error fetching menus:', error);
      return [];
    }

    return data;
  } catch (error) {
    console.error('An unexpected error occurred while fetching menus:', error);
    return [];
  }
}
