# Open-source, dependency, and security policy

## License acceptance

Mandatory runtime components must be OSI-approved open source. Reject source-available, non-commercial, field-of-use restricted, or proprietary-only dependencies. Verify exact repository, edition, directory, plugins, image, and transitive dependencies. Do not infer licensing from a public source repository alone.

Proposed licensing:
- Core platform: AGPL-3.0-only.
- SDKs/protocol definitions: Apache-2.0 where practical.
- Documentation: CC-BY-SA-4.0.
- Brand marks: separate trademark policy.

## Supply chain

- Generate SPDX or CycloneDX SBOMs for releases.
- Pin production container images by digest.
- Verify signatures/checksums where upstream provides them.
- Scan source, dependencies, and images.
- Track CVEs with severity, exploitability, affected versions, mitigation, and patch target.
- Keep THIRD-PARTY-NOTICES and attribution current.
- Review licenses for transitive dependencies and bundled assets.

## Security baseline

- OIDC, MFA for operators, short-lived sessions, scoped API keys.
- Organization/project scoping on every resource read and write.
- PostgreSQL RLS as defense in depth, not the sole authorization layer.
- Append-only audit events for privileged and customer-visible operations.
- Idempotency on provisioning and billing events.
- Secrets encrypted at rest; never log credentials or tokens.
- Signed webhooks with replay protection.
- Rate limits and abuse controls per organization and resource.
- No public Docker API, database, queue, or internal metrics endpoint.
- No untrusted customer workloads on the shared alpha host.
- Encrypted backups with restore drills.
- Incident response and vulnerability disclosure before public beta.

## Truthful operations

Do not state global CDN, DDoS-protected, zero downtime, high availability, end-to-end encrypted, or a specific SLA unless architecture, upstream provider capability, test evidence, and operational procedures justify it.
