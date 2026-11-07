# Open-source, dependency, and security policy

## License acceptance

Mandatory runtime components must be OSI-approved open-source software. Reject source-available, non-commercial, field-of-use restricted, or proprietary-only mandatory dependencies. Verify exact repository, version, edition, directory, plugins, image, and transitive dependencies. Do not infer licensing from a public source repository alone.

Proposed licensing:
- Core platform: AGPL-3.0-only.
- SDKs/protocol definitions: Apache-2.0 where practical.
- Documentation: CC-BY-SA-4.0.
- Brand marks: separate trademark policy.

## Supply chain

Before public beta/release:
- Generate SPDX or CycloneDX SBOMs.
- Pin production container images by digest where operationally practical.
- Verify upstream signatures/checksums when available.
- Scan source, dependencies, and images.
- Track CVEs with severity, exploitability, affected versions, mitigation, and patch target.
- Keep THIRD-PARTY-NOTICES and attribution current.
- Review licenses for transitive dependencies and bundled assets.

## Current single-VPS security baseline

- Operator access uses the VPS owner's existing SSH policy.
- Installer does not rewrite sshd or firewall configuration.
- Web gateway binds to loopback by default.
- `.env` is excluded from Git and set to mode 0600 by installer.
- First Superadmin setup uses a one-time bootstrap token and closes after enrollment.
- Passwords are hashed using Node.js scrypt.
- Sessions are opaque and persisted as digests in PostgreSQL.
- State-changing requests use CSRF/origin protections; setup/login are rate-limited.
- Relevant authentication, setup, and update actions create audit events.
- PostgreSQL is private to the Docker network.
- Browser does not receive root credentials or Docker socket.
- Updates require explicit approval and terminal execution.

These controls are a foundation, not a completed penetration test, security certification, or public-beta security posture.

## Required before customer beta

- Organization/project authorization tests on every API resource.
- MFA for operators and scoped/revocable API keys where applicable.
- PostgreSQL RLS as defense in depth, not the sole authorization layer.
- Append-only audit events for privileged and customer-visible operations.
- Secrets encrypted at rest with documented key recovery/rotation.
- Signed webhooks with replay protection.
- Rate limits and abuse controls per organization/resource.
- No public Docker API, database, queue, or internal metrics endpoint.
- No untrusted customer workloads on the shared control-plane host.
- Encrypted backups outside the VPS/provider failure domain and completed restore drills.
- Incident response and vulnerability disclosure process.

## Truthful operations

Do not state global CDN, DDoS-protected, zero downtime, high availability, end-to-end encrypted, or a specific SLA unless architecture, upstream provider capability, test evidence, and operational procedures justify it.
