# A-R-S-Y — Product Map and Service Catalog

This is the target product taxonomy, not a claim that listed services exist.

## Product definition
A-R-S-Y is an open, customer-owned infrastructure control plane and future service platform. One management experience coordinates infrastructure through stable contracts, policy and replaceable open-source engines. It is not a Coolify reskin, hosting reseller dashboard or global-cloud imitation on one VPS.

## Product surfaces
- ARSY Console: operator/customer UX, onboarding, catalog, resources, usage, status and support.
- ARSY Core: identity, tenancy, authorization, policy, resource registry, desired state, orchestration, audit, API and jobs.
- ARSY Node: independently deployable data-plane/compute/storage/network nodes enrolled through narrow authenticated contracts.
- ARSY Services: gated infrastructure capabilities.
- ARSY Sentinel: internal security/health observation. ARSY Shield: future customer-facing security capability.
- ARSY CLI: install, diagnostics, repair, explicit host operations and recovery.
- SDKs/integrations: only after API contracts stabilize.

## Service families and gates
1. **Core foundation:** identity, organizations, roles, projects, resources, policy, audit, API keys, jobs, status. Current single-Superadmin alpha is not tenant-ready.
2. **App/container platform:** build/deploy, lifecycle, environment secrets, domains, logs, health, rollback. Requires isolated compute nodes; never run untrusted customer workloads on the control-plane VPS.
3. **DNS/network:** zones, records, IPAM, routing, private networks, gateway. Public authoritative DNS requires independent nameserver failure domains, DNSSEC/key recovery and abuse operations.
4. **Edge/security:** cache, edge routing, WAF, rate limits, TLS, origin protection. CDN claims require distributed measured delivery; volumetric DDoS requires upstream network capability.
5. **Connectivity:** tunnels, connectors, private access, enrollment, rotation, revocation and policy. Requires threat model and least-privilege routing.
6. **Storage/data:** S3-compatible object storage, volumes, snapshots, backup, restore and retention. Backups must leave the primary provider failure domain; replication is not backup.
7. **Compute/IaaS:** container workers, VMs, images, networks, quotas and placement. Requires separate compute/hypervisor nodes and isolation.
8. **Operations/governance:** metrics, logs, traces, incidents, maintenance, audit export, abuse handling and status.
9. **Commercial layer:** plans, quotas, metering, invoices, payments, credits and support. Requires reconciliation, idempotency, legal review and operational ownership.

## Maturity labels
Concept → Prototype → Internal alpha → Private beta → Commercial MVP → Generally available. Every UI and document must use these labels honestly. A blueprint, mockup, branch or issue does not make a feature implemented.

## Build vs integrate
Prefer mature open-source engines behind A-R-S-Y-owned contracts. Evaluate license, governance, maintenance, security response, upgrade path, API maturity, footprint, portability, backup and operational burden. Avoid premature forks and leaking engine-specific details into public APIs.

## First-VPS non-goals
No customer tenant provisioning, public DNS hosting, WAF/CDN, tunnel product, S3, VM marketplace, billing, multi-region, global network, Kubernetes, CloudStack or arbitrary customer workloads. First alpha proves safe install, one operator, private recovery, diagnostics and consent-based lifecycle.
