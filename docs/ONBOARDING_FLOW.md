# A-R-S-Y — First-Run Installation and Onboarding Flow

> Status: product/UX specification for the next onboarding implementation. This document describes the target flow; it does not claim that all wizard screens or checks are implemented yet.

## 1. Product goal

A-R-S-Y should feel like a complete infrastructure platform during first launch, not like a bare admin registration page.

The first-run journey has two responsibilities:

1. The VPS installer detects and prepares the host, installs the minimum Core stack, and verifies that it is healthy.
2. The web onboarding collects the decisions that only the operator can make, verifies the installation profile, and guides the operator into the dashboard.

Keep the terminal flow short. Automatically detect technical facts; ask the operator only for decisions and labels. Use a resumable web wizard instead of one oversized form.

## 2. UX principles

- One guided journey from install command to the first dashboard.
- Safe defaults, clear explanations, and no surprise changes.
- Detect technical details instead of asking the operator to type them.
- Save each completed wizard step so the operator can leave and resume.
- Clearly distinguish configured, detected, planned, unavailable, and not-yet-verified items.
- Do not make optional future services look installed or operational.
- Do not block a private single-node setup on domain, DNS, public TLS, backup provider, or extra-node configuration.
- Never expose secrets in the browser, logs, diagnostics, or audit metadata.
- Do not silently expose services to the public internet, change firewall rules, change SSH settings, or install updates.

## 3. End-to-end journey

### Phase 0 — Download and inspect

The operator downloads the installer, inspects it, and runs it with administrative privileges. Keep the documented download-then-inspect workflow; do not encourage piping a remote script directly into a shell.

### Phase 1 — Read-only host preflight

Before package installation or host modification, the installer should detect and report:

| Area | Detect / validate | Behavior |
|---|---|---|
| Operating system | Distribution, version, supported status | Fail only when unsupported |
| CPU architecture | amd64 or arm64 | Fail when unsupported |
| CPU | Logical core count | Informational and capacity warning |
| Memory | Total RAM and swap | Warn when below recommendation |
| Disk | Free space on the target filesystem | Warn or fail using documented minimums |
| Host identity | Hostname | Display; do not change automatically |
| Time | System timezone and UTC offset | Use as detected default |
| Network | DNS resolution and outbound HTTPS | Fail when required download access is unavailable |
| Docker | Engine presence and version | Detect whether installation is required |
| Compose | Compose plugin presence and version | Install only when missing |
| Ports | Current use of the configured loopback port | Fail on an actual bind conflict |
| Public web ports | TCP 80/443 usage | Informational only in the current private-listener architecture |
| Existing installation | A-R-S-Y directory, deployment marker, Compose project, data volume | Never overwrite an existing installation silently |

The preflight should not upload host facts to any external service. Do not collect MAC addresses, hardware serials, machine UUIDs, SSH private keys, or unrelated process details.

Show a concise summary with PASS, WARN, and BLOCKED states. Explain every warning in plain language.

### Phase 2 — Explicit install confirmation

Before making changes, show the operator what will happen:

- Install missing base packages and Docker components from documented trusted repositories.
- Create or use the A-R-S-Y application directory.
- Create protected environment secrets.
- Create persistent PostgreSQL and gateway volumes.
- Start the Core application, database, and private gateway.
- Bind the panel to the configured loopback address and port.
- Leave the host firewall and SSH daemon unchanged.

Ask for an explicit confirmation before proceeding. A non-interactive mode may be supported only through a clear explicit flag such as --yes; it must not become the default.

### Phase 3 — Install and verify Core

Install or validate Docker Engine and Compose, prepare directories and secrets, deploy the exact selected revision, and wait for database and application health checks.

On failure:
- Stop the sequence and print the failing stage.
- Preserve the installer log and diagnostic output with restrictive permissions.
- Do not delete persistent volumes.
- Do not claim success when the health endpoint is unavailable.
- Print the exact safe diagnostic command and the relevant log location.

On success, print:
- A-R-S-Y version / commit.
- Local panel URL and port.
- SSH tunnel command template.
- One-time bootstrap key and a warning to keep it private.
- Application and diagnostics command references.

The default remains loopback-only. The installer must not open public firewall ports.

### Phase 4 — Private first access

The operator opens the panel through the SSH tunnel. The first page should show that Core and PostgreSQL are healthy and explain that initial setup is not yet complete.

The current one-time bootstrap key is used only to create the first Superadmin. Keep this step separate from the longer installation-profile wizard.

### Phase 5 — Create the first Superadmin

Required:
- Display name.
- Email address.
- Password and confirmation.
- One-time bootstrap key.

