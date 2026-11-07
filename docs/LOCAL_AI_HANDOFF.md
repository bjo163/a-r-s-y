# A-R-S-Y — Local AI Handoff

> Purpose: working context for local coding agents. Read before touching code and keep current.

**Repository:** \`bjo163/a-r-s-y\`  
**Product:** A-R-S-Y — *One Command Plane. Open by Design.*  
**Current stage:** single-VPS foundation / pre-alpha.  
**Primary goal:** finish and verify first-VPS onboarding and operations before expanding the cloud roadmap.

## Product and authority

A-R-S-Y is an open-source, customer-owned infrastructure control plane, not a Coolify reskin or a global cloud on one VPS. Start with one VPS and one operator. Keep the first release a modular monolith: Node.js 24, Fastify 5, PostgreSQL 17, Caddy, Docker Engine and Compose.

Use hybrid CLI/Web onboarding. CLI owns host preflight, prerequisites, domain activation and host operations. Web owns first Superadmin setup, installation profile, timezone/language preference and DNS observation. No public registration. Private SSH tunnel is the default and recovery path.

Never silently change firewall/SSH, expose public ports, deploy updates, restart production, delete persistent data, spend money or publish customer data. Public domain activation requires operator-managed DNS A/provider firewall and explicit CLI confirmation. Updates require exact-SHA approval and operator execution. No CI auto-deploy. Do not run arbitrary customer workloads on the control-plane host or expose Docker socket to the app.

## Implemented foundation

- Fastify web/API, PostgreSQL schema, Caddy gateway and Docker Compose.
- Installer for Ubuntu 22.04+ / Debian 12+, AMD64/ARM64 (real-host acceptance pending).
- One-time Superadmin bootstrap, scrypt password hashes, opaque PostgreSQL sessions, CSRF/origin protection, rate limits and audit events.
- Onboarding profile, DNS A/AAAA diagnostics, dashboard readiness and exact-SHA update approval.
- Private SSH listener 127.0.0.1:18080; existing same-host proxy ingress 127.0.0.1:18082; managed public listener remains loopback until explicit activation.
- Host scripts for deploy/update/doctor/domain, env migration, config validation, IPv4 validation, encrypted remote backup and isolated PostgreSQL restore drill.
- Runtime Caddy config persisted at /var/lib/arsy/Caddyfile.

Not implemented: tenant RBAC/invitations/API keys, provisioning/job engine, authoritative DNS, WAF/CDN, tunnels, S3, customer compute, billing, MFA/OIDC, secrets manager, multi-node, K3s/CloudStack, multi-region or HA.

## Current release-hardening branch

Branch \`fix/release-config-validation\` adds:
- \`scripts/arsy-config-validate.sh\`: fail-closed validation for required and unique managed .env keys, non-empty secrets, PostgreSQL identifiers, listener port ranges/uniqueness, supported bind addresses and cookie mode.
- Installer rejects unsupported CPU architectures before host changes and validates environment before deployment.
- Deploy/repair validates environment after migration/defaulting but before pulling images or changing the stack; on validation failure it restores the original .env through existing rollback handling.
- Negative tests cover empty/duplicate keys, invalid ports/binds, duplicate listener ports and unsafe database identifiers.
- CI invokes the new tests and has a 30-minute job timeout.
These changes are not verified until CI runs to completion on the branch and resulting main SHA.

## CI and release blockers

Latest main SHA before this branch: \`9bf2d20c725d97dc54900a5048b0f2efcb8df32a\`. Latest Actions run checked: [42370496335](https://github.com/bjo163/a-r-s-y/actions/runs/42370496335). Its validate job is queued with runner_id=0 and zero steps; this is neither a pass nor a failure. Repository/org Actions administrator must inspect hosted runner availability/quotas, Actions policy and GitHub status. Do not weaken permissions or bypass checks.

Still required:
1. CI terminal success with actual logs reviewed on exact SHA.
2. Dependency/image/license/secret/vulnerability review and SBOM.
3. Fresh install on Ubuntu and Debian, each claimed architecture.
4. Repair/update/rollback and private recovery on disposable real VPS.
5. Managed-domain TLS from external network and existing-proxy secure-cookie validation.
6. Encrypted off-site Restic backup, independently recoverable password, successful isolated restore drill and replacement-host rehearsal.
7. Independent application/host security review and release evidence record.

No real VPS has been installed or tested in this work session. Do not claim production readiness until these gates have evidence. Current status remains **pre-alpha / not production-ready**.

## Commands

\`\`\`bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
sudo arsy-doctor
sudo arsy-config-validate /opt/arsy/.env
sudo arsy-update
\`\`\`

Private access:
\`\`\`powershell
ssh -L 18080:127.0.0.1:18080 USER@VPS
\`\`\`

Never use \`docker compose down -v\` for routine repair/update.

## Close-out

Report changes, files, exact tests/results including blocked/skipped, commit and branch/PR/merge state, residual risks and next smallest task. Never turn a queued workflow, committed test or runbook into a false completion claim.
