# A-R-S-Y — Single VPS Installation and Onboarding

## Supported host target

- Ubuntu Server 22.04+ or Debian 12+.
- AMD64 or ARM64.
- Root/sudo required.
- Planning recommendation: 8 vCPU, 16 GB RAM, 200 GB NVMe. Smaller dev hosts may work but need testing.

## 1. Download, inspect, install

```bash
curl -fsSLo /tmp/arsy-install.sh https://raw.githubusercontent.com/bjo163/a-r-s-y/main/install.sh
less /tmp/arsy-install.sh
sudo bash /tmp/arsy-install.sh
```

The installer:
- Prints host/OS/architecture/resource/Docker/listener preflight information.
- Requires interactive confirmation; non-interactive execution requires explicit `ARSY_INSTALL_CONFIRM=1`.
- Installs basic tools and configures the official Docker APT repository only when Docker or Compose is missing.
- Installs only the Compose plugin when Docker already exists and only Compose is missing.
- Clones/fetches A-R-S-Y, creates secrets, and stores them in `/opt/arsy/.env` (mode 0600).
- Starts PostgreSQL, Fastify app, and Caddy gateway; waits for health.
- Installs `arsy-update`, `arsy-doctor`, `arsy-domain`, environment migration, network validation, backup, and restore-drill host commands.

The installer does not edit host firewall rules or SSH daemon settings. It does not open public ports. Existing environment values and database volume must be preserved during repair/update.

## 2. Private web access

Default host listener is `127.0.0.1:18080`. From the workstation:

```powershell
ssh -L 18080:127.0.0.1:18080 USER@VPS
```

Open `http://127.0.0.1:18080`.

Retrieve the one-time bootstrap token on the VPS if needed:

```bash
sudo grep '^ARSY_SETUP_TOKEN=' /opt/arsy/.env
```

## 3. Create first Superadmin

Enter:
- One-time setup token.
- Display name.
- Email.
- Password (minimum 14 characters).
- Password confirmation.

The first setup is transactional and creates one active Superadmin. Once complete, setup is permanently closed; there is no open registration route. Keep first setup private via SSH tunnel.

## 4. Complete Web installation profile

The wizard collects:
- Workspace name and contact email.
- Installation name and environment.
- Node name.
- Timezone and language preference (id/en).
- Access mode: private, public managed domain, or existing proxy.
- Hostname/expected IPv4 for public mode.
- Proxy metadata where relevant.

Saving the profile does not configure DNS, open ports, alter firewall/SSH, or activate the public domain.

## 5. Choose access mode

### Private (recommended default)
Continue using the SSH tunnel. This is also the recovery path after public domain activation.

### Managed public domain
1. Create a DNS A record pointing to the VPS public IPv4.
2. Allow inbound TCP 80 and 443 in the VPS provider firewall/security group.
3. Ensure ports 80/443 are not already used by another service.
4. Run the reviewed activation command:

```bash
sudo arsy-domain apply --hostname panel.example.com
```

The helper validates prerequisites, public IPv4, DNS A, AAAA, and port availability; prints planned changes; requires confirmation; updates gateway binding/config; enables secure cookies; and performs an HTTPS health check. On failure it attempts to restore the prior environment and Caddy configuration.

The current helper supports IPv4 only and rejects an AAAA record. A-R-S-Y does not create or edit DNS records or provider firewall rules.

### Existing reverse proxy
Keep A-R-S-Y private and configure the existing proxy upstream to:

```text
http://127.0.0.1:18082
```

Run `sudo arsy-domain proxy --hostname panel.example.com` to print example guidance. Point the same-host proxy to `http://127.0.0.1:18082`; the private SSH recovery path remains `127.0.0.1:18080`. TLS terminates at the existing proxy. Enable Secure cookies only after HTTPS and trusted forwarded-protocol handling are verified. A-R-S-Y does not take over ports 80/443 in this mode.

## 6. Updates

Dashboard checks GitHub main. **Later** leaves the VPS unchanged. **Update now** records approval for the exact SHA and displays a terminal command. The VPS changes only when the operator runs the command.

```bash
sudo arsy-update
```

Never treat a push, merge, release, or detection as deployment authorization.

## 7. Repair and diagnostics

```bash
sudo bash /opt/arsy/install.sh --repair
sudo arsy-doctor
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml ps
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml logs -f app
sudo docker compose --env-file /opt/arsy/.env -f /opt/arsy/compose.yaml logs -f db
```

Do not use `docker compose down -v` for routine repair/update; it deletes the named database volume.

## 8. Limits and release status

This is a pre-alpha foundation. It is not a public cloud region. No HA, global CDN, Anycast, volumetric DDoS, customer DNS hosting, or arbitrary customer compute is provided. Encrypted off-site backups and successful restore drills are required before accepting customer data. Real VPS testing remains a release gate.
