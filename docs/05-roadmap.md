# A-R-S-Y — Roadmap and Execution Gates

This roadmap tracks actual delivery, not aspirations. A checked item must exist in code/docs and have evidence. A merged commit is not equivalent to a tested feature.

## M0 — Product foundation and governance

**Entry gate:** repository and product owner agree the single-VPS-first scope, open-source baseline, and explicit operator approval boundaries.

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

**M0 exit:** all first-VPS Definition-of-Done items in `docs/LOCAL_AI_HANDOFF.md` have evidence. A written procedure, mock test, queued CI job or code merge is not equivalent to real-host evidence.

**Current maturity:** Core foundation / pre-alpha. CI execution and real VPS, security-review and backup evidence are still incomplete.

## M1 — ARSY Core alpha (after M0)

**Entry gate:** M0 exit evidence is complete; threat model and tenant authorization boundaries have been reviewed before any customer account is enabled.

**Exit gate:** identity/workspace/project/resource contracts are stable; tenant isolation and negative authorization tests pass; durable provisioning jobs are idempotent, observable and recoverable; public API schemas are versioned and validated in CI.

**Maturity target:** Internal alpha, not a customer production control plane.


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

**Entry gate:** Core alpha has a stable resource/job model and a documented owner for host operations.

**Exit gate:** monitoring/alert routing, incident and recovery runbooks, SBOM/dependency/license evidence, off-site encrypted backups, and measured restore/RPO/RTO are operational and tested on isolated and real replacement infrastructure.

**Maturity target:** Internal alpha progressing to private beta only after operational drills.


- [ ] Monitoring, metrics, dashboards, and actionable alerts.
- [ ] Encrypted off-site backup and tested restore automation.
- [ ] Host hardening guide without silent host mutation.
- [ ] Incident, rollback, disaster-recovery, and support runbooks.
- [ ] SBOM, dependency/image scanning, license inventory, vulnerability disclosure.

## M3 — ARSY Name (DNS)

**Entry gate:** M2 operational baseline is met; domain ownership, tenancy, quotas, audit and abuse policy exist; at least two independent DNS failure domains are designed.

**Exit gate:** zone lifecycle and ownership verification work end-to-end; DNSSEC and secondary nameserver failover are tested; abuse/rate/quota limits and recovery are proven before public delegation.

**Maturity target:** Prototype to internal alpha; no public authoritative-DNS claims until independent infrastructure passes.


- [ ] PowerDNS adapter and zone lifecycle API.
- [ ] Domain ownership verification and DNSSEC workflow.
- [ ] Independent secondary nameserver topology and failure domains before public delegation.
- [ ] Abuse, rate, quota, and audit controls.

## M4 — ARSY Edge + Shield

**Entry gate:** ARSY Name or an equivalent tested domain-control path is available; independent edge capacity and origin protection are designed.

**Exit gate:** versioned routing/cache/WAF policies, telemetry, safe rollback, false-positive tuning and independent edge failure tests pass; volumetric DDoS claims require an upstream provider and measured evidence.

**Maturity target:** Prototype to private beta.


- [ ] Caddy route provisioning and versioned configuration.
- [ ] Evaluate Envoy + Coraza + OWASP CRS with false-positive tuning.
- [ ] Cache policy, purge API, traffic/security telemetry.
- [ ] Independent edge node before customer production claims.

## M5 — ARSY Passage

**Entry gate:** identity, tenant authorization, network policy, abuse response and independent connector trust are reviewed.

**Exit gate:** connector enrollment/revocation/rotation, per-tenant access, audit, health, abuse handling and node-loss recovery pass security tests.

**Maturity target:** Prototype to private beta.


- [ ] Connector enrollment, revocation, and credential rotation.
- [ ] Evaluate FRP or WireGuard-based tunnel adapter.
- [ ] Per-tenant access policy, health, audit, and abuse handling.

## M6 — Commercial foundations

**Entry gate:** product/service catalog, entitlement ownership, support, privacy, acceptable-use and abuse procedures are approved; usage events are attributable and idempotent.

**Exit gate:** append-only usage ledger, quota reconciliation, invoice preview, duplicate/replay tests and provider adapter are verified; no charge is automated before financial, legal and operator approval gates are met.

**Maturity target:** Commercial MVP only after operational support and customer policies are live.


- [ ] Service catalog, versioned plans, quotas, append-only usage ledger.
- [ ] Invoice preview and payment-provider adapter.
- [ ] Terms, privacy, acceptable-use, abuse response, support, and status page.
- [ ] Reconciliation and duplicate-event tests before automated charging.

## M7 — ARSY Vault

**Entry gate:** independent storage capacity and tenant authorization/policy boundaries exist outside the Core Node.

**Exit gate:** S3 API, bucket/key policy, quota/admission, replication, encryption and independent backup/restore/failure tests pass; replication is never presented as backup.

**Maturity target:** Internal alpha to private beta.


- [ ] Independent storage capacity and admission control.
- [ ] S3 API, bucket/key policy, quota, and usage lifecycle.
- [ ] Replication, encryption, backup, and restore tests.

## M8 — ARSY Compute

**Entry gate:** separate compute nodes, tenant isolation model, image provenance and abuse controls are approved; Core Node is excluded from untrusted customer workloads.

**Exit gate:** workload lifecycle, network/resource quotas, node enrollment/revocation, isolation, GitOps/telemetry and recovery tests pass on disposable compute nodes.

**Maturity target:** Prototype to private beta.


- [ ] Separate compute nodes and tenant isolation model.
- [ ] K3s only when separate compute nodes exist.
- [ ] GitOps, resource quotas, network policy, and workload telemetry.
- [ ] No untrusted workloads on control-plane node.

## M9 — IaaS and multi-region

**Entry gate:** independent compute, edge, DNS and storage planes exist in more than one failure domain, with measured operations and customer-facing recovery commitments.

**Exit gate:** VM/network/IP/volume lifecycle, regional failover, data durability and upstream DDoS paths pass controlled failure drills; public SLA/HA/multi-region claims are backed by measured evidence and funded operations.

**Maturity target:** Commercial MVP to generally available only after independent audit and capacity/support readiness.


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