Retain server-side validation, strong password requirements, rate limiting, CSRF/origin protections where applicable, transactional account creation, and the single-Superadmin guard.

After account creation, close the bootstrap route permanently. Do not add public registration.

### Phase 6 — Resumable web onboarding wizard

Use a clear progress indicator, Back and Continue actions, per-step validation, and server-side persistence. The wizard should be short enough to finish in a few minutes.

#### Step 1 — Workspace identity

| Field | Requirement | Default / behavior |
|---|---|---|
| Workspace / organization name | Required | Suggest a sensible name; editable |
| Workspace slug | Generated | Derive from name; validate uniqueness before future use |
| Operational contact email | Optional | Default to the Superadmin email, editable |
| Workspace description | Optional | Short purpose / notes |

Do not ask for billing, payment details, tax identifiers, team member invitations, or tenant plans in this first-run flow. Those belong to later product milestones.

#### Step 2 — Installation profile

| Field | Requirement | Default / behavior |
|---|---|---|
| Installation display name | Required | A-R-S-Y Control Plane |
| Environment label | Required | Personal, Lab, Staging, or Production |
| Region / location label | Optional | Operator-entered label; never infer a precise physical location |
| Timezone | Required | Detect from host; allow correction |
| Interface language | Required | Indonesian or English; default Indonesian |

The environment label is descriptive metadata, not a production-readiness certification.

#### Step 3 — Core node identity

Automatically detect and display:
- Hostname.
- Operating system and version.
- CPU architecture and logical core count.
- Total memory and swap.
- Free disk space on the installation filesystem.
- Docker Engine and Compose versions.
- A-R-S-Y Core and database health.

Ask only for:
- Node display name (required; suggest the detected hostname).
- Optional node/location label.
- Optional operator note.

The first node is the local Core Node with a fixed control-plane role. Do not ask for remote SSH credentials or extra-node details in the single-VPS onboarding.

Host resource facts must come from the host-side installer/diagnostic path, not only from container limits. Store a minimal local snapshot in a root-owned location and mount it read-only into the application if the web UI needs it. Make the source and last-updated time visible.

#### Step 4 — Network and panel access

The supported initial mode is:

- Private access through SSH tunnel — selected by default and fully supported now.

Collect the operator's preferred panel access mode. Support private SSH-tunnel access immediately; design public-domain and existing-reverse-proxy modes as explicit guided setup paths. Never imply DNS or TLS is configured until independently verified.

Do not request DNS provider API tokens, cloud credentials, private SSH keys, or certificates in this onboarding phase. Public domain provisioning should become a separate guided flow only after the feature exists and can verify DNS, port reachability, and certificate health.

#### Step 5 — Security and operations review

Show actual system facts and actionable checks:

| Check | Initial expected state | Completion rule |
|---|---|---|
| First Superadmin | Created | Required |
| One-time enrollment | Closed | Required |
| Core health | Healthy | Required |
| Database health | Healthy | Required |
| Panel binding | Loopback-only | Required for this setup profile |
| HTTPS | Not configured for SSH-tunnel-only mode | Explain; do not report as public-secure |
| Firewall / SSH changes | Not modified by installer | Informational |
| Off-site backup | Not configured until verified | Warning / follow-up task |
| Backup restore test | Not verified | Warning / follow-up task |
| Update policy | Consent required | Required product rule |
| Multi-factor authentication | Not available in this foundation | Clearly disclose; do not show a fake toggle |

Do not ask the operator to paste backup credentials here. Later, a backup wizard can configure a provider and verify a real encrypted backup and restore.

#### Step 6 — Review and finish

Show a complete review of:
- Owner identity.
- Workspace identity.
- Installation profile.
- Local Core Node profile.
- Network access mode.
- Security and operations findings.

The operator confirms and finishes. Persist the profile, mark onboarding complete, and record an audit event without storing passwords, bootstrap keys, tokens, or other secrets in the event metadata.

## 4. After onboarding — Dashboard checklist

Finishing onboarding should open the dashboard, not another long wizard. Show a persistent, dismissible-but-reopenable checklist:

1. Installation profile completed.
2. Core Node healthy.
3. Admin access protected.
4. Confirm private access or configure HTTPS when that feature is available.
5. Configure encrypted off-site backup.
6. Perform and record a restore test.
7. Review the consent-first update policy.
8. Add another node only when multi-node enrollment is implemented.

A skipped task remains visible with its true status. Do not turn an unverified item green merely because the operator clicked Continue.

## 5. Data model and state transitions

Keep the initial account bootstrap and the installation wizard as separate state machines.

