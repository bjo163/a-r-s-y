# A-R-S-Y Documentation Index

This is the navigation map for product, architecture, engineering, operations and autonomous agents. README.md is the public entry point; AGENTS.md is the mandatory coding-agent policy; TODO.md is the active execution queue.

## Read first
1. Product narrative and positioning — 00-narrative-and-positioning.md
2. Master blueprint — 02-master-blueprint.md
3. First-VPS foundation plan — 03-first-vps-alpha.md
4. Roadmap and execution gates — 05-roadmap.md
5. Local AI handoff — LOCAL_AI_HANDOFF.md
6. Autonomous AI operating model — 08-autonomous-agent-operating-model.md

## Product and strategy
- 00-narrative-and-positioning.md — why A-R-S-Y exists and its place in the wider project universe.
- 01-brand-system.md — names, visual identity and usage.
- 02-master-blueprint.md — final product direction, planes, architecture boundaries and adoption gates.
- 03-first-vps-alpha.md — initial operator journey and deployment constraints.
- 05-roadmap.md — milestone entry and exit gates.
- 06-repository-structure.md — current layout and future modularization rules.
- 07-commercial-guardrails.md — future service promises, customer trust and commercial readiness.
- 09-product-and-service-catalog.md — service portfolio and maturity labels.

## Engineering and platform contracts
- ARCHITECTURE.md — what the code does now.
- 10-platform-contracts-and-data-model.md — APIs, identity, resources, jobs, tenancy and compatibility.
- 08-autonomous-agent-operating-model.md — execution authority, issue/PR lifecycle and close-out.
- 13-onboarding-and-experience.md — UX, CLI/Web split, states, language and timezone.

## Security, privacy and open source
- 04-open-source-security-policy.md — licensing and supply-chain policy.
- 11-security-privacy-and-trust.md — normative platform controls.
- THREAT-MODEL.md — initial first-VPS risks and residual risks.
- SECURITY.md — vulnerability reporting and current security constraints.

## Operations and release
- INSTALLATION.md — install, onboarding, access modes and repair.
- UPDATE_POLICY.md — update detection, exact-SHA approval and operator-controlled deployment.
- BACKUP-RESTORE.md — encrypted Restic backup and isolated restore drill.
- 12-operations-quality-and-release.md — CI, deployment, backup, recovery and quality gates.
- RELEASE-CHECKLIST.md — evidence required for each release.
- LOCAL_AI_HANDOFF.md — verified implementation state and next autonomous work.

## Source-of-truth precedence
- Observed code, schema, tests and completed workflow evidence define actual implementation truth.
- LOCAL_AI_HANDOFF.md records current verified status and blockers.
- 02-master-blueprint.md defines target product and architecture; it does not authorize premature implementation.
- 05-roadmap.md defines milestone entry and exit gates.
- 08-autonomous-agent-operating-model.md defines agent authority and approval boundaries.
- TODO.md is the only active short execution queue.
- Product catalog, platform contracts, security, operations and onboarding docs are normative within their topics.

When documents conflict, do not guess or silently create a new product decision. Follow the authority order, inspect current implementation, record the discrepancy, and reconcile canonical documents in the same change.
