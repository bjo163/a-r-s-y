# A-R-S-Y — First VPS Deployment Plan

## Purpose

The first server is the ARSY Core Node. It validates product identity, release automation, health checks, rollback, operator access, monitoring, and eventual control plane. It is not the final public edge, DNS, storage, or compute fleet.

## Capacity

| Profile | vCPU | RAM | NVMe | Use |
|---|---:|---:|---:|---|
| Constrained dev | 4 | 8 GB | 100 GB | Development / low-load preview |
| Recommended alpha | 8 | 16 GB | 200 GB | Core platform + trusted test services |
| Comfortable alpha | 8–12 | 32 GB | 300+ GB | More observability and integration tests |

Use a stable public IPv4, IPv6 where available, reasonable transfer quota, provider console access, and an off-site backup destination.

## v0.1 actual deployment

- Docker Engine + Compose.
- Caddy static foundation gateway.
- Loopback-only listener at 127.0.0.1:18080 by default.
- /healthz endpoint.
- GitHub Actions deployment on main pushes and published releases.
- Dedicated SSH deploy user with forced command and no Docker group membership.
- Exact commit checkout, Compose validation, health check, and best-effort rollback.

The customer console, Core API, database, identity, queue, metrics, DNS, WAF, tunnel, storage, and compute are not present in this release. Add these after resource, backup, security, and recovery design is complete.

## One-host restrictions

- No arbitrary customer-supplied code execution.
- No public production S3 service using the same VPS disk as the control plane.
- No claim of HA, regional failover, global CDN, or volumetric DDoS protection.
- No single-host primary/secondary DNS marketing.
- Do not run multiple deployment managers that compete for ports or Docker lifecycle.

## Network policy

- The foundation gateway is loopback-only; public TCP 80/443 are not required for v0.1.
- SSH remains under the existing operator policy; the installer does not rewrite sshd or firewall rules.
- Database, admin, queue, metrics, and internal service ports remain private when added.
- No Docker socket is mounted into a customer-facing API or portal.

## Backup and recovery

Before customer data is accepted: encrypt backups before transfer, store them outside the VPS/provider failure domain, retain a versioned/immutable copy where possible, and perform a restore drill. A VPS snapshot alone is not a backup strategy.
