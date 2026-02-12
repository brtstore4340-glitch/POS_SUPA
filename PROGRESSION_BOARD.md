# Boots-POS Gemini Progression Board

**Current Phase:** Phase 2 - Core POS Features
**Status:** 🟢 Scaffold Ready / In Active Development
**Last Updated:** 2026-02-12

---

## 🚀 High-Level Milestones

| Milestone | Status | Description |
| :--- | :---: | :--- |
| **M1: Stabilization** | ✅ **Done** | Repo cleanup, Auth 1:N fix, Edge Functions stabilization. |
| **M2: Product Core** | ✅ **Done** | Product Schema, RPC for creation, List/Search API. |
| **M3: POS Transaction** | 🚧 **In Progress** | Cart logic, Order processing, Receipt generation. |
| **M4: Inventory** | ⏳ **Pending** | Stock tracking, adjustments, low stock alerts. |
| **M5: Reporting** | ⏳ **Pending** | Daily sales, staff performance, export to CSV/Excel. |
| **M6: Admin UI** | ⏳ **Pending** | User management, store settings, role assignment. |

---

## 📋 Kanban Board

### ✅ Done (Completed)
*   **Repo Hygiene**
    *   [x] Clean up `.bak`, `.tmp`, and `boots_fix_*.ps1` files.
    *   [x] Standardize `package.json` scripts.
    *   [x] Setup Vitest testing infrastructure.
*   **Authentication & Security**
    *   [x] **Critical:** Implement 1 Email -> Multiple Staff Profiles (1:N) schema.
    *   [x] **Critical:** Fix `resetPin` and `verify-pin` Edge Functions (remove `deno.land` imports).
    *   [x] Enforce RLS on `user_pins` (Service Role only).
    *   [x] Fix `GoogleSignIn` runtime error.
*   **Backend Infrastructure**
    *   [x] Migrate Edge Functions to `npm:@supabase/functions-js`.
    *   [x] Create `rpc_create_product` for secure product creation.
    *   [x] Fix `search-products` function deployment.
*   **Frontend Core**
    *   [x] Implement `ProductFormPage` with correct UUID handling.
    *   [x] Verify `PosUI` component structure.
    *   [x] Fix duplicate `AuthContext` issue.

### 🚧 In Progress (Active)
*   **POS Transaction Flow**
    *   [ ] Verify full "Add to Cart -> Checkout -> Pay" flow.
    *   [ ] Test `posService.createOrder` with backend `carts` table.
    *   [ ] Verify Receipt printing/modal.
*   **Testing**
    *   [ ] Add integration test for Order Creation.
    *   [ ] Add unit tests for `useCart` hook.

### ⏳ To Do (Backlog)
*   **Inventory Management**
    *   [ ] Implement `InventoryPage` (View stock levels).
    *   [ ] Add "Stock Adjustment" feature (In/Out/Waste).
    *   [ ] Real-time stock updates via Supabase Realtime.
*   **Reporting Module**
    *   [ ] Implement `DailyReportPage`.
    *   [ ] Create Edge Function for aggregating sales data.
    *   [ ] Add "Export to Excel" functionality.
*   **User Management (Admin)**
    *   [ ] UI to Create/Edit Staff Profiles.
    *   [ ] UI to Reset Staff PINs (Admin override).
*   **Deployment**
    *   [ ] Setup CI/CD pipeline (GitHub Actions).
    *   [ ] Configure Staging vs Production environments.

### 🛑 Blockers / Issues
*   *None currently.* (Previous `deno.land` connection issues resolved).

---

## 🛠 Technical Debt / Notes
-   **Edge Functions:** Ensure all new functions use `npm:` imports to avoid `deno.land` downtime issues.
-   **Types:** Consider migrating key services to TypeScript (`.ts`) for better safety, matching the Edge Functions.
-   **Testing:** Coverage is low. Need to increase test coverage for `posService` and `productService`.
