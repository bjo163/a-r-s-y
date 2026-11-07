# A-R-S-Y — Local AI Handoff

> Purpose: this is the working context packet for a local coding agent. Read it before touching code. Keep it current whenever implementation, scope, decisions, or verified status changes.

**Repository:** `bjo163/a-r-s-y`  
**Product:** A-R-S-Y — *One Command Plane. Open by Design.*  
**Relationship:** practical infrastructure/control-plane layer in the wider MoonWitness universe.  
**Current stage:** single-VPS foundation / pre-alpha.  
**Primary goal now:** finish and verify the first-VPS onboarding and operations foundation before expanding into the broader cloud roadmap.

## 1. Product in one paragraph

A-R-S-Y is an open-source, customer-owned infrastructure control plane. It coordinates infrastructure services through a clear management experience and replaceable open-source engines. It starts with one VPS and one operator, then grows only when independent infrastructure and operational capability exist. It is not a Coolify reskin, hosting reseller panel, or claim to reproduce a global cloud network on one machine.

## 2. Decisions already made — do not reopen without evidence

### Deployment and onboarding
- One VPS first. Additional VPS/node is optional and belongs to a later milestone.
- Initial install is a reviewed shell installer: `install.sh`.
- Use a hybrid CLI + Web flow:
  - **CLI:** host preflight, install prerequisites, create secrets, start services, repair, diagnostics, and explicitly confirmed host-level domain activation.
  - **Web:** first Superadmin setup, workspace/profile, installation name, environment, node name, contact email, language, timezone, access mode, hostname/IP, DNS check, and onboarding progress.
- Installer prints a preflight summary and asks for confirmation when interactive. Non-interactive use requires explicit `ARSY_INSTALL_CONFIRM=1`.
- Installer must not silently rewrite firewall rules or SSH daemon configuration.
- No public registration. The one-time setup token creates the first Superadmin; setup then closes.
- Do not demand credentials that are not needed for first boot: no DNS provider API token, cloud provider token, billing account, SSH private key, or second-server credential.

### Access modes
1. **Private (default):** SSH tunnel to `127.0.0.1:18080`. Keep this path available for recovery even after public domain activation.
2. **Managed public domain:** user creates DNS A record to VPS IPv4 and allows inbound TCP 80/443 in provider firewall. User explicitly runs `sudo arsy-domain apply --hostname panel.example.com`; helper validates prerequisites, ports, DNS, and address, explains changes, asks confirmation, enables Caddy HTTPS, and performs a health check with rollback.
3. **Existing reverse proxy:** keep A-R-S-Y on loopback and configure a same-host proxy to `http://127.0.0.1:18082`. The private SSH recovery listener remains separate at `127.0.0.1:18080`. TLS terminates at the existing proxy. Do not take over public ports.

Current public domain helper is IPv4-only and rejects an AAAA result. Do not describe IPv6 domain activation as supported. Existing same-host reverse proxy uses 127.0.0.1:18082; private SSH recovery remains 127.0.0.1:18080.

### Updates
- Detection is not deployment.
- Dashboard offers **Later** and **Update now**. Approval records an exact SHA and displays a terminal command.
- VPS changes only after the operator runs the command and confirms/executes the approved operation.
- A push, merge, release, or update check must never auto-deploy.
- Preserve `.env`, PostgreSQL volume, `/var/lib/arsy/deployed-sha`, and runtime Caddy config at `/var/lib/arsy/Caddyfile`.
- Rollback must not delete persistent volumes.

### Architecture and scope
- Initial stack: Node.js 24, Fastify 5, PostgreSQL 17, Caddy, Docker Engine + Compose.
- Initial UI is server-rendered HTML with local CSS/JS; do not introduce Next.js or a new frontend framework without an explicit architecture decision and demonstrated need.
- Keep a modular monolith. Do not add microservices, workers, node agents, K3s, CloudStack, or distributed data planes in the first-VPS foundation.
- PostgreSQL is the durable store. The current implementation is not yet a multi-tenant customer cloud control plane.
- Mandatory runtime dependencies must be OSI-approved open source; verify exact license and edition.
- No arbitrary customer workloads on the control-plane host. No Docker socket in the web app.

## 3. Current implementation — distinguish implemented from planned

