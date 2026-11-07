# Security policy and operational baseline

## Open-source rule

Mandatory runtime dependencies must be OSI-approved open-source software. Reject source-available, non-commercial, field-of-use restricted, or proprietary-only mandatory components. Re-check exact version, edition, plugins, images, bundled assets, and transitive dependencies before adoption.

Proposed project licensing:
- Core platform: AGPL-3.0-only.
- SDKs/protocol definitions: Apache-2.0 where practical.
- Documentation: CC-BY-SA-4.0.
- Brand marks remain subject to a separate trademark policy.

## Current VPS controls

- Operator access continues to use the VPS owner's existing SSH policy.
- No GitHub deploy key, remote deploy user, or deploy SSH secret is required.
- The web gateway binds to 127.0.0.1 by default.
- The installer does not rewrite sshd or firewall policy.
- .env is excluded from Git and set to mode 0600 by the installer.
- Updates require an explicit operator confirmation.
- Fastify trusts exactly one immediate proxy hop (Caddy); the application is not published directly.
- SSH recovery uses its own loopback listener at 127.0.0.1:18080 and does not forward client-supplied proxy metadata.
- Existing same-host TLS proxies use a separate loopback listener at 127.0.0.1:18082. Only that ingress forwards metadata from the local proxy; Nginx must overwrite X-Forwarded-For with the observed peer address.
- Remote/untrusted proxy networks and multi-hop chains are not implicitly trusted or supported in the first-VPS mode.
- The browser does not receive root credentials or the Docker socket.

## Before customer beta

- Implement organization/project authorization tests on every API resource.
- Use MFA for operators and scoped, revocable API keys for automation.
- Keep database, queue, metrics, and admin ports private.
- Add rate limiting, abuse reporting, retention, and suspension runbooks.
- Encrypt off-site backups and complete restore drills.
- Generate an SPDX or CycloneDX SBOM for each release.
- Scan source, dependencies, and images; document CVE triage and patch SLAs.
- Never log credentials, tokens, customer payloads, or private keys.
- Do not place the Docker socket in a customer-facing API or portal.
- Do not run untrusted customer workloads in the control-plane trust boundary.
