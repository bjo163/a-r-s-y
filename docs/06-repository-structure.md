# A-R-S-Y — Repository Structure and Module Boundaries

## Current repository (implemented foundation)

```text
.
├── AGENTS.md                         # mandatory local AI/coding-agent instructions
├── README.md
├── install.sh                        # host preflight and install
├── compose.yaml                      # single-VPS runtime
├── Caddyfile                         # default gateway template
├── apps/
│   └── control-plane/
│       ├── src/                      # Fastify app and security helpers
│       ├── public/                   # local browser JS/CSS
│       ├── test/                     # Node test runner
│       ├── schema.sql                # current PostgreSQL bootstrap schema
│       └── Dockerfile
├── scripts/
│   ├── arsy-deploy.sh
│   ├── arsy-update.sh
│   ├── arsy-doctor.sh
│   └── arsy-domain.sh
├── brand/                            # SVG identity and design tokens
├── docs/                             # narrative, blueprint, operations, handoff
└── .github/workflows/                # CI validation
```

Keep this structure simple while the product is a single-VPS modular monolith.

## Target structure (future; do not scaffold prematurely)

When real domain boundaries and ownership justify it, the repository may evolve toward:

```text
apps/
  console/                            # customer/operator UI if separate app is justified
services/
  control-api/                        # modular control-plane API
  control-worker/                     # asynchronous provisioning/reconciliation
  node-agent/                          # future Rust/Go agent; only after trust design
packages/
  contracts/                          # OpenAPI, JSON Schema, generated types
  sdk-typescript/                     # public customer SDK
  ui/                                  # shared ARSY design system
infra/
  compose/                             # local/single-node runtime
  ansible/                             # repeatable host configuration
  opentofu/                            # provider resources where supported
  examples/                            # reference topologies
brand/
docs/
.github/
```

This is a possible target, not a task list. Do not create empty packages, placeholder apps, unused abstractions, or speculative services merely to match the diagram.

## Module boundaries

- Browser UI calls the Fastify API; it never connects directly to PostgreSQL.
- API owns authentication, authorization, validation, and domain rules.
- PostgreSQL is the durable source of truth.
- Host-level operations remain in reviewed CLI scripts, not shell commands exposed to the web process.
- Infrastructure adapters isolate engine-specific APIs when those products are implemented.
- Future workers and node agents receive narrowly scoped commands and never receive unrestricted database or host credentials.
- Contracts become authoritative before exposing a stable public API.

## Rules for extracting modules

Extract a separate deployable only when at least one is demonstrated:
- independent security/trust boundary;
- independent scaling or availability requirement;
- separate ownership/release cadence;
- a concrete operational reason the modular monolith cannot meet.

Do not add Next.js, Keycloak, Kubernetes, a worker, node agent, or SDK just because they appear in future architecture notes.
