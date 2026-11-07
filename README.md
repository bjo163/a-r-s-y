# A-R-S-Y

**One command plane. Open by design.**  
*Satu kendali. Infrastruktur terbuka.*

A-R-S-Y is an open hybrid-cloud control plane inspired by the MoonWitness coordination-hub narrative. MoonWitness is the wider narrative universe; A-R-S-Y is its practical infrastructure layer; ZILL Sentinel is the security and observability motif. The Arsy reference is symbolic and does not claim to depict or represent a sacred or metaphysical reality.

## Current status

**Foundation / pre-alpha · single VPS**

The first build provides a small Caddy gateway, a health endpoint, version metadata, a simple update notice, and a consent-based update command. It is not yet the complete cloud control plane.

The customer console, Core API, identity, tenant management, DNS, WAF, tunnel, storage, compute and billing are planned modules; they must not be presented as implemented.

## Install

Supported: Ubuntu 22.04+ or Debian 12+ (amd64/arm64).

Recommended alpha VPS: 8 vCPU, 16 GB RAM, 200 GB NVMe.

\`\`\`bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
\`\`\`

The installer preserves existing Docker/Compose and existing \`.env\` where possible. It uses the loopback-only listener \`127.0.0.1:18080\` by default and does not take over ports 80/443.

Inspect through an SSH tunnel:

\`\`\`bash
ssh -L 18080:127.0.0.1:18080 YOUR_OPERATOR_USER@YOUR_VPS_HOST
\`\`\`

Open \`http://127.0.0.1:18080\`; health endpoint: \`/healthz\`.

## Updates: detect first, ask, then update

A-R-S-Y must never silently update itself.

- The application checks whether a newer commit is available.
- If one is available, it shows an **Update available** notice and asks whether you want to update.
- **Later** leaves the running version untouched.
- **Update now** asks for confirmation.
- For this foundation build, after approval run \`sudo arsy-update\` in the VPS terminal. The authenticated one-click update action will be connected when the Core API is implemented.

Manual check:

\`\`\`bash
sudo arsy-update
\`\`\`

The command compares the installed version with GitHub \`main\`, shows the available commit and asks \`Do you want to update A-R-S-Y now? [y/N]\`. Only an explicit yes starts deployment. No means no changes.

## GitHub behavior

- Pushes and merges to \`main\` run CI checks only.
- Publishing a GitHub Release does not deploy to the VPS.
- No GitHub SSH deploy key or VPS deployment secrets are required.
- A new commit only becomes an available update; it is never installed without approval.

## Safety boundaries for one VPS

- No Kubernetes or CloudStack required on the first VPS.
- No arbitrary customer-code execution on the control-plane host.
- No production DNS delegation to one nameserver failure domain.
- No global CDN, Anycast, volumetric DDoS, HA, or SLA claims without the required network and test evidence.
- Customer data requires encrypted backups outside the VPS/provider failure domain.

## Repository layout

\`\`\`text
install.sh                 # simple single-VPS bootstrap
compose.yaml               # minimal foundation gateway
Caddyfile                  # loopback-only HTTP health + landing page
scripts/arsy-deploy.sh     # low-level exact-commit updater
scripts/arsy-update.sh     # checks version and asks before updating
scripts/arsy-doctor.sh     # diagnostics
site/                      # landing page and version notice
.github/workflows/ci.yml   # CI only; never deploys
brand/                     # SVG mark, wordmark, design tokens
docs/                      # narrative, architecture, update policy, security
\`\`\`

## License

Core source: AGPL-3.0-only. Documentation: CC-BY-SA-4.0 is the intended policy; verify individual file notices before reuse. Brand marks are subject to a separate trademark policy.
