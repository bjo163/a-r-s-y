# A-R-S-Y — Master Technical Blueprint

## 1. Product and architecture principles

A-R-S-Y is an open-source infrastructure control plane for customer-owned infrastructure. It begins as a single-VPS operator foundation and evolves toward independently deployable control and data-plane nodes.

1. Separate management, control, and data planes as the product grows.
2. Keep the initial release a modular monolith; do not create distributed services before they solve a real boundary.
3. PostgreSQL is the durable source of truth.
4. Infrastructure engines are replaceable behind explicit adapters.
5. Tenant isolation, auditability, authorization, idempotency, and observability are requirements before customer workloads.
6. A single VPS is a pre-alpha/alpha deployment, not a resilient region.
7. User consent is required for host changes, public exposure, and updates.
8. Documentation distinguishes current implementation from target architecture.

## 2. Current foundation architecture (implemented scope)

```text
Operator browser
  | private SSH tunnel by default
  v
127.0.0.1:18080 (host)
  | Docker port mapping
  v
Caddy gateway
  | private Docker network
  v
Fastify 5 / Node.js 24 :3000
  | PostgreSQL driver
  v
PostgreSQL 17 (named persistent volume)

Host CLI:
  install.sh -> arsy-deploy / arsy-doctor / arsy-update / arsy-domain
Runtime state:
  /opt/arsy/.env
  /var/lib/arsy/deployed-sha
  /var/lib/arsy/Caddyfile
```

The Caddy gateway has a private recovery listener and separate public HTTP/HTTPS listener mappings. Public bindings default to loopback. Managed domain activation changes public bindings only after explicit CLI confirmation. The private SSH-tunnel route must remain available.

### Current stack

| Layer | Current implementation |
|---|---|
| Host install | Bash installer, Ubuntu 22.04+ / Debian 12+ |
| Runtime | Docker Engine + Compose |
| Gateway | Caddy |
| Web/API | Fastify 5, Node.js 24 |
| Database | PostgreSQL 17 |
| UI | Server-rendered HTML, local CSS and browser JS |
| Authentication | First Superadmin, scrypt password hash, opaque DB-backed session |
| Security controls | CSRF/origin checks, rate limits, secure cookie option, audit events |
| Update | GitHub read-only check + exact-SHA operator-approved terminal deploy |
| Host state | `.env`, named DB volume, `/var/lib/arsy` |

## 3. Onboarding and access lifecycle

1. **Preflight/install (CLI):** supported OS/architecture check, resource summary, confirmation, prerequisite installation, secret generation, stack startup, health check.
2. **First Superadmin (Web):** one-time bootstrap token and administrator details; setup closes after successful creation.
3. **Installation profile (Web):** workspace, installation, environment, contact email, timezone, language, node name, access mode, optional hostname/IPv4/proxy settings.
4. **DNS check (Web):** reports observed A/AAAA records and expected IPv4 match. This is diagnostic only; it does not edit DNS.
5. **Access activation (CLI/operator):**
   - Private: SSH tunnel, default and recovery path.
   - Managed domain: user configures DNS A and provider firewall TCP 80/443, reviews and runs `arsy-domain apply`.
   - Existing proxy: user configures their own TLS reverse proxy to loopback; A-R-S-Y does not take over public ports.
6. **Operate:** dashboard, doctor, logs, update detection and explicit update approval.

Saving the onboarding profile does not itself change DNS, provider firewall, host firewall, SSH, or public listener bindings.

## 4. Planes — target evolution, not current feature claims

### Management plane (future)
- ARSY Console for customer and operator experiences.
- Product catalog, documentation, plans, usage, invoices, support, and status.

### Control plane (future)
- ARSY Core API modules for identity, organizations, projects, roles, resources, provisioning, configuration versions, and audit.
- Worker/reconciler for asynchronous jobs.
- Authenticated node agent with narrowly scoped commands and observed-state reporting.
- OpenAPI/JSON Schema contracts and public SDKs.

