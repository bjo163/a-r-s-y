# A-R-S-Y — Roadmap

## M0 — Foundation and governance

- [x] Product narrative and MoonWitness relationship.
- [x] Brand system and initial SVG concepts.
- [x] Single-VPS architecture and security boundaries.
- [x] Docker Compose foundation gateway and installer.
- [x] App-side version comparison and update-available notice.
- [x] Consent-based update command.
- [x] GitHub CI without automatic VPS deployment.
- [ ] VPS installation and health verification.
- [ ] Backup destination and restore drill.

## M1 — ARSY Core alpha

- [ ] Next.js customer/operator console.
- [ ] Fastify modular control API.
- [ ] PostgreSQL schema and tenant-scoping tests.
- [ ] OIDC identity, operator MFA, organization/project membership.
- [ ] Resource registry, audit log, API keys.
- [ ] Idempotent provisioning jobs and OpenAPI contract.
- [ ] Authenticated one-click update action; only after explicit operator confirmation.

## M2 — Operations baseline

- [ ] Prometheus/Grafana monitoring and alerting.
- [ ] Encrypted off-site backup and successful restore drill.
- [ ] Host hardening and private admin access.
- [ ] Incident, rollback, and recovery runbooks.

## M3 — ARSY Name

- [ ] PowerDNS adapter and zone lifecycle API.
- [ ] Domain ownership verification and DNSSEC.
- [ ] Independent secondary nameserver topology before public delegation.

## M4 — ARSY Edge + Shield

- [ ] Caddy route provisioning and configuration versioning.
- [ ] Envoy + Coraza + OWASP CRS evaluation and false-positive tuning.
- [ ] Cache policy, purge API, traffic and security telemetry.
- [ ] Independent edge node before customer production claims.

## M5 — ARSY Passage

- [ ] Connector enrollment, revocation, and credential rotation.
- [ ] FRP or WireGuard-based tunnel adapter.
- [ ] Per-tenant access policies, health, and audit.

## M6 — Commercial foundations

- [ ] Service catalog, plans, quotas, append-only usage ledger.
- [ ] Invoice preview and payment-provider adapter.
- [ ] Terms, privacy, acceptable-use, abuse response, support, and status page.

## M7 — ARSY Vault

- [ ] Independent storage capacity and admission control.
- [ ] S3 API, bucket/key policy, quota, and usage lifecycle.
- [ ] Replication, encryption, backup, and restore tests.

## M8 — ARSY Compute

- [ ] Separate compute nodes and tenant isolation model.
- [ ] K3s, GitOps, resource quotas, network policy, and workload telemetry.
- [ ] No untrusted workloads on the control-plane node.

## M9 — IaaS and multi-region

- [ ] Dedicated KVM hypervisors and CloudStack.
- [ ] VM image, network, IP, volume, and quota lifecycle.
- [ ] Multiple edge regions and independent DNS locations.
- [ ] Regional failover, upstream DDoS mitigation, and BGP/Anycast only when ready.
