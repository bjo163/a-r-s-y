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

Allow the operator to record a future intention to use a public HTTPS domain, but label it as planned and do not imply that DNS or TLS has been configured.

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
