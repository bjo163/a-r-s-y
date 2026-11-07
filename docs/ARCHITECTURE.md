# A-R-S-Y single-node foundation architecture

## Product identity

A-R-S-Y is an open infrastructure control plane inspired by the MoonWitness coordination-hub narrative. MoonWitness is the wider narrative universe; A-R-S-Y is its practical infrastructure layer; ZILL Sentinel is the security and observability motif. The Arsy reference is symbolic and does not claim to embody or represent a sacred or metaphysical reality.

Tagline: One command plane. Open by design.  
Indonesian: Satu kendali. Infrastruktur terbuka.

## v0.2 single-VPS topology

~~~text
Browser (via SSH tunnel)
        |
        v
Caddy : 127.0.0.1:18080
        |
        v
Fastify Control Plane :3000
  |       |          |
  |       |          +-- GitHub update check (read-only)
  |       |
  |       +-- PostgreSQL sessions, users, settings, audit
  |
  +-- Setup / Login / Superadmin dashboard
        |
        +-- consent prompt --> exact approved update command

PostgreSQL : private Docker network only
~~~

## First-boot onboarding

- Installer creates a one-time random setup key in the root-only .env file.
- /setup accepts the key and first Superadmin details.
- A database transaction serializes initial enrollment and creates exactly one first Superadmin.
- setup_completed=true closes the route permanently.
- Login uses scrypt password hashes and PostgreSQL-backed opaque sessions.
- Session cookies are HttpOnly, SameSite=Strict, and Secure when HTTPS is configured.
- State-changing API requests require same-origin checks and a CSRF token.
- Setup and login are rate-limited; audit events record authentication outcomes.

## Update lifecycle

A-R-S-Y checks GitHub main from an authenticated dashboard. Detection never changes the VPS. Approval records the exact target SHA and renders a command. The operator runs that command in the VPS terminal. The host deploy runner uses a lock, fetches the target, validates Compose, builds the app, starts services, and checks /healthz. It attempts rollback to the last known-good source revision if deployment fails.

GitHub Actions runs CI only; it never SSH-deploys to the host.

## Technology

| Component | Technology |
|---|---|
| Web + API | Fastify 5 / Node.js 24 |
| Database | PostgreSQL 17 |
| Gateway | Caddy |
| Container runtime | Docker Engine + Compose |
| Password hashing | Node.js scrypt |
| Sessions | Opaque tokens stored hashed in PostgreSQL |
| UI | Server-rendered HTML + local CSS/JS |

## Evolution

- Foundation: one VPS, Caddy + Fastify + PostgreSQL.
- Core alpha: tenant/project management, API keys, audit, resource registry, authenticated update agent.
- Network services: DNS lab, edge routing, WAF and tunnel behind replaceable adapters.
- Optional nodes: independent secondary DNS, edge/cache, storage and compute nodes.
- Cloud expansion: K3s for container workloads; CloudStack/KVM on dedicated bare-metal hosts for VM/IaaS.

## Technical boundaries

- Management/control plane must be separable from data plane.
- Every customer resource must be tenant-scoped before customer onboarding.
- Provisioning operations must be idempotent and observable.
- A one-node deployment must not be described as HA or globally distributed.
- Arbitrary customer workloads must not run on the control-plane host.
