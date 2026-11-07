# A-R-S-Y single-node foundation architecture

## Product identity

A-R-S-Y is an open infrastructure control plane inspired by the MoonWitness coordination-hub narrative. MoonWitness is the narrative universe; A-R-S-Y is the operational infrastructure layer; ZILL Sentinel is the internal security and observability motif. The Arsy reference is symbolic only: the product does not claim to embody or represent a sacred or metaphysical reality.

Tagline: One command plane. Open by design.  
Indonesian: Satu kendali. Infrastruktur terbuka.

## Deployment topology — v0.1 foundation

~~~text
GitHub main / published Release
            |
            v
   GitHub Actions runner
   (native OpenSSH; host key pinned)
            |
            | forced command: deploy <commit SHA>
            v
        VPS / Ubuntu
   +-----------------------+
   | arsy-deploy user      |  No Docker group
   | forced SSH command    |  no PTY/forwarding
   +-----------+-----------+
               | sudo: one root-owned command
               v
   +-----------------------+
   | /usr/local/sbin/      |
   | arsy-deploy           |
   +-----------+-----------+
               |
               v
   +-----------------------+
   | /opt/arsy             |
   | Git checkout          |
   | .env (root-only)      |
   | compose.yaml          |
   | Caddy + static site   |
   +-----------+-----------+
               |
               v
       127.0.0.1:18080
       /healthz + placeholder
~~~

## Why one VPS first

The first node validates provisioning, release automation, health checking, rollback, operator access, and product identity. It deliberately avoids a cluster, multi-tenant arbitrary workloads, customer DNS delegation, storage durability promises, and a second deployment manager.

## Evolution

- Foundation: Docker Compose + Caddy on one VPS; loopback-only listener.
- Core alpha: Next.js console, Fastify modular control API, PostgreSQL, OIDC, worker, audit, backups.
- Network services: DNS lab, edge routing, WAF and tunnel behind service adapters.
- Optional nodes: independent secondary DNS, edge/cache, storage and compute nodes registered to one control plane.
- Cloud expansion: K3s for container workloads; CloudStack/KVM on dedicated bare metal for VM/IaaS.

## Technical boundaries

- Management/control plane must be separable from data plane.
- Customer-facing services must be API-first and tenant-scoped.
- Provisioning operations must be idempotent and observable.
- Desired and observed state must be distinct.
- Infrastructure adapters must not leak upstream-specific APIs into the customer domain model.
- A one-node deployment must not be described as HA or globally distributed.