Recommended logical states:
- bootstrap_pending
- bootstrap_complete
- onboarding_in_progress
- onboarding_complete

Do not overload the existing setup_completed setting to represent both account creation and the whole wizard.

Recommended persisted profile entities:
- Installation profile: workspace identity, contact, installation name, environment label, region label, timezone, language, access intention, onboarding timestamps.
- Core node profile: display name, role, host facts snapshot, source, and last-updated timestamp.
- Onboarding progress: current step and completion state.

Use additive database migrations. Preserve existing users, sessions, settings, audit events, and PostgreSQL volumes. Existing installations with a Superadmin should be guided into the new profile wizard once; they must not be asked to create the Superadmin again.

Each step must be safe to retry. Persist validated data server-side. Never trust a client-side progress flag as proof that the step is complete.

## 6. Data we deliberately do not collect yet

Do not ask for these during first-run:
- DNS provider API credentials.
- Cloud provider access keys.
- SSH private keys or root passwords.
- Payment details or billing identity.
- Customer data or tenant information.
- Backup destination credentials before a real backup feature exists.
- MFA recovery codes before MFA is implemented.
- Telemetry consent while telemetry is not implemented.

Do not silently enable analytics, telemetry, update installation, public exposure, firewall changes, or workload execution.

## 7. Implementation order

1. Installer preflight, explicit confirmation, and reliable diagnostics.
2. Minimal host-facts snapshot with strict data minimization.
3. Split bootstrap completion from onboarding completion using additive migrations.
4. Workspace and installation profile wizard with resumable server-side progress.
5. Core node profile and health checks.
6. Network/security review and honest readiness states.
7. Dashboard first-run checklist.
8. Automated tests for migrations, setup gating, resume behavior, validation, CSRF, audit redaction, and installer safety.

Do not start domain automation, remote-node enrollment, backup-provider credentials, billing, or customer workload deployment as part of this onboarding milestone.

## 8. Acceptance criteria

- A fresh supported VPS can be preflighted before any host changes.
- No installation changes occur before explicit confirmation.
- A port conflict or unsupported host is reported clearly and safely.
- Existing .env values and persistent data are preserved.
- Installer health checks pass before it prints installation success.
- The first Superadmin can be created exactly once.
- An interrupted wizard resumes at the correct incomplete step after login.
- Existing installations migrate without data loss and without recreating the Superadmin.
- Every saved field is validated on the server.
- Secrets never appear in browser responses, logs, diagnostics, or audit metadata.
- The dashboard shows truthful health and readiness states.
- No update, public exposure, firewall change, or destructive operation occurs without explicit operator approval.


## 9. Architecture decision — hybrid CLI + web onboarding

**Decision: CLI installs and verifies the host foundation; the web wizard configures the installation profile and network identity.**

Do not make the CLI the primary questionnaire. Do not let the web application perform unrestricted host administration.

### CLI responsibilities

The CLI is responsible for tasks that require host-level access:

- Read-only preflight and compatibility checks.
- Detect existing Docker, Compose, A-R-S-Y installations, reverse proxies, and port conflicts.
- Install missing trusted prerequisites after explicit confirmation.
- Generate and protect secrets.
- Create persistent directories and volumes.
- Deploy the Core stack in a private-safe default mode.
- Collect a minimal host-facts snapshot.
- Verify Core and database health.
- Print the private URL, SSH tunnel instructions, setup key, and diagnostic commands.

The default CLI should ask only a small number of questions:
1. Confirm the preflight summary and the changes to be made.
2. Confirm installation after showing the exact actions.
3. Optionally choose a non-default install directory or local panel port if the defaults conflict.

Do not ask for organization name, admin profile, domain provider credentials, DNS records, API keys, SMTP credentials, or backup credentials in the CLI.

### Web wizard responsibilities

The web wizard is responsible for decisions and settings that benefit from validation and a guided interface:

1. Create the first Superadmin.
2. Create workspace / organization identity.
3. Set installation profile and preferences.
4. Name and label the local Core Node.
5. Choose panel access mode.
6. Enter and validate the control-panel domain when a public or reverse-proxy mode is selected.
7. Review DNS, TLS, firewall, and port readiness.
8. Review all settings and explicitly apply changes.
9. Verify the final URL and show recovery instructions.

The wizard must be resumable. The operator can finish initial identity setup, save progress, leave, and continue later.

## 10. Network access modes and domain inventory

The first-run wizard should show exactly three access modes. The first is fully supported by the current private foundation; the others become enabled only when their implementation and validation are complete.

### Mode A — Private (default)