### Implemented in repository
- Fastify web/API process and PostgreSQL connection/schema bootstrap.
- Caddy gateway and Docker Compose stack.
- Installer for Ubuntu 22.04+ / Debian 12+, AMD64/ARM64 (subject to actual runtime testing).
- Docker Engine/Compose installation path, generated secrets, root-only `/opt/arsy/.env`.
- Private listener default at `127.0.0.1:18080`; separate public gateway bindings default to loopback until explicitly activated.
- Health endpoint and database readiness check.
- One-time bootstrap-token Superadmin creation; single active Superadmin constraint.
- Password hashing using Node.js scrypt; opaque PostgreSQL-backed sessions; login/logout.
- CSRF/origin protections, rate limiting, audit events for relevant auth/setup/update actions.
- Onboarding profile persistence with workspace, installation, environment, contact, timezone, language, node, access mode, hostname, target IPv4 and proxy details; DNS A/AAAA diagnostic is timestamped and persisted, and retained across profile save only when its target still matches.
- Dashboard readiness distinguishes responding control plane, Superadmin, profile, node, DNS diagnostic, access mode and domain activation. Selected IANA timezone is used for dashboard clock; the UI does not claim full translation.
- Legacy environment migration preserves secrets and file mode, and leaves public binds on loopback until explicit domain activation.
- Dedicated same-host reverse-proxy ingress at 127.0.0.1:18082; private SSH recovery remains 127.0.0.1:18080.
- Dashboard update check, Later dismissal, explicit approval of exact commit SHA, terminal command generation.
- Host scripts: deploy, update, doctor, domain apply/proxy, safe legacy environment migration, shared IPv4 validation, encrypted remote backup and isolated PostgreSQL restore drill.
- Runtime Caddy config persisted under `/var/lib/arsy/Caddyfile` so source checkout/update does not replace it.
- Brand assets and product/architecture/security/installation documentation.

### Not implemented / not to be implied as available
- Multi-user invitations, organization/project CRUD, tenant RBAC, customer API keys.
- Service catalog/provisioning engine, durable job queue/worker, reconciliation.
- Public DNS hosting, PowerDNS production topology, DNSSEC workflow, independent secondary nameservers.
- Production WAF/edge, global CDN, cache fleet, tunnel product, S3/object storage, customer compute/VMs.
- Billing, subscriptions, usage ledger, invoices, payment integrations.
- MFA, full OIDC/Keycloak, secrets manager, production-grade backup service.
- Multi-node agent, K3s, CloudStack/KVM, multi-region, HA, Anycast, upstream DDoS service.
- Real VPS deployment and browser/domain/TLS/backup/restore smoke tests.

## 4. Current technical map

- `install.sh`: host preflight, explicit confirmation, Docker/Compose prerequisites, clone/fetch main, preserve environment, install host commands, deploy.
- `compose.yaml`: PostgreSQL, Fastify app, Caddy gateway; named PostgreSQL volume.
- `Caddyfile`: source default; first deployed to `/var/lib/arsy/Caddyfile`.
- `apps/control-plane/src/server.js`: routes, auth/session, onboarding, update approval, health.
- `apps/control-plane/src/security.js`: password/session/input/security helpers.
- `apps/control-plane/schema.sql`: current database schema and additive bootstrap DDL.
- `apps/control-plane/public/`: browser JS and CSS.
- `scripts/arsy-deploy.sh`: locked exact-SHA deployment, safe legacy env migration before defaults, exact `.env` backup/restore on failure, Compose validation/build/up, health check, source rollback and post-rollback health verification.
- `scripts/arsy-update.sh`: update discovery and consent gate.
- `scripts/arsy-domain.sh`: managed domain apply and existing same-host proxy instructions; validates generated Caddy configuration before changing the running gateway and restores runtime config on failure.
- `scripts/arsy-doctor.sh`: host and service diagnostic checks.
- `.github/workflows/ci.yml`: Node tests, disposable PostgreSQL integration, Compose/Caddy validation, isolated shell regression tests and docs link check. It does not run a real VPS test or deploy.

## 5. Current execution status and remaining work

