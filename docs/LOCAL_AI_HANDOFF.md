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
3. **Existing reverse proxy:** keep A-R-S-Y on loopback and configure the user's proxy to `http://127.0.0.1:18080`. TLS terminates at that proxy. Do not take over public ports.

Current public domain helper is IPv4-only and rejects an AAAA result. Do not describe IPv6 domain activation as supported.

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
- Onboarding profile persistence with workspace, installation, environment, contact, timezone, language, node, access mode, hostname, target IPv4, proxy details; DNS A/AAAA check.
- Dashboard update check, Later dismissal, explicit approval of exact commit SHA, terminal command generation.
- Host scripts: deploy, update, doctor, domain apply/proxy.
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
- `scripts/arsy-deploy.sh`: locked exact-SHA deployment, Compose validation/build/up, health check, best-effort source rollback.
- `scripts/arsy-update.sh`: update discovery and consent gate.
- `scripts/arsy-domain.sh`: managed domain apply and existing proxy instructions.
- `scripts/arsy-doctor.sh`: host and service diagnostic checks.
- `.github/workflows/ci.yml`: Node test/syntax checks and Bash syntax checks. It does not currently run a real VPS test or deploy.

## 5. Immediate engineering priorities (execute in order)

### P0 — establish reliable verification
1. Resolve GitHub Actions runner queue issue; inspect whether jobs start and complete. Do not label queued/cancelled as passing.
2. Add CI validation for Compose configuration using safe dummy environment values; ensure no real secrets are needed.
3. Add shell tests or isolated test harnesses for installer/domain/deploy safety logic where practical.
4. Add integration tests for setup, session, CSRF, onboarding, DNS check, update approval, and health behavior using disposable PostgreSQL.
5. Ensure tests cover the private recovery listener and public listener mapping.

### P1 — harden install/upgrade/domain lifecycle
1. Review fresh install, repair, update, and rollback as separate lifecycle paths.
2. Test that existing `.env`, database volume, deployed SHA, and `/var/lib/arsy/Caddyfile` survive each path.
3. Fix and test migration of any legacy `.env` keys; remove stale ignored variables only with a safe migration plan.
4. Verify domain apply rollback at every failure point: invalid DNS, occupied port, invalid IPv4, Compose failure, gateway restart failure, TLS health timeout.
5. Review IPv4 global-unicast validation; current checks reject common private/shared/loopback/link-local/multicast ranges but are not a complete IANA registry validation.
6. Verify reverse-proxy trust and secure-cookie behavior; document exact trusted proxy assumptions.
7. Check script prerequisites and package availability on supported Ubuntu/Debian releases.

### P2 — finish operator experience
1. Audit onboarding UI against the intended hybrid CLI/Web flow; ensure saved profile is clearly distinguished from actual host activation.
2. Provide a visible step/status summary: install, Superadmin, workspace/profile, node, access mode, DNS check, domain activation, final health.
3. Make public domain instructions explicit about provider firewall being user-managed and no automatic DNS changes.
4. Add clear recovery guidance and diagnostics for SSH tunnel, Caddy, app, DB, DNS, and HTTPS.
5. Ensure update card cannot imply update has been applied merely because approval was recorded.
6. Keep language and timezone selection consistent with persisted settings; do not claim full localization if only profile metadata is stored.

### P3 — security and release gate
1. Review session expiry/rotation, cookie flags, CSRF, proxy IP trust, rate limits, audit metadata, and error logging.
2. Add dependency/license and container image review; generate SBOM only when release workflow is ready.
3. Define backup/restore procedure and execute a restore drill before accepting customer data.
4. Add threat model and security tests before any public beta.
5. Create a release checklist with reproducible CI evidence and real VPS smoke test evidence.

Do not skip P0/P1 to start DNS/edge/compute feature work.

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

## 8. Verification snapshot at handoff

- Latest known `main` before this documentation synchronization: `fad330468f2f29ba8d2ffbaa3e283d5a1cfde7aa`.
- That commit contains the Docker Compose prerequisite fix (`8337917`) and runtime Caddy persistence fix (`fad3304`).
- GitHub Actions run `42358651522` for that SHA was **queued** with no runner assigned when last checked. This is not a pass or a test failure.
- No real VPS is connected to this work session. No SSH access, install, browser, public DNS, TLS, rollback, or backup restore test has been performed here.
- Re-check branch head and latest Actions before starting. This snapshot is historical and must be refreshed by the next agent.

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