### Data plane (future)
- Gateway and route adapters.
- DNS authoritative and recursive services.
- Edge/WAF/cache.
- Secure connector/tunnel.
- Object storage.
- Container and VM compute.

No future plane is considered implemented merely because it appears in this blueprint.

## 5. Future technology evaluation

Adopt only when the milestone needs it and license/security/operations are verified.

| Capability | Candidate direction | Gate |
|---|---|---|
| API contracts | OpenAPI + JSON Schema | Stable public API modules |
| Jobs | PostgreSQL-backed queue/worker first | Real asynchronous provisioning |
| Identity federation | OIDC; evaluate Keycloak only when needed | Multiple users/organizations and SSO requirement |
| Secrets | SOPS + age initially; evaluate OpenBao later | Documented recovery and key lifecycle |
| Metrics | Prometheus + Grafana OSS | Operational metrics and alerting requirement |
| IaC | OpenTofu + Ansible | Repeatable multi-host provisioning |
| DNS | PowerDNS + dnsdist | Independent DNS nodes and recovery design |
| Edge/WAF | Caddy first; evaluate Envoy + Coraza | Route scale, threat model, false-positive testing |
| Cache | Apache Traffic Server | Independent edge/cache node |
| Tunnel | FRP prototype or WireGuard-based adapter | Connector enrollment, revocation, and threat model |
| Storage | SeaweedFS or another OSI-approved engine | Independent capacity, replication, backup, restore |
| Container compute | K3s | Separate compute nodes and tenant isolation |
| VM/IaaS | CloudStack + KVM | Dedicated hypervisors and operational maturity |
| Node agent | Rust or Go | mTLS, least privilege, signed desired state |

This is an evaluation map, not a locked dependency list. No component is mandatory until its gate is met.

## 6. Domain model (future customer platform)

Potential entities: user, identity, organization, membership, role, permission, project, environment, region, node, service instance, resource, domain, DNS zone, DNS record, tunnel, connector, origin, edge route, security policy, plan, subscription, quota, usage event, invoice, API key, secret reference, audit event, and provisioning job.

Before customer tenancy:
- Every tenant-owned record must have explicit organization scope.
- Enforce authorization in API queries and mutations; PostgreSQL RLS is defense in depth.
- Define role/permission matrix and cross-tenant negative tests.
- Do not create placeholder CRUD or pretend the current single-Superadmin schema is tenant-ready.

## 7. Provisioning and API contracts (future)

Lifecycle: requested → validating → queued → provisioning → active → updating → deleting → deleted. Failure states: failed and degraded.

- Every side-effecting mutation must be idempotent.
- Desired configuration is versioned; adapters report applied/observed versions.
- Never report active before the target confirms configuration.
- API prefix target: `/api/v1`.
- Structured errors, request IDs, pagination, filtering, audit correlation IDs.
- Signed webhooks with replay protection.
- OpenAPI contract validation in CI before public API release.

## 8. Network and trust boundaries

- Keep PostgreSQL and internal service ports private.
- Never expose Docker API/socket to customer-facing app.
- Do not run untrusted workloads on the control-plane VPS.
- Public DNS requires independent nameserver endpoints/failure domains before customer delegation.
- One VPS cache is not a global CDN.
- Application WAF is not volumetric DDoS protection.
- Do not claim HA, global coverage, Anycast, or SLA without independent infrastructure and evidence.

## 9. Evolution gates

1. **First-VPS foundation:** secure install, Superadmin, onboarding, access, update consent, diagnostics, tested recovery.
2. **Core alpha:** tenant model, RBAC, API keys, resource registry, service catalog, provisioning contracts.
3. **Operations:** backup/restore, monitoring, incident/rollback runbooks, security review.
4. **Network services:** DNS lab then independent nameservers; edge/WAF; connector/tunnel.
5. **Storage and compute:** independent nodes, isolation, metering, backups.
6. **IaaS/multi-region:** dedicated hypervisors, independent regions, tested failover and upstream network capability.

Do not skip an earlier gate because a later technology is attractive.
