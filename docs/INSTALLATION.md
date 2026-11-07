# A-R-S-Y — Single VPS installation

## Supported host

- Ubuntu Server 22.04+ or Debian 12+.
- amd64 or arm64.
- Recommended alpha: 8 vCPU, 16 GB RAM, 200 GB NVMe.
- Constrained development: 4 vCPU, 8 GB RAM, 100 GB SSD.

## Install

Download and inspect the installer:

~~~bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
~~~

The installer:
- Installs Docker Engine and Compose from Docker's official APT repository only when needed.
- Clones A-R-S-Y into /opt/arsy.
- Generates PostgreSQL password, session secret, and one-time Superadmin setup token.
- Stores secrets in /opt/arsy/.env with mode 0600.
- Starts PostgreSQL, the Fastify web application, and Caddy gateway.
- Waits for the application/database health endpoint.
- Prints the one-time setup key.

The installer does not edit the host firewall or SSH daemon. It does not take over public port 80/443. The application is not published directly; only Caddy exposes the loopback port.

## Open the web app

Default listener: 127.0.0.1:18080.

From your workstation:

~~~bash
ssh -L 18080:127.0.0.1:18080 YOUR_OPERATOR_USER@YOUR_VPS_HOST
~~~

Open http://127.0.0.1:18080. The first visit redirects to /setup.

## Create the first Superadmin

The installer prints the bootstrap key after successful installation. If needed, retrieve it on the VPS:

~~~bash
sudo grep '^ARSY_SETUP_TOKEN=' /opt/arsy/.env
~~~

Complete the first-boot form with:
- One-time bootstrap key.
- Display name.
- Email address.
- Password of at least 14 characters.
- Password confirmation.

The setup transaction creates the first superadmin, records an audit event, and sets setup_completed=true. The setup route is permanently closed after that. There is no open registration endpoint.

## Update behavior

The dashboard checks the latest commit on GitHub main. If a newer version is found, the application asks for approval. After you approve, it shows the exact command for the exact commit.

Run the command displayed by the app in the VPS terminal. Or manually check:

~~~bash
sudo arsy-update
~~~

The terminal command asks for confirmation. GitHub commits and releases never trigger VPS deployment.

## Repair / reinstall

To explicitly repair the installation or deploy the current main revision:

~~~bash
sudo bash /opt/arsy/install.sh --repair
~~~

This preserves .env and the named PostgreSQL volume. Never use docker compose down -v unless you intentionally want to delete the database.

## Operations

~~~bash
sudo arsy-doctor
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml ps
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml logs -f app
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml logs -f db
~~~

## HTTPS and cookies

The default gateway is loopback-only HTTP for private setup via SSH tunnel. When placing A-R-S-Y behind a trusted HTTPS reverse proxy, set:

~~~dotenv
ARSY_COOKIE_SECURE=true
~~~

Then apply that configuration through a deliberate operator-approved update/restart. Do not expose the setup page over public HTTP.

## Single VPS limits

- No public production DNS delegation to one nameserver failure domain.
- No global CDN, Anycast, volumetric DDoS, HA, or SLA claims.
- No arbitrary customer code execution on the control-plane host.
- Backups must be encrypted and stored outside the VPS/provider failure domain before customer data is accepted.
