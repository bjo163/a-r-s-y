# A-R-S-Y single-node foundation architecture

## Product identity

A-R-S-Y is an open infrastructure control plane inspired by the MoonWitness coordination-hub narrative. MoonWitness is the wider narrative universe; A-R-S-Y is its practical infrastructure layer; ZILL Sentinel is the security and observability motif. The Arsy reference is symbolic and does not claim to embody or represent a sacred or metaphysical reality.

Tagline: One command plane. Open by design.  
Indonesian: Satu kendali. Infrastruktur terbuka.

## v0.1 topology

~~~text
GitHub main
    |
    +--> CI checks only (no VPS deployment)
    |
    +--> Browser checks latest commit
              |
              v
        Update available
          /       \
       Later    Update now
                   |
              Confirmation
                   |
          sudo arsy-update
                   |
             VPS / Docker
                   |
           Caddy : 127.0.0.1:18080
                   |
             /healthz
~~~

The web page can detect a new commit and ask for approval. In this foundation build, the approved action is completed by running the simple local update command on the VPS. A secure one-click app action will be added with the authenticated Core API; do not expose a root shell or Docker socket to the browser.

## Single VPS first

The first node validates installation, product identity, version detection, consent, health checks, and rollback. It deliberately avoids a cluster, public customer DNS delegation, distributed storage, and arbitrary customer workloads.

## Evolution

- Foundation: Docker Compose + Caddy on one VPS; loopback-only listener.
- Core alpha: Next.js console, Fastify modular control API, PostgreSQL, identity, tenant management, audit, and authenticated update action.
- Network services: DNS lab, edge routing, WAF, and tunnel behind replaceable adapters.
- Optional nodes: independent secondary DNS, edge/cache, storage, and compute nodes registered to one control plane.
- Cloud expansion: K3s for container workloads; CloudStack/KVM on dedicated bare-metal hosts for VM/IaaS.

## Technical boundaries

- Management/control plane must be separable from data plane.
- Customer-facing services must be API-first and tenant-scoped.
- Provisioning operations must be idempotent and observable.
- Desired and observed state must be distinct.
- Infrastructure adapters must not leak upstream-specific APIs into the customer domain model.
- A one-node deployment must not be described as HA or globally distributed.
- Updates must be detected and offered; never silently installed.
