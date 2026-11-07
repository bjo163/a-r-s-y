# A-R-S-Y — First-VPS Threat Model

## Scope and assumptions

This is the initial threat-model register for the single-VPS pre-alpha. It is a living engineering document, not a completed independent security audit, penetration test, certification, or guarantee. Revisit it when a new trust zone, network ingress, service engine, tenant boundary or external provider is introduced.

Current trust boundaries:
- Operator browser and workstation: untrusted client.
- SSH tunnel: authenticated operator transport; VPS SSH policy remains owner-managed.
- Caddy gateway: the only network hop trusted by Fastify.
- Local same-host reverse-proxy ingress: separate loopback port; proxy must overwrite forwarded headers.
- Fastify control plane: privileged management surface, never executes customer workloads.
- PostgreSQL: private service and durable control-plane state.
- Docker daemon/host root: infrastructure authority; never exposed to browser or application code.
- Remote backup provider: independent external trust boundary; snapshots are sensitive and Restic-encrypted.

## Risk register

| Asset / threat | Attacker and precondition | Potential impact | Current mitigation | Residual risk / detection / recovery |
|---|---|---|---|---|
| Bootstrap token theft | Local user, log reader, or browser observer obtains initial token | Attacker claims first Superadmin | One-time high-entropy token; private access instructions; setup closes transactionally | Token is printed to installer output and .env; protect terminal/logs, rotate only before setup. Review audit event and reinstall/repair if compromised |
| Credential brute force | Remote user can reach login route | Account takeover or resource exhaustion | Login rate limit, 14-character minimum password, scrypt hashes | In-memory limits reset on restart and are not cluster-wide; add distributed controls before public beta. Alert from auth failure audit events |
| Session theft/replay | Malware or attacker obtains cookie | Authenticated control-plane access | Opaque random token, HMAC digest at rest, HttpOnly, SameSite Strict, 8-hour expiry, revocation | No MFA or device binding yet; revoke sessions by account/DB action and rotate affected credentials |
| CSRF / cross-origin mutation | Victim has active session and visits malicious site | Unauthorized profile or privileged mutation | Same-origin comparison and CSRF token on authenticated POST routes | Verify every new mutating endpoint uses both; add negative API tests |
| XSS / HTML injection | Attacker controls rendered input or content | Script execution in operator session | Escaping for user-provided HTML fields, restrictive CSP, no inline script | Server-rendered pages require escaping at every new insertion point; test output encoding and CSP |
| Proxy header spoofing | Client sends forged X-Forwarded headers | Spoofed client IP/protocol, rate-limit bypass or insecure cookie assumptions | Private SSH ingress stays separate; same-host proxy ingress is separate and loopback-only; Nginx overwrites X-Forwarded-For; Fastify trusts only one Caddy hop | Host-local processes are trusted. Remote and multi-hop proxies are unsupported. Validate listener mapping and proxy config at each release |
| Direct database access | Attacker reaches host or Docker network | Read/modify identities, sessions, secrets and profile data | No host-published DB port; dedicated Compose network; app uses parameterized SQL | Host root/Docker authority can read DB. Keep daemon access restricted and monitor host security |
| Command / path injection | Malicious profile value or request reaches shell helper | Host compromise | Web profile does not execute shell; domain helper validates hostname/IP; no Docker socket in app | Keep values out of shell interpolation; tests must cover every helper argument |
| Domain takeover / TLS misconfiguration | DNS records or provider firewall are controlled/misconfigured | Panel exposure, TLS failure, loss of access | Explicit operator apply; A record and IPv4 checks; AAAA rejected; port conflict check; rollback; private listener retained | DNSSEC and external reachability not fully tested; inspect domain state and retain SSH path |
| Supply-chain compromise | Malicious dependency, image, or GitHub source revision | Code execution in app/container/host | Pinned direct npm versions, exact-SHA update approval, no auto-deploy, restricted container privileges | Image digests, SBOM and automated CVE/license scanning remain release work; review release provenance |
| Destructive update or migration | Bug or incompatible schema change | Service outage or data loss | Deployment lock, source rollback, persistent DB volume, .env and runtime Caddyfile preservation | Source rollback cannot reverse destructive DB migrations; use additive compatibility and off-site backup before release |
| Backup theft / key loss | Provider breach or stolen Restic password | Confidentiality loss or unrecoverable backup | Restic encryption; root-only config/password files; off-site repository; isolated restore drill tooling | Actual remote repository and password recovery not configured by code; key custody and restore evidence remain operator release gates |
| Host/provider failure | VPS disk, account, zone or provider outage | Full service outage | Off-site backup design, private recovery and repair path | Single VPS has no HA/failover. RTO/RPO are unknown until measured; restore to a replacement host |
| Denial of service | Public scanner or attacker sends traffic | Panel unavailable or host resource exhaustion | Private-by-default access; body limits, request timeout, rate limits, container memory/PID limits | No volumetric DDoS or managed WAF; rely on provider controls and keep public exposure minimal |
| Insider / operator misuse | Authorized operator misuses root or platform permissions | Data disclosure or destructive change | Explicit operator actions, audit events, no silent firewall/SSH changes | Current audit coverage is partial and host root is ultimate authority; review logs and backups after incidents |
| Future tenant escape | Malicious tenant targets missing authorization boundary | Cross-customer data or resource compromise | No customer tenancy or untrusted workloads in current release; tenant isolation is an explicit future gate | Must not launch multi-tenant services before RBAC, tenant-scoped queries, RLS defense-in-depth and negative cross-tenant tests |

## Required controls before private beta

- Independent application and host security review.
- MFA or an approved operator identity-hardening plan.
- Complete authorization/tenant isolation tests before adding customer tenancy.
- Session, origin, forwarded-header and cookie tests for all supported ingress routes.
- SBOM, dependency/image/license review and vulnerability intake process.
- Encrypted off-site backups, recovery-key custody and successful restore drill.
- Incident response, abuse handling, evidence retention and operator access review.

## Change review checklist

For each newly introduced service, record:
1. assets and trust zone;
2. attacker capability and preconditions;
3. attack surface and privilege required;
4. impact and likelihood;
5. preventive controls;
6. detection signal and alert/runbook;
7. containment, recovery and residual risk;
8. test evidence and owner.

No security claim may exceed the exact control and test evidence available on the release commit.
