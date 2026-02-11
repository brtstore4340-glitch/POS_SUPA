import React, { useState, useEffect } from 'react';
import { productService } from '../services/productService';
import { toast } from 'react-hot-toast'; // Assuming react-hot-toast for feedback
import { useNavigate } from 'react-router-dom';

export const ProductFormPage = () => {
  const [formData, setFormData] = useState({
    sku: '',
    name: '',
    description: '',
    price: '',
    category_id: '',
    brand: '',
    cost_price: '',
    is_active: true,
    barcode: [],
  });
  const [categories, setCategories] = useState([]);
  const [loadingCategories, setLoadingCategories] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const fetchedCategories = await productService.listCategories();
        setCategories(fetchedCategories);
      } catch (err) {
        toast.error('Failed to load categories.');
      } finally {
        setLoadingCategories(false);
      }
    };
    fetchCategories();
  }, []);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const productToCreate = {
        ...formData,
        price: parseFloat(formData.price),
        cost_price: parseFloat(formData.cost_price),
        category_id: parseInt(formData.category_id, 10),
        // barcode is an array, ensure it's handled correctly if input is string
        barcode: formData.barcode.length > 0 ? formData.barcode.split(',').map(s => s.trim()) : [],
      };
      await toast.promise(productService.createProduct(productToCreate), {
        loading: 'Creating product...',
        success: 'Product created successfully!',
        error: 'Failed to create product.',
      });
      navigate('/products'); // Redirect to product list after creation
    } catch (error) {
      console.error('Error submitting form:', error);
    }
  };

  if (loadingCategories) return <div>Loading categories...</div>;

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">Create New Product</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="name" className="block text-sm font-medium text-gray-700">Name</label>
          <input type="text" name="name" id="name" value={formData.name} onChange={handleChange} required
                 className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2" />
        </div>
        <div>
          <label htmlFor="sku" className="block text-sm font-medium text-gray-700">SKU</label>
          <input type="text" name="sku" id="sku" value={formData.sku} onChange={handleChange} required
                 className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2" />
        </div>
        <div>
          <label htmlFor="description" className="block text-sm font-medium text-gray-700">Description</label>
          <textarea name="description" id="description" value={formData.description} onChange={handleChange}
                    className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"></textarea>
        </div>
        <div>
          <label htmlFor="price" className="block text-sm font-medium text-gray-700">Price</label>
          <input type="number" name="price" id="price" value={formData.price} onChange={handleChange} required step="0.01"
                 className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2" />
        </div>
        <div>
          <label htmlFor="cost_price" className="block text-sm font-medium text-gray-700">Cost Price</label>
          <input type="number" name="cost_price" id="cost_price" value={formData.cost_price} onChange={handleChange} step="0.01"
                 className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2" />
        </div>
        <div>
          <label htmlFor="brand" className="block text-sm font-medium text-gray-700">Brand</label>
          <input type="text" name="brand" id="brand" value={formData.brand} onChange={handleChange}
                 className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2" />
        </div>
        <div>
          <label htmlFor="category_id" className="block text-sm font-medium text-gray-700">Category</label>
          <select name="category_id" id="category_id" value={formData.category_id} onChange={handleChange} required
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2">
            <option value="">Select a Category</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="barcode" className="block text-sm font-medium text-gray-700">Barcode (comma-separated)</label>
          <input type="text" name="barcode" id="barcode" value={formData.barcode} onChange={handleChange}
                 className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2" />
        </div>
        <div className="flex items-center">
          <input type="checkbox" name="is_active" id="is_active" checked={formData.is_active} onChange={handleChange}
                 className="h-4 w-4 text-indigo-600 border-gray-300 rounded" />
          <label htmlFor="is_active" className="ml-2 block text-sm text-gray-900">Is Active</label>
        </div>
        <button type="submit" className="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600">
          Create Product
        </button>
      </form>
    </div>
  );
};

// export default ProductFormPage;