### P0 — CI and automated verification
1. Workflow has Compose config validation, PostgreSQL disposable integration, Caddy validation, Bash syntax, isolated migration/domain/deploy regression and Markdown link checking.
2. Main base SHA for PR #1 is `9bf2d20c725d97dc54900a5048b0f2efcb8df32a`; the current release-hardening PR head is `0502ff30a3696a596fb6fb3eab87efffb5c997f1`. Latest PR workflow run `42394245690` is queued; its `validate` job has no runner assignment or executed steps. Same-SHA push run `42394241695` was cancelled by concurrency. The combined commit status has no completed status entries. This is not a CI pass or test failure.
3. Do not lower permissions or add secrets. A repository/org Actions administrator must check runner availability, quotas and Actions policy if the queue remains stalled.
4. After CI runs, fix observed failures, rerun on resulting SHA, and retain actual logs.

### P1 — host lifecycle and ingress safety
1. Safe legacy .env migration and tests exist; execute regression in CI and review first upgrade/repair on a real disposable host.
2. Domain failure-matrix tests exist for validation, DNS, prerequisites, occupied ports, generated Caddyfile validation, Compose failures, TLS timeout and rollback; execute them in CI. Real network and provider-firewall tests remain a release gate.
3. Deploy lifecycle harness covers update, repair/redeploy, legacy layout migration success, exact .env restoration after failed deployment, failed Compose start, failed health check, source rollback, and preservation of Caddyfile/deployed SHA/no-volume-deletion. It does not yet emulate a full fresh install or a failure during first installation.
4. Proxy boundaries: SSH recovery is loopback port 18080; existing same-host reverse proxy uses loopback port 18082; Fastify trusts one immediate Caddy hop; the reverse proxy must overwrite X-Forwarded headers. Remote/multi-hop proxies are unsupported.
5. Independently review installer prerequisites and supported Ubuntu/Debian host behavior before private beta.

### P2 — onboarding and operator experience
1. Web owns profile metadata and DNS observation; CLI owns host preflight and domain activation; provider DNS/firewall actions remain operator-managed.
2. Dashboard displays evidence-backed profile, node, DNS, access, domain and control-plane states. A manual/provider step is never marked verified by saved profile alone.
3. DNS result is timestamped, resolver errors are distinguished from no-record results, and a result survives profile-save only when hostname and target IPv4 still match.
4. IANA timezone is validated and used for dashboard display. Language preference sets the HTML language attribute, but full translation remains future work.

## 6. Definition of done for the first-VPS foundation

- Clean install succeeds on supported Ubuntu and Debian hosts, on AMD64 and ARM64 where available.
- Installer clearly previews host changes and requires confirmation; it does not edit firewall/SSH settings.
- Private SSH tunnel works immediately after install and remains available after managed domain activation.
- First Superadmin can be created once; subsequent setup attempts are rejected.
- Login/logout/session/CSRF/rate-limit behavior is tested.
- Onboarding profile saves and reloads; DNS check accurately distinguishes A, AAAA, mismatch, and no-record states.
- Private, managed-domain, and existing-proxy modes have explicit instructions and tested boundaries.
- Managed domain requires correct DNS A and operator firewall action; public ports are never opened silently.
- Update check has no side effects; approval pins exact SHA; operator executes it; rollback preserves data and runtime gateway config.
- CI passes on current `main`; all tests are reproducible.
- Real VPS install, update, rollback, domain HTTPS, private recovery, and backup/restore drills are recorded.
- Docs match code and clearly label unimplemented features.

Until all gates are met, status remains **pre-alpha / not production-ready**.

## 7. Commands and operator paths

Fresh install:
```bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
```

Private access from workstation:
```powershell
ssh -L 18080:127.0.0.1:18080 USER@VPS
```
Then open `http://127.0.0.1:18080`.

Retrieve bootstrap key on VPS:
```bash
sudo grep '^ARSY_SETUP_TOKEN=' /opt/arsy/.env
```

Diagnostics / updates:
```bash
sudo arsy-doctor
sudo arsy-update
```

Managed domain activation (only after DNS A and provider firewall are ready):
```bash
sudo arsy-domain apply --hostname panel.example.com
```

Existing reverse proxy guidance:
```bash
sudo arsy-domain proxy --hostname panel.example.com
```

Repair:
```bash
sudo bash /opt/arsy/install.sh --repair
```

Never use `docker compose down -v` as routine repair/update; it deletes the database volume.

## 8. Verification snapshot

