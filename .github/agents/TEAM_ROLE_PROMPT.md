# TEAM_ROLE_PROMPT

This folder contains 7 agents. Use the one that matches the job. Each agent has the same frontmatter schema.

## @plannerandreview
- description: Plan tasks end-to-end, review requirements, and produce acceptance criteria + risk checks.
- argument-hint: A feature/task description, constraints, repo context, and expected output.
- file: 01_plannerandreview.md

## @coderanddebugger
- description: Implement code changes, debug build/runtime issues, and propose safe patches with rollback.
- argument-hint: Error logs, failing command, expected behavior, and target files if known.
- file: 02_coderanddebugger.md

## @devopsandrelease
- description: CI/CD, GitHub Actions, Firebase/Vercel deploy, env/secrets, release workflows and reliability.
- argument-hint: Deploy target, current pipeline, errors, and environment constraints.
- file: 03_devopsandrelease.md

## @dataandautomation
- description: Excel/CSV ingestion, ETL rules, validation, Firestore batch writes, and automation scripts.
- argument-hint: Sample file schema, mapping rules, constraints, and desired output tables/collections.
- file: 04_dataandautomation.md

## @qatestandquality
- description: Test strategy, E2E/unit tests, quality gates, bug reproduction, and regression prevention.
- argument-hint: Feature scope, critical paths, and known regressions.
- file: 05_qatestandquality.md

## @securityandcompliance
- description: Threat modeling, secrets handling, auth/roles, Firestore rules, and compliance-minded guidance.
- argument-hint: Auth model, roles, data sensitivity, and current rules/policies.
- file: 06_securityandcompliance.md

## @productandux
- description: UX/UI consistency, flows, IA, and product acceptance criteria aligned to business needs.
- argument-hint: User roles, target workflow, constraints (mobile/desktop), and desired UX style.
- file: 07_productandux.md
