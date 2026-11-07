# A-R-S-Y

**One command plane. Open by design.**  
*Satu kendali. Infrastruktur terbuka.*

A-R-S-Y is an open hybrid-cloud control plane inspired by the MoonWitness coordination-hub narrative. It aims to make infrastructure understandable, portable, auditable, and operable through one customer experience and documented APIs.

> MoonWitness is the narrative universe. A-R-S-Y is its practical infrastructure layer. ZILL Sentinel is the internal security and observability motif. The Arsy reference is symbolic and does not claim to depict or represent a sacred or metaphysical reality.

## Current status

**Status: Foundation / pre-alpha**

The first release is deliberately a **single-VPS foundation**, not yet a complete cloud provider. It installs Docker Engine/Compose if needed, deploys a small loopback-only Caddy gateway, validates a health endpoint, and supports exact-commit automatic deployment from GitHub Actions.

The customer portal, control API, identity integration, DNS, WAF, tunnel, storage, compute and billing are planned modules; they must not be presented as already implemented.

## Product direction

| Module | Responsibility | Status |
|---|---|---|
| ARSY Core | Control API, tenancy, provisioning, audit | Planned / build next |
| ARSY Console | Customer and operator portal | Planned |
| ARSY Name | Authoritative DNS and zone lifecycle | Lab after core |
| ARSY Edge | Routing, TLS, cache | Single-node foundation gateway only |
| ARSY Shield | WAF, rate limits, security policy | Planned |
| ARSY Passage | Authenticated private-origin tunnel | Planned |
| ARSY Vault | S3-compatible object storage | Deferred to independent capacity |
| ARSY Compute | Container and VM lifecycle | Deferred to isolated nodes |
| ZILL Sentinel | Security telemetry and event correlation | Internal subsystem concept |

## Install on one VPS

Supported: Ubuntu 22.04+ or Debian 12+ (amd64/arm64).

Recommended alpha host: 8 vCPU, 16 GB RAM, 200 GB NVMe. A smaller VPS can be used for development after reviewing resource availability.

```bash
# Download the installer, inspect it, then execute as root.
curl -fsSLo install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less install.sh
sudo bash install.sh
```

The default listener is `127.0.0.1:18080`; it does not take over public ports 80/443 or conflict with an existing Coolify/Dokploy ingress. Inspect it through an SSH tunnel:

```bash
ssh -L 18080:127.0.0.1:18080 YOUR_OPERATOR_USER@YOUR_VPS_HOST
```

Open `http://127.0.0.1:18080`; health endpoint: `/healthz`.

See [Installation](docs/INSTALLATION.md) for the optional GitHub deploy key and host configuration.

## Automatic deployment

`.github/workflows/deploy.yml` deploys the exact commit on every push to `main`, every published GitHub Release, or a manual workflow run. It uses native OpenSSH, pinned host keys, a forced-command deploy key, serialized deployments, health checks, and best-effort rollback.

Required repository Actions secrets:

- `ARSY_DEPLOY_HOST`
- `ARSY_DEPLOY_USER` (`arsy-deploy`)
- `ARSY_DEPLOY_SSH_KEY` (private Ed25519 key)
- `ARSY_DEPLOY_KNOWN_HOSTS` (verified pinned host-key entry)

Detailed setup: [Automatic deployment](docs/AUTO_DEPLOY.md).

## One-VPS safety boundaries

- No Kubernetes or CloudStack on the first VPS by default.
- No customer arbitrary-code execution on the control-plane host.
- No public production DNS delegation to one nameserver failure domain.
- No global CDN, Anycast, volumetric DDoS, HA, or SLA claims without network capacity and test evidence.
- Customer storage and backups must not depend solely on the same VPS disk.
- Optional VPS/node expansion is supported as a future architecture direction, not an installation requirement.

## Repository layout

```text
install.sh                  # single-VPS bootstrap
compose.yaml                # minimal foundation gateway
Caddyfile                   # loopback-only HTTP health + static landing page
scripts/                    # deploy, SSH forced-command gate, diagnostics
.github/workflows/          # main/release automatic deployment
brand/                      # SVG mark, wordmark, design tokens
docs/                       # narrative, architecture, install, security, roadmap
```

## License

Core source: AGPL-3.0-only. Documentation: CC-BY-SA-4.0 is the intended policy; verify individual file notices before reuse. Brand marks are not granted as trademarks by the source license.
