// src/services/posService.js
import { supabase } from '../../supabase/client';

async function invoke(functionName, payload) {
  const { data, error } = await supabase.functions.invoke(functionName, {
    body: payload,
  });
  if (error) throw error;
  return data;
}

export const posService = {
  calculateOrder: async (payload) => {
    return invoke('calculate-order', payload);
  },

  hasMasterData: async () => {
    // Check if we have any products
    const { count } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true });
    return (count || 0) > 0;
  },

  uploadProductAllDept: async () => {
    throw new Error("Excel/CSV upload is currently disabled for security.");
  },
  
  uploadExcelUpdate: async () => {
    throw new Error("Excel/CSV upload is currently disabled for security.");
  },
  
  getProductStats: async () => {
    const { count } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true });
    return { count: count || 0, lastUpdated: new Date(), uploads: {} };
  },

  searchProducts: async (keyword) => {
    if (!keyword) return [];
    return invoke('search-products', { keyword });
  },

  scanItem: async (keyword) => {
    if (!keyword) throw new Error("Barcode required");
    const data = await invoke('scan-item', { barcode: keyword });
    if (!data) throw new Error("Product not found");
    return data;
  },

  createOrder: async (orderData) => {
    // Save to 'carts' table with status 'completed'
    const { data: cart, error: cartError } = await supabase
        .from('carts')
        .insert({
            status: 'completed',
            total_price: orderData.summary.grandTotal
        })
        .select()
        .single();
    
    if (cartError) throw cartError;

    // Save items
    const itemsToInsert = orderData.items.map(item => ({
        cart_id: cart.id,
        product_id: item.id || item.sku, // Assuming id matches DB id
        quantity: item.qty
    }));

    // Note: This relies on product_id being the BIGINT id from DB. 
    // If frontend uses SKU string as ID, this will fail.
    // For now, we assume frontend has the numeric ID from search/scan results.

    const { error: itemsError } = await supabase
        .from('cart_items')
        .insert(itemsToInsert);

    if (itemsError) throw itemsError;

    return cart.id;
  },

  getLastDBUpdate: async () => {
    return new Date();
  }
};




