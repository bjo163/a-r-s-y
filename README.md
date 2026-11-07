# A-R-S-Y

**One command plane. Open by design.**  
*Satu kendali. Infrastruktur terbuka.*

A-R-S-Y is an open infrastructure control plane inspired by the MoonWitness coordination-hub narrative. MoonWitness is the wider narrative universe; A-R-S-Y is its practical infrastructure layer; ZILL Sentinel is the security and observability motif. The Arsy reference is symbolic and does not claim to depict or represent a sacred or metaphysical reality.

## Current status

**Single-VPS foundation / pre-alpha — not production-ready.**

The current web foundation includes:
- Branded web console.
- One-time first Superadmin onboarding; no public registration.
- Password login, PostgreSQL-backed sessions, logout, and audit events.
- Installation profile wizard (workspace, installation, node, environment, language/timezone, access mode).
- DNS diagnostic check (does not modify DNS).
- Dashboard update detection and exact-SHA approval flow; updates are never automatic.
- Health endpoint and database readiness check.
- Private SSH-tunnel access, optional managed-domain helper, and existing reverse-proxy guidance.

Customer tenancy, organizations/projects, DNS hosting, WAF/CDN, tunnels, storage, compute, billing, multi-node control, and production backup service are future work.

## Install

Supported host target: Ubuntu 22.04+ or Debian 12+ (AMD64/ARM64).

```bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
```

The installer previews host information and asks for confirmation, installs missing Docker prerequisites, creates secrets, and starts PostgreSQL + web app + private gateway. It does not change firewall or SSH settings or open public ports.

Open the panel privately through SSH:

```powershell
ssh -L 18080:127.0.0.1:18080 USER@VPS
```

Then visit `http://127.0.0.1:18080`.

## First-run flow

1. Create the first Superadmin with the one-time setup key printed by the installer.
2. Complete the Web installation profile.
3. Choose private, managed public domain, or existing reverse proxy.
4. For managed public domain only: create DNS A record, allow TCP 80/443 in provider firewall, then explicitly run `sudo arsy-domain apply --hostname panel.example.com`.
5. Keep private SSH tunnel access for recovery.

The Web profile does not automatically change DNS, firewall, SSH, or public listeners. The existing-proxy mode keeps the service private and expects the user's proxy to terminate TLS.

## Updates: detect first, ask, then update

- **Later** leaves the running installation unchanged.
- **Update now** approves an exact commit SHA and shows a terminal command.
- The operator must run that command on the VPS.
- GitHub pushes/releases never deploy to the VPS.

```bash
sudo arsy-update
sudo arsy-doctor
```

## Documentation and local AI handoff

- [Active execution queue](TODO.md)
- [Local AI handoff and current execution priorities](docs/LOCAL_AI_HANDOFF.md)
- [Master technical blueprint](docs/02-master-blueprint.md)
- [Roadmap and execution gates](docs/05-roadmap.md)
- [Current architecture](docs/ARCHITECTURE.md)
- [Installation and onboarding](docs/INSTALLATION.md)
- [Security policy](docs/SECURITY.md)
- [Update policy](docs/UPDATE_POLICY.md)
- [Repository structure](docs/06-repository-structure.md)
- [Contributing](CONTRIBUTING.md)
- [AI coding-agent rules](AGENTS.md)

Local AI agents must read `AGENTS.md` and `docs/LOCAL_AI_HANDOFF.md` before implementation. Update these documents whenever project state or decisions change.

## One-VPS boundaries

This is not a global CDN or resilient cloud region. Do not claim HA, Anycast, volumetric DDoS protection, public authoritative DNS redundancy, or distributed storage guarantees. Do not execute arbitrary customer code on the control-plane host. Backups for customer data must leave the VPS/provider failure domain.

## License

Core source: AGPL-3.0-only. Documentation: CC-BY-SA-4.0 is the intended policy; verify individual file notices before reuse. Brand marks are subject to a separate trademark policy.


## Complete product and agent blueprint

- [Product and service catalog](docs/09-product-and-service-catalog.md)
- [Platform contracts and data model](docs/10-platform-contracts-and-data-model.md)
- [Security, privacy and trust model](docs/11-security-privacy-and-trust.md)
- [Operations, quality and release](docs/12-operations-quality-and-release.md)
- [Onboarding and product experience](docs/13-onboarding-and-experience.md)
- [Autonomous AI operating model](docs/08-autonomous-agent-operating-model.md)

Local agents must follow AGENTS.md and the autonomous operating model. Routine repository engineering should proceed without user confirmation; high-impact external actions remain operator-approved.
