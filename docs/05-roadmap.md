# A-R-S-Y — Roadmap and Execution Gates

This roadmap tracks actual delivery, not aspirations. A checked item must exist in code/docs and have evidence. A merged commit is not equivalent to a tested feature.

## M0 — Product foundation and governance

- [x] Product narrative and MoonWitness relationship.
- [x] Brand system and initial SVG concepts.
- [x] Single-VPS-first architecture and explicit non-goals.
- [x] Docker Compose foundation and installer.
- [x] Consent-first update detection and exact-SHA approval flow.
- [x] GitHub CI workflow (workflow exists; execution is not yet verified green).
- [x] Fastify web console and health endpoint.
- [x] One-time first Superadmin onboarding.
- [x] Login/logout, PostgreSQL-backed sessions, and audit events.
- [x] Installation profile wizard and DNS diagnostic endpoint.
- [x] Private SSH tunnel, managed-domain helper, and existing-proxy guidance.
- [ ] CI consistently completes successfully on current main.
- [ ] Fresh install and repair tested on real supported VPS.
- [ ] Managed domain HTTPS, private recovery, failure rollback tested on real VPS.
- [ ] Encrypted off-site backup and successful restore drill.
- [ ] Security review and release readiness checklist.

**M0 exit:** all first-VPS Definition-of-Done items in `docs/LOCAL_AI_HANDOFF.md` have evidence.

## M1 — ARSY Core alpha (after M0)

- [ ] Confirm tenant model and threat model.
- [ ] Organization/workspace model and membership lifecycle.
- [ ] Project and environment management.
- [ ] Tenant-scoped RBAC and negative cross-tenant tests.
- [ ] Scoped, revocable API keys.
- [ ] Resource registry and service catalog.
- [ ] OpenAPI/JSON Schema contract and CI validation.
- [ ] Idempotent provisioning request model and durable job lifecycle.
- [ ] Authenticated update/host agent design only after least-privilege boundary is reviewed.

## M2 — Operations baseline

- [ ] Monitoring, metrics, dashboards, and actionable alerts.
- [ ] Encrypted off-site backup and tested restore automation.
- [ ] Host hardening guide without silent host mutation.
- [ ] Incident, rollback, disaster-recovery, and support runbooks.
- [ ] SBOM, dependency/image scanning, license inventory, vulnerability disclosure.

## M3 — ARSY Name (DNS)

- [ ] PowerDNS adapter and zone lifecycle API.
- [ ] Domain ownership verification and DNSSEC workflow.
- [ ] Independent secondary nameserver topology and failure domains before public delegation.
- [ ] Abuse, rate, quota, and audit controls.

## M4 — ARSY Edge + Shield

- [ ] Caddy route provisioning and versioned configuration.
- [ ] Evaluate Envoy + Coraza + OWASP CRS with false-positive tuning.
- [ ] Cache policy, purge API, traffic/security telemetry.
- [ ] Independent edge node before customer production claims.

## M5 — ARSY Passage

- [ ] Connector enrollment, revocation, and credential rotation.
- [ ] Evaluate FRP or WireGuard-based tunnel adapter.
- [ ] Per-tenant access policy, health, audit, and abuse handling.

## M6 — Commercial foundations

- [ ] Service catalog, versioned plans, quotas, append-only usage ledger.
- [ ] Invoice preview and payment-provider adapter.
- [ ] Terms, privacy, acceptable-use, abuse response, support, and status page.
- [ ] Reconciliation and duplicate-event tests before automated charging.

## M7 — ARSY Vault

- [ ] Independent storage capacity and admission control.
- [ ] S3 API, bucket/key policy, quota, and usage lifecycle.
- [ ] Replication, encryption, backup, and restore tests.

## M8 — ARSY Compute

- [ ] Separate compute nodes and tenant isolation model.
- [ ] K3s only when separate compute nodes exist.
- [ ] GitOps, resource quotas, network policy, and workload telemetry.
- [ ] No untrusted workloads on control-plane node.

## M9 — IaaS and multi-region

- [ ] Dedicated KVM hypervisors and CloudStack.
- [ ] VM image, network, IP, volume, and quota lifecycle.
- [ ] Multiple edge regions and independent DNS locations.
- [ ] Tested regional failover and upstream DDoS arrangements before related claims.

## Current execution order

1. P0 CI and automated test reliability.
2. P1 install/repair/update/domain lifecycle regression coverage.
3. P2 onboarding and operator UX completion.
4. P3 security, backup/restore, real-VPS release gate.
5. Only then begin M1 tenant/Core product implementation.

See `docs/LOCAL_AI_HANDOFF.md` for detailed tasks and acceptance criteria.


## Autonomous execution and cross-document rules

The active queue is TODO.md. Agent execution, issue/PR lifecycle, merge awareness, verification and operator approval boundaries are defined in docs/08-autonomous-agent-operating-model.md. Product maturity and service entry gates are defined in docs/09-product-and-service-catalog.md. API/resource contracts, security, operations and UX requirements are in docs/10 through docs/13. These documents are normative together; no roadmap item authorizes bypassing an earlier gate or an operator-approval boundary.
