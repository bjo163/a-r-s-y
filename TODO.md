# A-R-S-Y — Active Execution Queue

This is the short, actionable queue for the next implementation cycle. It is not a second roadmap:
- Product milestones and gates live in `docs/05-roadmap.md`.
- Full context, constraints, acceptance criteria, and handoff rules live in `docs/LOCAL_AI_HANDOFF.md`.
- When a task is completed, update this queue and the relevant canonical docs in the same PR/commit.

## P0 — CI and verification reliability

- [ ] **P0.1 — Get CI to execute on GitHub Actions**
  - Inspect repository Actions settings/runner availability and recent queued/cancelled runs.
  - Do not change workflow permissions or add external secrets as a workaround without a security reason.
  - Success: current `main` run reaches a terminal result with actual job steps; record pass/fail and logs.
- [ ] **P0.2 — Add Compose config validation to CI**
  - Supply non-secret dummy environment values only for `docker compose config --quiet`.
  - Validate service graph and volume/network configuration without deploying containers.
  - Success: malformed Compose fails CI; no production secrets are required.
- [ ] **P0.3 — Expand automated regression tests**
  - Add disposable PostgreSQL integration coverage for setup-once, login/logout, session invalidation/expiry, CSRF/origin, onboarding persistence, DNS check response, and exact-SHA update approval.
  - Add negative/security cases; do not rely only on happy-path tests.
  - Success: tests run repeatably in CI with cleanup and no shared production state.

## P1 — Host lifecycle safety

- [ ] **P1.1 — Test install, repair, update, rollback as separate flows**
  - Verify `.env`, named PostgreSQL volume, `/var/lib/arsy/deployed-sha`, and `/var/lib/arsy/Caddyfile` survive.
  - Test initial install failure separately from update rollback.
- [ ] **P1.2 — Add safe migration for legacy environment variables**
  - Inspect older `ARSY_HTTP_BIND`, `ARSY_HTTPS_BIND`, and related values.
  - Migrate only when intent is unambiguous; preserve user data and print a clear warning otherwise.
  - Never silently expose public ports.
- [ ] **P1.3 — Domain helper failure matrix**
  - Test invalid hostname/IP, private/shared IP, missing/mismatched A, AAAA present, occupied 80/443, missing prerequisites, Compose failure, Caddy failure, TLS timeout, and rollback.
  - Verify private SSH recovery listener remains intact after every path.
- [ ] **P1.4 — Review proxy trust and cookie security**
  - Verify Fastify `trustProxy` assumptions against supported topology.
  - Ensure untrusted forwarded headers cannot spoof secure transport or client IP.
  - Document exact reverse-proxy requirements and test them.

## P2 — Onboarding and operator UX

- [ ] **P2.1 — Audit wizard against intended journey**
  - Make CLI vs Web responsibilities explicit.
  - Clearly distinguish saved profile, DNS diagnostic, and actual domain activation.
  - Ensure private mode remains the default and recovery path.
- [ ] **P2.2 — Add onboarding progress and actionable diagnostics**
  - Show install, Superadmin, profile, node, access mode, DNS check, domain activation, and health states.
  - Avoid marking an external/manual step complete without verification.
- [ ] **P2.3 — Verify language/timezone behavior**
  - Do not imply full localization if the selected language is only stored.
  - Ensure selected timezone is actually used where relevant.

## P3 — First-VPS release gate

- [ ] **P3.1 — Security review and threat model**
- [ ] **P3.2 — Encrypted off-site backup and successful restore drill**
- [ ] **P3.3 — Real VPS fresh-install, repair, update, rollback, private recovery, and HTTPS smoke tests**
- [ ] **P3.4 — Release checklist and evidence record**

## Explicitly not next

Do not begin tenant CRUD, DNS hosting, WAF/CDN, tunnels, storage, compute, K3s, CloudStack, billing, Keycloak, node agents, or multi-region work until the first-VPS foundation gate is met. See the master blueprint for later adoption gates.


## Autonomous execution contract

This queue is executed under docs/08-autonomous-agent-operating-model.md. Agents must not pause for routine technical choices or ask the owner to approve ordinary repository changes. They must inspect current main, issues, PRs and CI; avoid duplicate tasks; implement, test, document, commit and verify; then continue to the next safe independent task. Stop only the specific action requiring operator authority (public exposure, firewall/SSH/DNS/provider change, real-host deploy/restart, destructive data action, live secret rotation, paid resource, legal/commercial commitment or external customer communication). Record the blocker and exact operator step, then continue unrelated work.

## Documentation completeness gate

- [ ] Confirm README links to every canonical product, security, operations, UX and agent document.
- [ ] Check all cross-document links and terms; keep one canonical home per topic.
- [ ] Ensure each roadmap milestone has entry/exit gates and each feature is maturity-labelled.
- [ ] Ensure handoff and verification snapshot reflect current main, not historical assumptions.
