# A-R-S-Y — Master Technical Blueprint

## Architecture rules

1. Separate management, control, and data planes.
2. Treat every customer-facing capability as an API-backed product.
3. Multi-tenancy, auditability, quotas, and idempotency are foundational.
4. Keep infrastructure engines replaceable behind adapters.
5. Start with the simplest working single-node topology; add distributed components only when an independent node is available.
6. A single VPS is an alpha environment, not a resilient cloud region.

## Planes

### Management plane
- ARSY Console: customer portal and operator console.
- Product catalog, documentation, plans, usage, invoices, and support.

### Control plane
- ARSY Core API: organizations, projects, members, roles, resources, provisioning, configuration versions, and audit.
- ARSY Worker: asynchronous provisioning and reconciliation.
- Future node agent: authenticated node registration, desired-state polling, apply, and observed-state reporting.
- PostgreSQL is the durable source of truth.

### Data plane
- Initial HTTP gateway: Caddy on the first VPS.
- DNS: PowerDNS Authoritative and dnsdist, initially lab-only.
- Edge: Envoy and Coraza after route and security tests.
- Cache: Apache Traffic Server on a dedicated edge/cache node.
- Tunnel: FRP prototype or a WireGuard-based adapter.
- Storage: SeaweedFS when independent capacity and backup exist.
- Compute: trusted Docker Compose alpha, K3s on separate compute nodes, CloudStack/KVM for VM products later.

## Target control-plane stack

| Layer | Technology |
|---|---|
| Customer portal | Next.js + TypeScript |
| Control API | Fastify + TypeScript modular monolith |
| API contracts | OpenAPI + JSON Schema |
| Primary state | PostgreSQL |
| Early job queue | PostgreSQL-backed worker |
| Identity | Keycloak OIDC |
| Single-node ingress | Caddy |
| Secrets | SOPS + age initially; OpenBao after recovery design |
| Metrics | Prometheus + Grafana OSS |
| Host deployment | Docker Engine + Compose |
| Infrastructure as Code | OpenTofu + Ansible |
| Future node agent | Rust or Go with mTLS |

## Domain model

Minimum entities include user, identity, organization, membership, role, permission, project, environment, region, node, service instance, resource, domain, DNS zone, DNS record, tunnel, connector, origin, edge route, security policy, plan, subscription, quota, usage event, invoice, API key, secret reference, audit event, and provisioning job.

Every tenant-owned record must carry an organization scope. Enforce authorization in the API and use PostgreSQL Row-Level Security as defense in depth.

## Provisioning lifecycle

requested → validating → queued → provisioning → active → updating → deleting → deleted

Failure states include failed and degraded. Every mutation must be idempotent and include a request/idempotency key. Desired configuration is versioned; data-plane adapters report applied/observed versions. Never report active before the target service confirms the configuration.

## API conventions

- Prefix: /api/v1.
- OIDC for user sessions; scoped API keys for automation.
- Resource-level authorization and tenant scoping on every route.
- Idempotency keys for create/update operations with side effects.
- Pagination, filtering, structured errors, request IDs, audit correlation IDs.
- OpenAPI contract checked in CI.
- Webhooks signed per endpoint with replay protection.

## Network reality

A public authoritative DNS product needs independent nameserver endpoints and failure domains. Do not delegate a customer zone to two names that resolve to one VPS and call it redundant. A cache proxy on one VPS is not a global CDN. Volumetric DDoS mitigation requires upstream network capacity and coordination; application WAF alone is not equivalent.

## Evolution

- Alpha: Compose on one VPS.
- Beta: separate DNS/edge nodes plus node registration and reconciliation.
- Growth: K3s for container compute and independent storage.
- IaaS: CloudStack + KVM on dedicated bare-metal hypervisors.
- Global: multiple edge regions, independent DNS locations, routing/Anycast capability, and upstream DDoS arrangements.
