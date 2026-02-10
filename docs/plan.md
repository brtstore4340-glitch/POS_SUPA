# Project Plan: SDE Refactor & Core Completion

## 1. Objective
Refactor the Boots-POS Gemini application to strictly adhere to "Svelte 5 Runes Logic" (State/Derived/Effect) regardless of the framework. Complete the core POS functionality using Supabase Edge Functions.

## 2. Architecture Standard (SDE)
-   **STATE:** Minimal mutable source-of-truth (e.g., React Context, Zustand).
-   **DERIVED:** Pure computed values. NO side effects, NO state writes during derivation.
-   **EFFECT:** All IO (Supabase, LocalStorage, Fetch) must be isolated in the Service Layer or dedicated Effect Hooks.

## 3. Milestones
1.  **M1: Architectural Compliance:**
    -   Centralize all `localStorage` access.
    -   Move all direct Supabase calls from UI to Services.
    -   Refactor `AuthContext` to be a pure State provider with separate Effect handlers.
2.  **M2: POS Core Service:**
    -   Replace `posService.js` placeholders with real Supabase Edge Function calls.
    -   Implement offline-resilient cart logic.
3.  **M3: Optimization & Polish:**
    -   Performance tuning (chunk splitting).
    -   Final Security Review (Gatekeeper).

## 4. Branching Strategy
-   `refactor/sde-*`: Branches for architectural cleanup.
-   `feat/pos-core`: Implementation of the POS service.
-   `main`: Production-ready code (passing all SDE gates).
