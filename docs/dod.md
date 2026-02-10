# Definition of Done (DoD)

-   [ ] **Local Build:** `npm ci` and `npm run build` succeed without errors.
-   [ ] **Vercel Deploys:** Production and Preview deployments are successful.
-   [ ] **Supabase RLS:** RLS is enabled on the `profiles` table. Policies are tested and verified.
-   [ ] **Application UI:**
    -   [ ] User can sign up and sign in.
    -   [ ] User can view their own profile data on a protected page.
    -   [ ] User can update their own profile data.
    -   [ ] Anonymous users are redirected from protected pages.
-   [ ] **Security:** No secrets are present in client-side code. No `service_role` key is used.
-   [ ] **Documentation:** README is updated. `.env.example` is present.
-   [ ] **Gatekeeper Sign-off:** The Reviewer has approved the final deliverable.
