# A-R-S-Y — Current Foundation Architecture

## Product identity

A-R-S-Y is an open infrastructure control plane and the practical infrastructure layer within the wider MoonWitness universe. ZILL Sentinel is an internal security/observability motif. Brand references are symbolic and do not claim sacred or metaphysical authority.

**Tagline:** One command plane. Open by design.

## Current single-VPS topology

```text
Operator browser
    | SSH tunnel (default/recovery)
    v
Host 127.0.0.1:18080
    |
    v
Caddy gateway :8080 (container)
    |
    v
Fastify 5 / Node.js 24 :3000
    |
    +---- PostgreSQL 17 (private Docker network)

Optional public route after explicit activation:
Host public bind:80  ---> Caddy :80
Host public bind:443 ---> Caddy :443
                         |
                         +--> Fastify app

Host CLI:
install.sh | arsy-deploy | arsy-update | arsy-doctor | arsy-domain

Persistent state:
  /opt/arsy/.env
  Docker named volume: arsy_postgres
  /var/lib/arsy/deployed-sha
  /var/lib/arsy/Caddyfile
```

Public listener binds default to loopback. The managed domain helper changes them to public binds only after validation and operator confirmation. Private SSH recovery remains available.

## First boot and onboarding

1. CLI installer preflights host and asks for confirmation.
2. Installer installs missing dependencies, creates secrets, starts services, and waits for health.
3. A one-time setup token creates the first Superadmin. Setup then closes.
4. Superadmin logs in and completes installation profile: workspace, installation, environment, contact email, timezone, language, node name, access mode, and optional domain/proxy details.
5. DNS check is diagnostic only.
6. Public activation is a separate operator CLI action; saving profile does not modify host or provider network settings.

## Security controls currently present

- scrypt password hashes.
- Opaque session tokens stored as keyed digests in PostgreSQL.
- HttpOnly/SameSite cookie configuration; Secure flag depends on HTTPS configuration.
- CSRF token and same-origin protections on state-changing routes.
- Fastify trusts one immediate proxy hop (Caddy). SSH recovery (18080) and same-host proxy ingress (18082) are separate loopback listeners; only the latter forwards sanitized metadata from the local proxy.
- Setup/login rate limits.
- Audit events for setup and authentication/update actions.
- Private database network; no public DB port.
- Root-owned environment file with restrictive permissions.
- Host firewall and SSH daemon are not modified by installer.

These controls do not equal a completed security audit or production security certification.

## Update lifecycle

- Dashboard checks GitHub main without deploying.
- Later dismisses the notice; Update now approves the exact SHA and displays a terminal command.
- Operator runs the command on the VPS.
- Host deploy script uses a lock, fetches the exact target, validates Compose, builds and starts services, checks health, and attempts source rollback.
- Runtime Caddy configuration is kept under `/var/lib/arsy` so source checkout does not replace it.
- GitHub Actions runs validation only; it never deploys to a VPS.

## Technology

| Component | Technology |
|---|---|
| Host | Ubuntu 22.04+ / Debian 12+ |
| Runtime | Docker Engine + Compose |
| Gateway | Caddy |
| Web/API | Fastify 5 / Node.js 24 |
| Database | PostgreSQL 17 |
| UI | Server-rendered HTML + local CSS/JS |
| Password hashing | Node.js scrypt |
| Sessions | Opaque tokens stored hashed in PostgreSQL |

## Boundaries

- Current implementation is a single-Superadmin foundation, not tenant-ready cloud control plane.
- No public DNS hosting, production WAF/CDN, tunnel/storage/compute products, billing, or multi-node agent yet.
- Do not run arbitrary customer workloads on the control-plane host.
- Do not claim HA, global CDN, Anycast, volumetric DDoS, or SLA.
- See `docs/02-master-blueprint.md` for future architecture and explicit adoption gates.
