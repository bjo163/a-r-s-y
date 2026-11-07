# A-R-S-Y — Security, Privacy and Trust Model

Mandatory design and release policy.

## Trust zones
Operator browser is untrusted. Public gateway is exposed. Control plane is privileged and must not run customer workloads or expose Docker socket to web code. Database stays private and least-privileged. Data-plane nodes are a separate trust domain. Customer workloads/data are hostile by default. External providers are independent trust boundaries.

## Identity and authorization
No public self-registration for initial install. Bootstrap credential is one-time and never logged. Password hashing uses a modern scheme with upgrade path. Sessions are opaque, revocable, bounded and rotated after auth; cookies use appropriate flags. Browser mutations require CSRF and origin validation. Rate-limit login, bootstrap, recovery and sensitive operations. Future tenant services require RBAC, tenant scoping, MFA options, scoped/expiring/revocable API keys and audited break-glass.

## Host boundary
Installer previews changes and obtains confirmation. Never silently modify firewall/SSH, expose public ports or change provider settings. Database, Docker API, admin and metrics ports remain private. Never mount Docker socket into web app or run untrusted workloads on control-plane host. Node agents require mutual auth, least privilege, signed/versioned commands, replay protection and revocation. Never execute user-controlled shell input.

## Threat-model coverage
Cover credential theft, brute force, session fixation/replay, CSRF, XSS, SSRF, request smuggling, proxy-header spoofing, SQL/command injection, path traversal, malicious images/dependencies, container escape, tenant escape, node impersonation, secret exfiltration, backup theft, DNS/tunnel abuse, billing manipulation, denial of service, insider misuse and destructive updates/migrations. Record assets, attacker, preconditions, impact, mitigation, residual risk, detection and recovery. Revisit every new service/trust boundary.

## Privacy
Collect minimum data for a stated purpose. Document access, retention, deletion and export. Redact passwords, tokens, cookies, auth headers, private keys, customer payloads and secret environment values. Avoid request-body logging by default. Backups are sensitive; encrypt and test retention/deletion. No third-party telemetry by default; opt-in telemetry must be transparent, minimal and disableable.

## Supply chain
Verify exact licenses/editions for runtime dependencies, images, plugins and transitive packages. Review provenance, maintenance and advisories; pin artifacts/digests where practical. Generate SBOM and scan dependencies/images for release candidates. Define vulnerability intake, severity triage, supported versions and security contact before beta. Never weaken CI permissions to obtain green status.

## Incident and abuse operations
Before public services, define security contact, severity, response owner, containment, evidence, notification, recovery and disclosure. DNS, tunnel, storage and compute need abuse reporting, triage, suspension review, appeal and evidence retention. No public customer launch without operational ownership.

## Release gate
No public beta until threat model, security review, isolation tests where relevant, backup/restore drill, vulnerability process, secret rotation/revocation, incident runbooks, dependency/license review and real deployment evidence exist. Security claims must match tested controls.