- Main base SHA for the current release-hardening PR: `9bf2d20c725d97dc54900a5048b0f2efcb8df32a`.
- PR #1 head: `0502ff30a3696a596fb6fb3eab87efffb5c997f1` on `fix/release-config-validation`.
- Latest run `42394245690` (pull_request) is queued with no runner assignment or executed steps. The same-SHA push run `42394241695` was cancelled by concurrency. Neither is a test pass; cancellation is not a failure. Combined commit status currently has no completed status entries.
- Workflow concurrency now groups push and PR runs by the same branch ref. This reduces duplicate runner requests but has not resolved the queue. Exact cause is unconfirmed; repository/org Actions administrator must inspect Actions policy and hosted-runner availability/quotas.
- CI includes Node unit/integration tests, PostgreSQL 17 service, Compose/Caddy validation, shell regression tests, docs link checking, production npm audit, CycloneDX SBOM artifact generation, and production control-plane image build. None of these CI gates has been verified on this branch until the workflow executes and logs/artifacts are reviewed.
- PR #1 is the active release-hardening PR; do not use the historical statement that the PR collection was empty.
- No real VPS is connected. No SSH access, fresh install, repair, provider DNS/firewall, external browser/TLS, live rollback, remote Restic backup or restore drill has been performed in this work session.
- A documentation-only follow-up commit will itself trigger a new workflow run; always inspect the latest run against the resulting branch SHA.


## 9. Required close-out format for local AI

At the end of each task, update this file and the relevant docs. Report:
1. What changed and why.
2. Files changed.
3. Tests actually executed and exact result (including skipped/blocked).
4. Commit SHA and branch.
5. Risks or decisions still open.
6. Next smallest independent task.

Do not dump speculative future architecture into code. Implement the smallest safe next increment.


## 10. Expanded canonical context and autonomous policy

Before work on product scope or architecture, read docs/02-master-blueprint.md and docs/09-product-and-service-catalog.md. For domain/API work read docs/10-platform-contracts-and-data-model.md. For security/privacy read docs/11-security-privacy-and-trust.md. For tests, backup, deployment and release read docs/12-operations-quality-and-release.md. For wizard/dashboard/localization read docs/13-onboarding-and-experience.md. Agent authority, issue quality, merge awareness, continuation rules and operator approval boundaries are defined by docs/08-autonomous-agent-operating-model.md.

The agent should make ordinary engineering decisions independently, execute the safe queue end-to-end, and not ask the owner to choose routine implementation details. It must not perform real-host changes, public exposure, destructive production operations, paid-resource creation, live secret rotation or external/legal commitments without operator approval. A blocked high-impact action does not block unrelated repository tasks.


## Follow-up hardening — integration database safety

- Integration tests perform destructive schema cleanup only in a dedicated disposable database.
- The test now fails before connecting unless DB_NAME is exactly `arsy_test`, DB_USER is exactly `arsy_test`, and DB_HOST is loopback (`127.0.0.1`, `::1`, or `localhost`).
- This guard reduces accidental remote/production targeting; CI still must execute on the exact current main SHA before this suite is called verified.

## Release-hardening branch addendum — 2026-11-07

**Branch:** `fix/release-config-validation`  
**PR:** [#1](https://github.com/bjo163/a-r-s-y/pull/1)  
**Base main:** `9bf2d20c725d97dc54900a5048b0f2efcb8df32a`

The branch adds fail-closed deployment environment validation and architecture checks. A follow-up audit found that the new required `ARSY_ENV_LAYOUT_VERSION=2` was not being seeded by either the fresh installer or deploy/repair defaults. Both paths now seed version 2 after legacy migration and before validation. The config regression test also asserts that both paths retain this default. Do not omit this compatibility check in future changes.

CI now also runs npm production dependency audit (high/critical), generates and uploads a CycloneDX SBOM, and builds the production control-plane Docker image. These gates are committed but not yet verified because the latest workflow remains queued with no runner assignment or steps. Subsequent branch commits create newer runs; inspect the latest run on the final branch SHA rather than treating earlier cancelled runs as failures or passes.

Locally executed evidence before this follow-up: isolated validator positive/negative fixture passed. The newly added install/deploy default assertion and full repository CI still require execution. No fresh VPS install, domain/TLS test, off-site backup, restore drill, or independent security review has been performed. Status remains **pre-alpha / not production-ready**.
