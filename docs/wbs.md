# Work Breakdown Structure (SDE Refactor)

## 1. Architectural Cleanup (App Coder)
-   1.1 **Storage Service:** Create `src/services/internal/storageService.js` to wrap `localStorage`.
-   1.2 **System Service:** Create `src/services/systemService.js` for health checks.
-   1.3 **Refactor UI:**
    -   Update `LoginPage.jsx` to use `storageService`.
    -   Update `PosUI.jsx` to use `storageService` for search hits.
    -   Update `ServerStatus.jsx` to use `systemService`.

## 2. POS Core Implementation (App Coder + Supabase Architect)
-   2.1 **Edge Functions:** Implement `calculateOrder`, `searchProducts`, `scanItem` in `supabase/functions/`.
-   2.2 **Service Integration:** Update `src/services/posService.js` to call these Edge Functions.
-   2.3 **Cart Logic:** Audit `useCart` hook for SDE violations (ensure strict separation of state update vs. IO).

## 3. Verification (Runner)
-   3.1 **Hotspot Scan:** Re-run grep to ensure no `localStorage` or `supabase.from` remains in `src/pages` or `src/components`.
-   3.2 **Build Check:** Ensure `npm run build` passes.
-   3.3 **Smoke Test:** Verify login, cart addition, and checkout flow.

## 4. Review (Gatekeeper)
-   4.1 Check Derived Purity Gate.
-   4.2 Check Effect Boundary Gate.
-   4.3 Check Loop Safety Gate.
