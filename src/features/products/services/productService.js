import { supabase } from '../../../../supabase/client';

export const productService = {
  async listProducts({ q = "", category } = {}) {
    try {
      let query = supabase
        .from('products')
        .select('*')
        .eq('is_active', true);

      if (category && category !== "All") {
        query = query.eq('category', category);
      }

      if (q) {
        query = query.or(`name.ilike.%${q}%,sku.ilike.%${q}%`);
      }

      const { data, error } = await query.order('name', { ascending: true });

      if (error) {
        console.error('Error fetching products:', error);
        return { items: [] };
      }

      return { items: data };
    } catch (error) {
      console.error('An unexpected error occurred while fetching products:', error);
      return { items: [] };
    }
  },

  async getProductByBarcode(barcode) {
    const code = String(barcode || "").trim();
    if (!code) return null;

    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .contains('barcode', [code])
        .limit(1)
        .single();

      if (error) {
        // .single() throws an error if no row is found, which is expected.
        // We only log if it's not a "not found" error.
        if (!error.message.includes('No rows found')) {
            console.error('Error fetching product by barcode:', error);
        }
        return null;
      }

      return data;
    } catch (error) {
        console.error('An unexpected error occurred:', error);
        return null;
    }
  },

  async upsertProduct(product) {
    try {
      const { data, error } = await supabase
        .from('products')
        .upsert(product)
        .select()
        .single();

      if (error) {
        console.error('Error upserting product:', error);
        return { ok: false, error };
      }

      return { ok: true, product: data };
    } catch (error) {
        console.error('An unexpected error occurred:', error);
        return { ok: false, error };
    }
  },

  async listCategories() {
    try {
        const { data, error } = await supabase.rpc('get_distinct_categories');

        if (error) {
            console.error('Error fetching categories:', error);
            return ["All"];
        }

        return ["All", ...data.sort()];
    } catch(error) {
        console.error('An unexpected error occurred:', error);
        return ["All"];
    }
  }
};
