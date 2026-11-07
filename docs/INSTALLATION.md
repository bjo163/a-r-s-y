# Single VPS installation

## Supported host

- Ubuntu Server 22.04+ or Debian 12+.
- amd64 or arm64.
- Recommended alpha: 8 vCPU, 16 GB RAM, 200 GB NVMe.
- Constrained development minimum: 4 vCPU, 8 GB RAM, 100 GB SSD.

The first release intentionally deploys only a small loopback-bound Caddy foundation gateway. The customer portal, API, identity, DNS, WAF, tunnel, storage, compute, and billing services are not yet implemented.

## Prepare

1. Provision a clean VPS and create an operator SSH key.
2. Keep provider console access available.
3. Ensure outbound HTTPS to GitHub and Docker package/image registries.
4. Ensure the selected loopback port is free (default 127.0.0.1:18080).
5. Create a dedicated GitHub Ed25519 deploy key as described in AUTO_DEPLOY.md.

## Install

Download, inspect, and execute the installer:

~~~bash
curl -fsSLo install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less install.sh
sudo bash install.sh
~~~

To choose another loopback port on first installation:

~~~bash
sudo ARSY_HTTP_PORT=18081 bash install.sh
~~~

To enable auto-deploy during installation, pass the public key as ARSY_DEPLOY_PUBLIC_KEY. Or configure it afterward using the --configure-deploy-key mode.

The installer checks OS support and root privileges; installs Docker Engine/Compose from the official Docker APT repository only when required; preserves a working existing Docker/Compose installation and an existing .env; clones the public repository into /opt/arsy; installs root-owned deployment entrypoints; optionally configures a restricted deployment user; and deploys the current main commit.

The installer does not rewrite firewall policy or SSH daemon configuration. It does not take over host ports 80 or 443.

## Inspect locally

The gateway binds to loopback by default. From your workstation:

~~~bash
ssh -L 18080:127.0.0.1:18080 YOUR_OPERATOR_USER@YOUR_VPS_HOST
~~~

Open http://127.0.0.1:18080. Health endpoint: /healthz.

## Configuration

File: /opt/arsy/.env

~~~dotenv
ARSY_HTTP_BIND=127.0.0.1
ARSY_HTTP_PORT=18080
TZ=Asia/Jakarta
~~~

The default avoids collisions with an existing Coolify, Dokploy, Caddy, Nginx, or Traefik. Do not bind to 0.0.0.0 without reviewing firewall, TLS, domain, and reverse-proxy ownership.

## Commands

~~~bash
sudo /opt/arsy/scripts/arsy-doctor.sh
sudo /usr/local/sbin/arsy-deploy "$(git -C /opt/arsy rev-parse HEAD)"
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml ps
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml logs -f
~~~

## Single-VPS limits

- This is a pre-alpha operations host, not a global CDN or public cloud region.
- Do not delegate customer production DNS to one nameserver failure domain.
- Do not sell HA, global anycast, volumetric DDoS protection, or distributed-storage guarantees.
- Do not execute arbitrary customer code on the control-plane host.
- Backups must leave the VPS/provider failure domain before customer data is accepted.
