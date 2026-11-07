# A-R-S-Y — Instructions for AI coding agents

## Mandatory read order
1. README.md
2. TODO.md
3. docs/LOCAL_AI_HANDOFF.md
4. docs/00-narrative-and-positioning.md
5. docs/02-master-blueprint.md
6. docs/05-roadmap.md
7. docs/08-autonomous-agent-operating-model.md
8. docs/09-product-and-service-catalog.md
9. docs/10-platform-contracts-and-data-model.md
10. docs/11-security-privacy-and-trust.md
11. docs/12-operations-quality-and-release.md
12. docs/13-onboarding-and-experience.md
13. Relevant operational docs, source, tests, workflows, issues and current Git state.

## Authority
Actual code, schema, tests and observed runtime define implementation truth. The handoff defines verified current state. The master blueprint defines target architecture, not permission to implement every future service. The roadmap defines gates. TODO defines the active queue. The autonomous operating model defines agent authority. Resolve conflicts using that model; never silently invent a product decision.

## Product constraints
- A-R-S-Y is an open, customer-owned infrastructure control plane and future service platform, not a Coolify reskin or one-VPS global cloud.
- One VPS and one operator first; hybrid CLI/Web onboarding.
- Private SSH tunnel is default and recovery path.
- Public domain requires operator-configured DNS A/provider firewall TCP 80/443 and explicit CLI activation.
- No mandatory K3s, CloudStack, Keycloak, second VPS, provider token, billing account or SSH private key in first install.
- Never silently change firewall/SSH, expose public ports, deploy updates, restart production, delete persistent data, spend money or publish customer data.
- Exact-SHA updates require operator execution. No CI/GitHub auto-deploy.
- No untrusted customer workloads on control-plane VPS; no Docker socket in web app.
- Never claim HA, global CDN, Anycast, volumetric DDoS, multi-region, SLA or production readiness without evidence.
- Verify exact licenses/editions of mandatory dependencies.

## Engineering
Inspect current GitHub state, tests and open work before editing. Prefer small changes and modular monolith. Preserve .env, DB volume, deployed SHA, runtime Caddy config and operator settings. Migrations remain additive/backward-compatible until tested. Add negative/failure tests. Never claim a queued/cancelled/skipped CI run passed. Never claim a real VPS test unless performed. Never commit secrets or customer data.

## Autonomous delivery
Follow docs/08-autonomous-agent-operating-model.md. Do not ask for confirmation for routine code, tests, docs, refactors, issue triage or compatible technical choices. Continue safe independent tasks when blocked. Explicit operator approval is mandatory for external/high-impact actions listed in that policy.

## Git and close-out
main is stable; use dev if active; branch prefixes feat/, fix/, chore/. Use Conventional Commits. Never force-push or overwrite concurrent work. Merge only when required checks/reviews/policy permit. Verify main after merge and update linked issue only with evidence. Report files, tests/results, commit/branch, PR/merge state, risks and next task.
