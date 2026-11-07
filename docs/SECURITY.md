# Security policy and operational baseline

## Open-source rule

Mandatory runtime dependencies must be OSI-approved open-source software. Reject source-available, non-commercial, field-of-use restricted, or proprietary-only mandatory components. Re-check exact version, edition, plugins, images, bundled assets, and transitive dependencies before adoption.

Proposed project licensing:
- Core platform: AGPL-3.0-only.
- SDKs/protocol definitions: Apache-2.0 where practical.
- Documentation: CC-BY-SA-4.0.
- Brand marks remain subject to a separate trademark policy.

## Current VPS controls

- Operator SSH uses public-key authentication.
- GitHub deploy access uses a dedicated user with an authorized-key forced command.
- The deploy user is not a member of the Docker group.
- The deploy user has passwordless sudo only for /usr/local/sbin/arsy-deploy.
- SSH host-key checking in Actions is strict and uses pinned known_hosts.
- The HTTP gateway binds to 127.0.0.1 by default.
- The installer does not rewrite SSH daemon or firewall configuration.
- .env is excluded from Git and set to mode 0600 by the installer.

## Before customer beta

- Implement organization/project authorization tests on every API resource.
- Use MFA for operators and scoped, revocable API keys for automation.
- Keep database, queue, metrics, and admin ports private.
- Add rate limiting, abuse reporting, retention and suspension runbooks.
- Encrypt off-site backups and complete restore drills.
- Generate an SPDX or CycloneDX SBOM for each release.
- Scan source, dependencies and images; document CVE triage and patch SLAs.
- Never log credentials, tokens, customer payloads, or private keys.
- Do not place the Docker socket in the customer-facing API or portal.
- Do not run untrusted customer code in the control-plane trust boundary.
