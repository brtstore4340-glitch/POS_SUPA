import React, { useEffect, useState } from 'react';
import { productService } from '../services/productService';
import { toast } from 'react-hot-toast'; // Assuming react-hot-toast for feedback

export const ProductListPage = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        const { products: fetchedProducts } = await productService.listProducts();
        setProducts(fetchedProducts);
      } catch (err) {
        setError(err);
        toast.error('Failed to load products.');
      } finally {
        setLoading(false);
      }
    };
    fetchProducts();
  }, []);

  if (loading) return <div>Loading products...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">Product List</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {products.map((product) => (
          <div key={product.id} className="border p-4 rounded shadow">
            <h2 className="text-xl font-semibold">{product.name}</h2>
            <p>SKU: {product.sku}</p>
            <p>Price: ${product.price}</p>
            {/* Add more product details here as needed */}
          </div>
        ))}
      </div>
    </div>
  );
};

// export default ProductListPage;
