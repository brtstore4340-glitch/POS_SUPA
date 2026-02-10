# Work Breakdown Structure

## 1. Environment Setup (Orchestrator, All Agents)
-   1.1 Create GitHub Repository.
-   1.2 Create Vercel Project and link to Git repo.
-   1.3 Create Supabase Prod & Staging projects.
-   1.4 Configure Vercel environment variables.

## 2. Backend (Supabase Architect)
-   2.1 Define `profiles` table schema.
-   2.2 Define RLS policies for `profiles`.
-   2.3 Create SQL migration file.

## 3. Frontend (App Coder)
-   3.1 Scaffold Vite + React application.
-   3.2 Create Supabase client.
-   3.3 Create `LoginPage`.
-   3.4 Create `ProtectedPage` for smoke testing.
-   3.5 Implement routing and protected routes.

## 4. Verification & Deployment (Runner, Debugger)
-   4.1 Run `npm ci`, `npm run build`.
-   4.2 Perform smoke tests locally.
-   4.3 Trigger Vercel deployments via PR.
-   4.4 Debug any failures.

## 5. Review (Reviewer)
-   5.1 Conduct security and quality review.
-   5.2 Verify all deliverables.
-   5.3 Provide SHIP / NO-SHIP decision.
