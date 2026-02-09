# Copilot Instructions for Boots-POS Gemini

## Architecture Overview

**Stack:** React + Vite (frontend) | Supabase (backend/auth) | Edge Functions (trusted actions)

**Key Boundary:** UI ← Services ← Edge Functions ← Database
- UI never touches auth logic; all auth via Supabase session
- Staff PIN validation must happen in Edge Functions, never client-side
- RLS enforces row-level access; client checks are UX only

## Agent-Driven Workflow

1. **PlannerAndReview** – Parse requirements, create deployment runbooks, approve tasks (≤3 files per task)
2. **CoderAndDebugger** – Implement approved tasks only; minimal patches with verification commands
3. **SecurityAndCompliance** – Audit RLS policies, auth flows, secrets handling
4. **PerformanceAndOptimization** – Query optimization, pagination, N+1 detection

**Invocation:** `/agent [AgentName] [context]`

## Non-Negotiables

- **Plan:** Assume free Copilot plan; do not require Copilot Pro or premium-only features.
- **RLS:** Strict deny by default; explicit allow only. Test with `supabase test`
- **Secrets:** Never hardcode; use Supabase vault. No logging of PIN or PII
- **Auth:** Email/password + OAuth only; no brittle session bugs
- **Edge Functions:** Use for staff PIN validation, trusted actions, PII access
- **Pagination:** Required for tables > 10k rows; avoid N+1 queries
- **Staff PIN:** Hash + salt; include rate-limit/lockout in Edge Function

## File Structure & Patterns

- `.github/agents/` – Agent definition files (`.agent.md`)
- `src/` – React components, services, hooks
- `supabase/migrations/` – Schema changes (always versioned)
- `supabase/functions/` – Edge Functions (trusted actions)
- `supabase/policies/` – RLS policy definitions

**Example RLS Pattern:**
```sql
-- Strict deny default
CREATE POLICY "staff_pins_deny" ON staff_pins AS RESTRICTIVE USING (false);
-- Explicit allow for staff context only
CREATE POLICY "staff_pins_allow_read" ON staff_pins FOR SELECT USING (auth.uid() = staff_id);
```

## Deployment Checklist

- [ ] Migrations tested locally: `supabase migration up --linked`
- [ ] RLS policies pass: `supabase test`
- [ ] Edge Functions deployed: `supabase functions deploy`
- [ ] Secrets injected: `supabase secrets set`
- [ ] Performance baseline: P95 latency established
- [ ] Rollback plan documented (revert migration + git revert)

## Common Commands

```bash
npm run dev              # Start Vite + Supabase local
supabase migration new   # Create migration
supabase test            # Run RLS tests
supabase functions deploy # Deploy Edge Functions
npm run verify:prod      # Integration tests
```

## When to Route to Specialist Agents

- **Ambiguous scope?** → PlannerAndReview
- **Security question?** → SecurityAndCompliance (RLS, secrets, OAuth)
- **Performance issue?** → PerformanceAndOptimization (query analysis, pagination)
- **Blocked on error?** → CoderAndDebugger (with logs + context)
