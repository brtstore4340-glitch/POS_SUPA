# Workflow & Stage Gates

## Standard Workflow (6 agents)

**Gate 0 — Evidence Ready:**
Runner collects evidence (repo structure, key files, scripts, build output, supabase artifacts)

**Gate 1 — Blueprint Approved:**
Planner produces WBS + DoD + risks; Reviewer confirms no major scope/security gaps.

**Gate 2 — Supabase Contract Ready:**
Supabase Architect defines schema/RLS/RPC plan aligned with requirement and tenancy model.

**Gate 3 — Integration Slice Implemented:**
App Coder implements minimal vertical slice (auth + one core entity flow) aligned to contract.

**Gate 4 — Verify & Fix:**
Runner runs build/test; Debugger fixes failures; Runner re-verifies.

**Gate 5 — Release Gate:**
Reviewer outputs PASS/NEEDS FIX/BLOCKED with strict checklist.

---

# Stop Criteria

When to stop the workflow.

**If requirement is NOT provided yet:**
- Stop after Gate 1 (Baseline + Plan + Prompts + evidence gaps list).

**If requirement IS provided:**
- Stop after Gate 4 with a working verified slice + Reviewer verdict (Gate 5).

---

# How to Use This Pack

1.  Place the `00-orchestrator.prompt.md` content into the Orchestrator agent.
2.  Place the `01-06` prompt files into their corresponding agents.
3.  Send the next requirement in a single message.
4.  The Orchestrator will initiate Gate 0 by instructing the Runner to collect evidence, and the process will begin.
