# A-R-S-Y — Active Execution Queue

This is the short, actionable queue. Product milestones live in docs/05-roadmap.md; full context lives in docs/LOCAL_AI_HANDOFF.md. A script or document being committed is not equivalent to successful test or real-host evidence.

Status key:
- [x] — implementation and required evidence complete.
- [~] — implementation/test harness exists; CI or external evidence is pending.
- [ ] — not complete or blocked.

## P0 — CI and verification reliability

- [~] P0.1 — Get CI to execute on GitHub Actions
  - Latest implementation commit checked: 9f6d647. Its Actions run 42368016667 is queued; the validate job has no assigned runner (runner_id=null) and no executed steps. Recheck the newest run on current main before making any pass/fail claim.
  - Workflow is configured for push, PR and manual dispatch; permissions remain contents: read.
  - Do not weaken permissions, add secrets, or bypass required checks to force a result.
  - Next: repository/org Actions administrator must inspect Actions policy, hosted-runner availability/quotas and GitHub status if the queue remains stalled.
  - Complete only when a current-main run reaches a terminal result and its actual job steps/logs are reviewed.
- [~] P0.2 — Compose configuration validation
  - CI runs docker compose config --quiet with CI-only dummy environment values.
  - No containers are deployed and no real credentials are used.
  - Pending actual CI execution and confirmation that malformed Compose fails the job.
- [~] P0.3 — PostgreSQL integration and negative/security tests
  - Added disposable PostgreSQL 17 coverage for health, setup-once, login, cookie attributes, repeated setup, invalid credentials, CSRF, Origin, timezone and IPv4 validation, DNS diagnostic, pre-save DNS persistence, onboarding profile, dashboard readiness, exact-SHA update approval/audit, logout and session expiry.
  - Database name is hard-limited to arsy_test; tests clean their tables and child process.
  - Pending actual CI execution and failure-log review. Never run against a live database.

## P1 — Host lifecycle safety

- [~] P1.1 — Install, repair, update and rollback
  - Added isolated deploy lifecycle tests for update, Compose-start failure rollback, health-check rollback, same-SHA repair/redeploy, legacy migration success (80/443 are retained but wildcard binds stay loopback), exact .env restoration after failed deploy, runtime Caddyfile/deployed SHA preservation, and no persistent-volume deletion.
  - Pending CI run. Full initial installer mutation/failure path is not yet tested in a disposable VM. Real install/repair remains a VPS release gate.
- [~] P1.2 — Safe legacy environment migration
  - Added idempotent, same-filesystem atomic migration for legacy ARSY_HTTP_* and ARSY_HTTPS_* layouts.
  - Retains configured ports but intentionally does not migrate old wildcard binds; new public binds remain 127.0.0.1 until explicit domain activation. Preserves secrets and .env mode 0600.
  - Regression tests cover legacy wildcard layout, current-layout idempotency and secret preservation. Deploy migrates the untouched legacy layout before adding modern defaults; failure restores the exact pre-deploy .env. Pending CI execution.
- [~] P1.3 — Domain helper failure matrix
  - Added mocked tests for invalid hostname/IP, special-use/private IPv4, occupied port, missing A, mismatched A, AAAA, missing prerequisite, generated Caddyfile validation failure, Compose config/start failure, HTTPS timeout, rollback-state preservation and successful activation.
  - Private SSH recovery remains separate from public listeners; tests assert recovery and local-proxy listener configuration.
  - Pending CI execution and real external-network/VPS verification.
- [~] P1.4 — Proxy trust and cookie security
  - Private SSH recovery is 127.0.0.1:18080; same-host reverse-proxy ingress is 127.0.0.1:18082.
  - Nginx guidance overwrites forwarded client headers; Fastify trusts one immediate Caddy hop; remote/multi-hop proxies are unsupported in first-VPS mode.
  - Pending automated workflow evidence and real same-host proxy integration test. Do not broaden trusted proxy ranges without a new threat review.

## P2 — Onboarding and operator UX

- [x] P2.1 — Hybrid CLI/Web responsibilities
  - CLI owns host preflight, prerequisites, domain activation and host operations.
  - Web stores installation metadata and observes DNS only. Provider DNS and firewall remain operator-managed. Saving a profile does not activate a domain.
  - Private SSH tunnel remains the default/recovery path.
- [~] P2.2 — Readiness and actionable diagnostics
  - Dashboard distinguishes Control Plane response, Superadmin, saved profile, node identity, DNS observation, access mode and domain activation. DNS resolver transient errors, no-record, mismatch and match states are shown separately.
  - DNS diagnostic is timestamped and retained when the matching profile is saved; changed hostname/target invalidates the prior result.
  - Manual/provider steps remain explicitly unverified. Pending CI integration and visual verification on a real browser/VPS.
- [x] P2.3 — Language/timezone behavior
  - Valid IANA timezone is enforced and used for the node clock display.
  - Saved language sets HTML lang, but the interface is not fully translated; the UI says so.

## P3 — First-VPS release gate

- [~] P3.1 — Security review and threat model
  - Added first-VPS threat model and release security checklist.
  - Independent application/host review, MFA plan, vulnerability intake, SBOM and dependency/image/license evidence remain outstanding.
- [~] P3.2 — Encrypted off-site backup and restore drill
  - Added Restic remote-only backup and isolated PostgreSQL restore-drill tooling. Restore drill uses Docker network=none and does not touch production volume.
  - No provider account, remote repository, credentials, encryption password or schedule has been configured. Actual backup and successful restore drill remain required; never store credentials in Git.
- [ ] P3.3 — Real VPS fresh-install, repair, update, rollback, private recovery and HTTPS smoke tests
  - Blocked until an operator has a supported VPS and chooses to run reviewed host commands. No VPS/SSH access is available in this repository task.
- [~] P3.4 — Release checklist and evidence record
  - Checklist and redacted evidence template created. CI, real-host, backup, restore, review and release evidence fields remain unchecked until recorded against an exact candidate SHA.

## Documentation completeness
- [x] Added docs/INDEX.md as the canonical document map and source-of-truth precedence.
- [~] Cross-document links have a CI checker and are included in CI; workflow run is pending.
- [x] Roadmap milestones declare entry and exit gates.
- [~] Handoff is updated for implementation through code commit 9f6d647; refresh again after new CI or VPS evidence.

## Explicitly not next

Do not begin tenant CRUD, DNS hosting, WAF/CDN, tunnel product, object storage, compute, K3s, CloudStack, billing, Keycloak, node agents or multi-region work until the first-VPS foundation gate is met.

## Autonomous execution contract

Read AGENTS.md and docs/08-autonomous-agent-operating-model.md. Inspect current main, issues, PRs and CI before editing. Implement, test, document, commit and verify safe repository tasks without pausing for routine technical choices. When blocked by operator authority or unavailable infrastructure, record the exact blocker and next operator step, then continue unrelated safe work. Never convert a queued workflow, committed test, runbook or mock into a false completion claim.