- Access through SSH tunnel to the loopback listener.
- No public domain is required.
- No public ports are opened.
- No public TLS certificate is requested.
- Keep this mode available as a recovery path even after configuring a public hostname.

This is the safest way to finish the first-run setup on a new VPS.

### Mode B — Public domain, managed by A-R-S-Y

The operator enters one required hostname, for example `panel.example.com`.

A-R-S-Y:
- Validates that the value is a hostname, not a URL or IP address.
- Detects the VPS public IPv4/IPv6 when possible and asks the operator to confirm the target address.
- Shows the required A record and, only when the VPS IPv6 route is confirmed, the optional AAAA record.
- Checks current DNS answers and reports mismatches.
- Checks whether host ports TCP 80 and 443 are available.
- Explains that provider-level firewalls/security groups may need inbound TCP 80 and 443; the installer cannot reliably inspect every provider firewall.
- Configures the managed Caddy gateway for the exact hostname only after review and confirmation.
- Requests and verifies a publicly trusted TLS certificate.
- Verifies HTTPS, redirect behavior, and application health.
- Keeps the private SSH-tunnel path available.

Caddy automatic HTTPS requires a public hostname, correct DNS, and reachability on the relevant external challenge ports. The standard HTTP-01 challenge requires TCP 80; TLS-ALPN-01 requires TCP 443. See the Caddy automatic HTTPS documentation.

Do not silently take over ports 80/443. If another service is listening there, stop and present Mode C instead. Never stop or reconfigure an existing proxy automatically.

### Mode C — Existing reverse proxy

Use when Nginx, Caddy, Traefik, a hosting panel, or another trusted proxy already owns public ports 80/443.

Collect:
- Public control-panel hostname (required).
- Reverse-proxy type (informational selection).
- Whether TLS terminates at that proxy (must be confirmed).
- Optional operator note / proxy location.

A-R-S-Y remains on its private loopback listener. Show the exact upstream target and required proxy headers. Require HTTPS at the external proxy before marking the public panel URL as secure. Set the secure-cookie configuration only after the operator confirms that HTTPS is active.

Do not request proxy admin credentials, private keys, certificate private material, or an API token in this first-run wizard.

### Domain types — keep them separate

| Domain type | Example | First-run handling |
|---|---|---|
| Control-panel hostname | `panel.example.com` | Configure now only for Mode B or C |
| Application wildcard domain | `*.apps.example.com` | Explain as a later capability; do not activate without application routing and tenant isolation |
| Separate API hostname | `api.example.com` | Not required; use the panel hostname and `/api` path initially |
| Customer DNS zones | Customer-owned domains | Later ARSY Name workflow, separate from control-panel setup |
| Marketing / documentation domain | `example.com` | Not part of VPS first-run setup |

Do not ask for a wildcard domain as a required field. It can be recorded as a future intention only after clearly stating that no routing or DNS records are being created.

## 11. Domain validation and application lifecycle

The public-domain wizard must have visible, independently verifiable phases:

1. **Hostname entered** — show the normalized hostname and allow correction.
2. **Target address confirmed** — show detected public IPv4/IPv6 with its detection source; allow manual correction when detection is unavailable.
3. **DNS instructions** — show the exact A record and optional AAAA record. Do not suggest an AAAA record if IPv6 is not routable to the VPS.
4. **DNS check** — resolve current A/AAAA records and compare them with the confirmed target. Show each record's actual and expected value.
5. **Port readiness** — check local port ownership and explain the external firewall/security-group requirement. Clearly distinguish host port availability from external reachability.
6. **Review changes** — list hostname, DNS expectation, gateway changes, ports that will be bound, TLS behavior, and the continued private recovery route.
7. **Explicit approval** — no network configuration changes before operator approval.
8. **Apply** — validate Caddy configuration before activation, apply the fixed configuration, and request a certificate.
9. **Verify** — check HTTPS, certificate validity, expected hostname, HTTP-to-HTTPS redirect, and Core health.
10. **Complete or recover** — show the verified public URL only after success. On failure, retain or restore the prior private configuration and explain the precise blocker.

DNS and TLS readiness states must be honest:
- Not configured.
- DNS pending.
- DNS mismatch.
- Waiting for provider firewall.
- Port conflict.
- Certificate pending.
- Certificate failed.
- HTTPS verified.

Do not mark a domain ready merely because the operator entered it or clicked Continue.

### DNS provider credentials

The first release should use manual DNS instructions. Do not request a Cloudflare or other DNS API token until a supported provider integration exists and its permission scope is documented.

A later provider integration may offer two distinct permissions:
- DNS record management for a selected zone.
- DNS-01 certificate challenge management.

