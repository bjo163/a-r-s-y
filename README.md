# A-R-S-Y

**One command plane. Open by design.**  
*Satu kendali. Infrastruktur terbuka.*

A-R-S-Y is an open hybrid-cloud control plane inspired by the MoonWitness coordination-hub narrative. MoonWitness is the wider narrative universe; A-R-S-Y is its practical infrastructure layer; ZILL Sentinel is the security and observability motif. The Arsy reference is symbolic and does not claim to depict or represent a sacred or metaphysical reality.

## Current status

**Foundation / pre-alpha · one VPS**

The first usable web foundation includes:
- Branded web console.
- One-time first Superadmin onboarding.
- Password login, PostgreSQL-backed sessions, logout, and audit events.
- Dashboard showing the Core Node and planned infrastructure modules.
- Health endpoint and database readiness check.
- Update detection from the app. Updates are never installed automatically.

DNS, WAF, CDN, tunnel, storage, compute, customer billing, additional users, and multi-node management are future milestones; the first dashboard does not pretend those services are already implemented.

## Install

Supported: Ubuntu 22.04+ or Debian 12+ (amd64/arm64).

Recommended alpha VPS: 8 vCPU, 16 GB RAM, 200 GB NVMe.

Download and inspect the installer, then run it:

~~~bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
~~~

The installer installs Docker Engine/Compose when needed, creates /opt/arsy, generates database/session/setup secrets, starts PostgreSQL + the web app + the private gateway, and runs a health check. Existing .env values are preserved.

The gateway listens on 127.0.0.1:18080; it does not take over public ports 80/443. Inspect the app from your workstation through SSH:

~~~bash
ssh -L 18080:127.0.0.1:18080 YOUR_OPERATOR_USER@YOUR_VPS_HOST
~~~

Open http://127.0.0.1:18080.

## First Superadmin onboarding

The installer prints a one-time bootstrap key after installation. Keep it private.

1. Open the web app and go to the initial setup page.
2. Paste the bootstrap key.
3. Enter the Superadmin display name, email, and a password of at least 14 characters.
4. Submit once. A-R-S-Y creates the first Superadmin and opens the dashboard.

To retrieve the key later from the VPS:

~~~bash
sudo grep '^ARSY_SETUP_TOKEN=' /opt/arsy/.env
~~~

Initial setup closes permanently after the first Superadmin is created. There is no public registration route. The setup key is not a substitute for TLS; keep the first setup private through an SSH tunnel.

## Updates: detect first, ask, then update

A-R-S-Y must never silently update itself.

- The dashboard checks GitHub main and shows a notice if a newer commit exists.
- **Later** keeps the current version untouched.
- **Update now** records your approval for the exact commit and displays a command.
- Run the displayed command in the VPS terminal to apply that exact approved commit.
- A normal terminal check also asks before changing anything.

~~~bash
sudo arsy-update
~~~

GitHub pushes and releases run CI or make a version available; they do not deploy to the VPS.

## Repair / reinstall

An explicit repair is available when you choose to run the installer again:

~~~bash
sudo bash /opt/arsy/install.sh --repair
~~~

It preserves .env and the PostgreSQL volume. Do not use docker compose down -v; that deletes the database volume.

## Useful commands

~~~bash
sudo arsy-doctor
sudo arsy-update
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml ps
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml logs -f app
~~~

## One-VPS boundaries

- This is a pre-alpha control plane, not a global CDN or public cloud region.
- Do not delegate customer DNS to one nameserver failure domain.
- Do not claim HA, Anycast, volumetric DDoS protection, or distributed-storage guarantees.
- Do not execute arbitrary customer code on the control-plane host.
- Backups for customer data must leave the VPS/provider failure domain.
- When the app is exposed through HTTPS, set ARSY_COOKIE_SECURE=true in /opt/arsy/.env and redeploy with an explicitly approved update.

## License

Core source: AGPL-3.0-only. Documentation: CC-BY-SA-4.0 is the intended policy; verify individual file notices before reuse. Brand marks are subject to a separate trademark policy.
