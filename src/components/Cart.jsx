// src/components/Cart.jsx
import React from 'react';
import { useCart } from '../hooks/useCart';
import { Button } from './ui/button';
import { Trash2, PlusCircle, MinusCircle } from 'lucide-react';

export default function Cart() {
  const {
    cartItems,
    summary,
    addToCart,
    decreaseItem,
    removeFromCart,
    clearCart,
  } = useCart();

  if (cartItems.length === 0) {
    return (
      <div className="p-4 text-center text-gray-500">
        <p>Your cart is empty.</p>
      </div>
    );
  }

  return (
    <div className="p-4 bg-white rounded-lg shadow-md">
      <h2 className="text-xl font-bold mb-4">Shopping Cart</h2>
      
      <div className="mb-4">
        {cartItems.map(item => (
          <div key={item.sku || item.id} className="flex items-center justify-between py-2 border-b">
            <div>
              <p className="font-semibold">{item.name}</p>
              <p className="text-sm text-gray-600">฿{item.price?.toFixed(2)}</p>
            </div>
            <div className="flex items-center gap-2">
              <Button variant="ghost" size="icon" onClick={() => decreaseItem(item.sku || item.id)}>
                <MinusCircle className="h-4 w-4" />
              </Button>
              <span>{item.qty}</span>
              <Button variant="ghost" size="icon" onClick={() => addToCart(item)}>
                <PlusCircle className="h-4 w-4" />
              </Button>
              <Button variant="ghost" size="icon" className="text-red-500" onClick={() => removeFromCart(item.sku || item.id)}>
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          </div>
        ))}
      </div>

      <div className="space-y-2">
        <div className="flex justify-between">
          <span>Subtotal:</span>
          <span>฿{summary?.subTotal?.toFixed(2)}</span>
        </div>
        <div className="flex justify-between text-red-600">
          <span>Discount:</span>
          <span>-฿{summary?.totalDiscount?.toFixed(2)}</span>
        </div>
        <div className="flex justify-between font-bold text-lg">
          <span>Grand Total:</span>
          <span>฿{summary?.grandTotal?.toFixed(2)}</span>
        </div>
      </div>

      <Button className="w-full mt-4" onClick={() => alert('Checkout functionality to be implemented.')}>
        Proceed to Checkout
      </Button>
      <Button variant="outline" className="w-full mt-2" onClick={clearCart}>
        Clear Cart
      </Button>
    </div>
  );
}
