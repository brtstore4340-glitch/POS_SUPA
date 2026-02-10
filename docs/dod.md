# Definition of Done (SDE Standard)

-   [ ] **Derived Purity Gate:** NO `localStorage`, `fetch`, or `supabase.*` calls in any UI component render logic or derived state selectors.
-   [ ] **Effect Boundary Gate:** 100% of IO interactions are encapsulated in `src/services/`.
-   [ ] **Functionality:**
    -   `posService` is fully functional and connected to Supabase Edge Functions.
    -   Login/Logout works via `AuthContext` -> `authService`.
    -   App builds without errors (`npm run build`).
-   [ ] **Clean Code:** No "dead code" or commented-out blocks from previous versions.
-   [ ] **Security:** RLS enabled on all tables. No leaked secrets.
