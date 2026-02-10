# Supabase Backend Contract

## 1. Database Schema
(Existing migrations are assumed sufficient for `products` and `ui_menus`. No new tables required for Phase 1.)

## 2. Row Level Security (RLS)
-   **Strict Default Deny:** All tables must have RLS enabled.
-   **Public Access:** `ui_menus` (read-only for authenticated), `products` (read-only for authenticated).
-   **Service Access:** Edge Functions will use `service_role` key to bypass RLS for complex logic (e.g., inventory deduction).

## 3. Edge Functions Contract

### 3.1 `search-products`
-   **Method:** POST
-   **Input:** `{ "keyword": string }`
-   **Output:** `Array<Product>`
-   **Logic:**
    -   Perform text search on `products` table (name, sku, barcode).
    -   Filter by `is_active = true`.
    -   Return top 20 matches.

### 3.2 `scan-item`
-   **Method:** POST
-   **Input:** `{ "barcode": string }`
-   **Output:** `Product | null`
-   **Logic:**
    -   Exact match on `sku` OR `barcode` (array contains).
    -   Return single product or null.

### 3.3 `calculate-order`
-   **Method:** POST
-   **Input:**
    ```json
    {
      "items": [{ "id": string, "qty": number, "price": number }],
      "discounts": [{ "type": "bill" | "item", "value": number }]
    }
    ```
-   **Output:**
    ```json
    {
      "subtotal": number,
      "totalDiscount": number,
      "grandTotal": number,
      "items": Array<CalculatedItem>
    }
    ```
-   **Logic:**
    -   (Server-side calculation prevents client tampering)
    -   Validate item prices against DB.
    -   Apply discount logic.
    -   Return final totals.
