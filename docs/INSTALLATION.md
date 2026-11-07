# Single VPS installation

## Supported host

- Ubuntu Server 22.04+ or Debian 12+.
- amd64 or arm64.
- Recommended alpha: 8 vCPU, 16 GB RAM, 200 GB NVMe.
- Constrained development: 4 vCPU, 8 GB RAM, 100 GB SSD.

The first build is a small Caddy gateway with a health endpoint and version notice. The complete customer console, Core API, identity, DNS, WAF, tunnel, storage, compute, and billing are not implemented yet.

## Install

Download and inspect the installer, then run it:

~~~bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
~~~

The installer:
- Checks Ubuntu 22.04+ or Debian 12+.
- Installs Docker Engine and Compose only if required.
- Clones A-R-S-Y into /opt/arsy or reuses an existing checkout.
- Creates /opt/arsy/.env on first install and preserves it on later runs.
- Starts the foundation gateway and checks /healthz.
- Installs the local consent-based update command as /usr/local/sbin/arsy-update.

It does not edit firewall or SSH daemon policy. It does not take over ports 80/443.

## Inspect

The listener defaults to 127.0.0.1:18080. From your workstation:

~~~bash
ssh -L 18080:127.0.0.1:18080 YOUR_OPERATOR_USER@YOUR_VPS_HOST
~~~

Open http://127.0.0.1:18080. Health endpoint: /healthz.

## Updates

The app checks GitHub main and displays an update notice if a newer commit exists. It never changes the running system without approval.

For this foundation build, apply an approved update from the VPS:

~~~bash
sudo arsy-update
~~~

The command displays current and available versions and asks for confirmation. Press Enter or answer anything other than yes to keep the existing version.

## Useful commands

~~~bash
sudo arsy-update
sudo bash /opt/arsy/scripts/arsy-doctor.sh
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml ps
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml logs -f
~~~

## Single VPS limits

- This is a pre-alpha operations host, not a global CDN or public cloud region.
- Do not delegate customer zones to one nameserver failure domain.
- Do not sell HA, Anycast, volumetric DDoS protection, or distributed-storage guarantees.
- Do not execute arbitrary customer code on the control-plane host.
- Backups for customer data must leave the VPS/provider failure domain.