Those permissions must be least-privilege and optional. They are not needed for the initial manual A/AAAA + HTTP-01/TLS-ALPN flow.

## 12. Safe host-side apply boundary

The current web application runs without the Docker socket and must not be given unrestricted root access. Public-domain activation requires host-level changes (gateway port bindings and proxy configuration), so it needs a deliberately narrow host-side mechanism.

Preferred architecture for one-click apply:
- Install a small host-side A-R-S-Y bridge/helper during the CLI installation.
- The helper accepts a strict, versioned request schema over a local-only channel.
- Supported actions are allowlisted, for example: read host facts, validate network configuration, apply a panel hostname, and rollback the panel hostname.
- It must not accept arbitrary shell commands, arbitrary file paths, arbitrary Compose project names, or arbitrary Docker API requests.
- Domain inputs are validated as hostnames; file writes are limited to owned A-R-S-Y configuration paths.
- Every apply request is tied to an authenticated Superadmin approval, expires, is idempotent, and cannot be replayed.
- The helper validates generated configuration before reload/recreate, performs health checks, and rolls back to the prior known-good gateway configuration on failure.
- It must never remove persistent volumes or change SSH access.
- The host agent/helper must not open public listeners.

Do not solve this by mounting `/var/run/docker.sock` into the web application container. Do not give the application a generic sudo shell.

If the restricted host helper is not implemented yet, Mode B must remain visibly unavailable or require a clearly documented operator-run command. Do not present a fake one-click domain setup.

## 13. Recommended first-run screen sequence

1. **Welcome / system check** — explain private bootstrap and detected Core health.
2. **Administrator account** — one-time bootstrap key, display name, email, password.
3. **Workspace** — organization/workspace name, slug, operational contact, short description.
4. **Installation profile** — installation name, Personal/Lab/Staging/Production label, region label, timezone, language.
5. **Core Node** — suggested hostname-based label, role, detected resources, OS, Docker/Compose versions.
6. **Panel access** — Private, Public domain managed by A-R-S-Y, or Existing reverse proxy.
7. **Domain setup** — conditional; show only for Mode B or C. Include DNS records and live checks.
8. **Security review** — enrollment closed, session protection, access mode, firewall and TLS truth, backup readiness, update-consent policy.
9. **Review & apply** — complete summary and explicit confirmation for any host/network change.
10. **Success** — show panel URL, private recovery method, Core node status, and remaining checklist.

The wizard should support Back, Save and exit, Resume, and a final review. Do not save secrets in ordinary profile fields or render them again after initial submission.

## 14. Current implementation gap and release gates

The current foundation publishes only the private loopback gateway at `127.0.0.1:18080`. It does not yet bind public ports 80/443, configure a user-supplied hostname, run domain DNS checks, request a panel certificate, or provide the restricted host-side apply bridge.

Therefore:
- The current private installation and Superadmin bootstrap remain the supported path.
- Domain fields and Mode B must not be marked implemented until the host helper, managed gateway changes, and certificate verification exist.
- Mode C may be documented as a manual external reverse-proxy path, but must not be marked verified until HTTPS and secure-cookie behavior are tested.
- A user who skips public domain setup must still complete onboarding and operate privately.
- Never lock the operator out by removing the SSH-tunnel route before the public endpoint has passed verification.

## 15. Implementation order

1. Improve CLI preflight and explicit install confirmation.
2. Add root-owned host facts snapshot with minimal data collection.
3. Split account bootstrap from onboarding completion using additive migrations.
4. Implement resumable workspace, installation, and Core Node wizard steps.
5. Implement access-mode selection with Private mode as the working default.
6. Design and test the restricted host bridge/helper and its threat model.
7. Implement DNS/port readiness checks and domain validation.
8. Implement managed Caddy public mode with apply/rollback and certificate verification.
9. Implement external reverse-proxy instructions and HTTPS verification.
10. Add dashboard onboarding checklist and regression tests.

## 16. Additional domain acceptance criteria

- A private installation can finish without owning or entering a domain.
- Public-domain setup requires a syntactically valid FQDN and a confirmed target address.
- A/AAAA records are checked against the confirmed target; invalid IPv6 is not advertised.
- Port conflicts are detected before applying public gateway changes.
- Existing reverse proxies are never stopped or overwritten automatically.
- The public gateway is never activated without explicit operator approval.
- TLS is not marked ready until certificate and hostname validation pass.
- SSH-tunnel access remains available after public setup.
- Failure during public configuration restores the previous private gateway configuration.
- No arbitrary shell or Docker socket is exposed to the application.
- Wildcard application domains and customer DNS zones remain separate future workflows.
