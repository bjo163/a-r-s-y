# A-R-S-Y — First VPS Foundation Plan

## Goal

Deliver a safe, understandable first installation on one VPS, operated by one Superadmin. The first host is a Core Node and onboarding/operations foundation. It is not a production cloud region or customer workload host.

## Supported host target

- Ubuntu Server 22.04+ or Debian 12+.
- AMD64 or ARM64.
- Root/sudo for installation.
- Recommended alpha planning profile: 8 vCPU, 16 GB RAM, 200 GB NVMe.
- Constrained development profile: 4 vCPU, 8 GB RAM, 100 GB disk.

These are planning targets; actual compatibility and capacity still require real-host testing.

## Current stack

- Docker Engine + Compose.
- Caddy gateway.
- Fastify 5 / Node.js 24.
- PostgreSQL 17 with named persistent volume.
- Server-rendered HTML, local CSS and JavaScript.
- Bash host utilities for install, deploy, update, doctor, and domain configuration.

## Intended first-run journey

### A. CLI install

1. Download and inspect `install.sh`.
2. Run preflight: OS, architecture, hostname, CPU, memory, disk, Docker, and planned listener summary.
3. Installer asks for confirmation before host changes.
4. Installs missing prerequisites; does not replace an existing Docker Engine when only Compose is missing.
5. Clones the selected `main` revision, generates secrets, creates root-only `.env`, starts PostgreSQL/app/Caddy, waits for health.
6. Prints one-time Superadmin setup key and private URL.
7. Does not edit host firewall or SSH daemon; does not open public ports.

### B. Web first Superadmin

1. Operator connects via SSH tunnel.
2. Enters one-time setup token, display name, email, and password (minimum 14 characters).
3. The database transaction creates the first Superadmin and closes initial setup.
4. There is no public registration route.

### C. Web installation profile

Collect only data needed to configure the installation:
- Workspace name and contact email.
- Installation name and environment (personal/lab/staging/production).
- Node name.
- Timezone and language preference (Indonesian/English).
- Access mode: private, managed public domain, or existing reverse proxy.
- Hostname and optional expected IPv4 for public mode.
- Existing proxy type/TLS intent where relevant.

The profile is saved separately from host activation. It does not change DNS, provider firewall, host firewall, SSH, or gateway bindings by itself.

### D. Access mode and activation

**Private (default):**
- Host listener: `127.0.0.1:18080`.
- Workstation tunnel:
  ```powershell
  ssh -L 18080:127.0.0.1:18080 USER@VPS
  ```
- Browser: `http://127.0.0.1:18080`.
- Retain this path after enabling a public domain.

**Managed public domain:**
- User creates DNS A record pointing to VPS IPv4.
- User allows inbound TCP 80/443 in provider firewall/security group.
- User runs `sudo arsy-domain apply --hostname panel.example.com`.
- Helper checks dependencies, port conflicts, public IPv4, DNS A, and AAAA; prints changes and requires confirmation.
- Caddy manages HTTPS; health check must pass or the previous configuration is restored.
- Current helper is IPv4-only and rejects an AAAA record.

**Existing reverse proxy:**
- A-R-S-Y remains private on loopback port 18080.
- User configures their own proxy upstream to `http://127.0.0.1:18080`.
- TLS must be valid at the existing proxy before Secure cookies are enabled.
- A-R-S-Y does not take over ports 80/443.

## Network layout

- Private recovery: host `127.0.0.1:18080` → Caddy container `:8080`.
- Public HTTP: separate configurable host bind/port → Caddy `:80`.
- Public HTTPS: separate configurable host bind/port → Caddy `:443`.
- Public bind defaults are loopback. Domain helper changes them only after explicit confirmation.
- PostgreSQL is reachable only on the Docker network.
- The app is not published directly to the host.

## Operations

- `sudo arsy-doctor`: host/runtime health overview.
- `sudo arsy-update`: check for updates and ask before deploying.
- `sudo bash /opt/arsy/install.sh --repair`: explicit repair/reinstall.
- Docker Compose logs and status are available under `/opt/arsy`.
- Preserve `.env`, named PostgreSQL volume, deployed SHA, and `/var/lib/arsy/Caddyfile`.

## Not in first-VPS scope

No mandatory second VPS, Kubernetes/K3s, CloudStack, Keycloak, DNS provider API credentials, cloud provider tokens, billing account, SSH private key, public DNS hosting, WAF product, CDN, tunnel product, object storage, customer compute, or arbitrary customer workloads.

## Acceptance gates

- Clean install on supported distro/architectures.
- Private tunnel and recovery access verified.
- One-time setup, login/logout, session, CSRF, rate limits, and audit tested.
- Profile persists and reloads.
- DNS check handles no record, A match/mismatch, and AAAA clearly.
- Public activation requires DNS/provider firewall preparation and explicit approval.
- Existing proxy instructions are accurate.
- Update exact-SHA consent and rollback preserve state.
- CI passes and a real VPS smoke test is recorded.
- Encrypted off-site backup and restore drill completed before customer data is accepted.

Until then, the project remains pre-alpha.
