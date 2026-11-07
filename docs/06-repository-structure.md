# A-R-S-Y repository structure

Start with a modular monolith in one repository. Split deployables only when ownership, deployment cadence, scale, or a security boundary demands it.

~~~text
apps/
  console/                 # Next.js customer/operator portal
services/
  control-api/             # Fastify modular monolith
  control-worker/          # provisioning and reconciliation
  node-agent/              # future Rust/Go agent; do not stub early
packages/
  contracts/               # OpenAPI, JSON Schema, typed contracts
  sdk-typescript/           # public customer SDK
  ui/                       # ARSY design system
infra/
  compose/                  # single VPS alpha
  ansible/                  # host provisioning and hardening
  opentofu/                 # provider resources where supported
  examples/                 # reference deployment topologies
brand/                      # SVG mark, wordmark, design tokens
docs/                       # narrative, brand, architecture, operations
.github/
  ISSUE_TEMPLATE/
  workflows/
  PULL_REQUEST_TEMPLATE.md
~~~

## Module boundaries

- The console talks only to the public control API; it never connects directly to PostgreSQL.
- The control API owns authorization and domain rules.
- The worker consumes jobs and reconciles desired state.
- Contracts are the source of truth for public API shapes.
- Infrastructure adapters isolate PowerDNS, Envoy, FRP, and storage-specific APIs.
- Node agents receive narrowly scoped commands and never receive unrestricted control-plane database credentials.

## Initial API modules

identity, tenancy, projects, catalog, domains, dns, edge, tunnels, secrets, usage, billing, audit, nodes, provisioning, and support.

Keep them as internal modules until independent deployment or scaling is justified.
