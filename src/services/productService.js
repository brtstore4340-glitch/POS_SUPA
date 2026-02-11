import { supabase } from '../../supabase/client';

export const productService = {
  /**
   * Creates a new product using a Supabase RPC.
   * @param {object} product_data - The product data.
   * @returns {Promise<object>} The created product's ID and a message.
   */
  async createProduct(product_data) {
    try {
      console.log('productService: Attempting to create product with data:', product_data);
      const { data, error } = await supabase.rpc('rpc_create_product', { product_data });
      if (error) {
        console.error('productService: Error creating product:', error.message);
        throw error;
      }
      console.log('productService: Product created successfully:', data);
      return data;
    } catch (error) {
      console.error('productService: Uncaught error creating product:', error.message);
      throw error;
    }
  },

  async listProducts(filters = {}) {
    try {
      console.log('productService: Attempting to list products with filters:', filters);
      const { q, category_id, is_active, limit = 10, offset = 0 } = filters;

      let query = supabase.from('products').select('*', { count: 'exact' });

      if (q) {
        query = query.or(`name.ilike.%${q}%,sku.ilike.%${q}%,brand.ilike.%${q}%`);
      }
      if (category_id) {
        query = query.eq('category_id', category_id);
      }
      if (is_active !== undefined) {
        query = query.eq('is_active', is_active);
      }

      query = query.range(offset, offset + limit - 1);

      const { data, error, count } = await query;
      if (error) {
        console.error('productService: Error listing products:', error.message);
        throw error;
      }
      console.log('productService: Products listed successfully. Count:', count, 'Data:', data);
      return { products: data, total_count: count };

    } catch (error) {
      console.error('productService: Uncaught error listing products:', error.message);
      throw error;
    }
  },

  async getProductById(product_id) {
    try {
      console.log('productService: Attempting to get product by ID:', product_id);
      const { data, error } = await supabase.from('products').select('*').eq('id', product_id).single();
      if (error && error.code !== 'PGRST116') {
        console.error('productService: Error getting product by ID:', error.message);
        throw error;
      }
      console.log('productService: Product by ID fetched:', data);
      return data;
    } catch (error) {
      console.error('productService: Uncaught error getting product by ID:', error.message);
      throw error;
    }
  },

  async listCategories() {
    try {
      console.log('productService: Attempting to list categories');
      const { data, error } = await supabase.from('categories').select('id, name');
      if (error) {
        console.error('productService: Error listing categories:', error.message);
        throw error;
      }
      console.log('productService: Categories listed successfully:', data);
      return data;
    } catch (error) {
      console.error('productService: Uncaught error listing categories:', error.message);
      throw error;
    }
  },
};
