# A-R-S-Y — First-VPS Release Checklist and Evidence

This checklist is a release record, not a promise. Check an item only when evidence is attached to the exact release candidate SHA. A merged PR, workflow queue, or written procedure is not equivalent to a successful test.

## Repository and build
- [ ] Current main commit SHA and release tag are recorded.
- [ ] All required GitHub Actions jobs completed successfully on the exact SHA.
- [ ] Node unit and PostgreSQL integration tests passed.
- [ ] Bash syntax and isolated env/domain/deploy regression tests passed.
- [ ] Docker Compose configuration validated with dummy values.
- [ ] Caddy configuration validated.
- [ ] Local documentation links validated.
- [ ] Dependency, image, license, secret and vulnerability checks reviewed.
- [ ] SBOM generated and archived for release candidate.
- [ ] Known issues, migration notes, rollback steps and supported architectures listed.

## First-VPS installation and operations
- [ ] Fresh install tested on Ubuntu 22.04+ AMD64.
- [ ] Fresh install tested on Debian 12+ AMD64.
- [ ] ARM64 install tested if that architecture is claimed as supported.
- [ ] Installer preflight and explicit confirmation observed.
- [ ] Firewall and SSH settings remained unchanged.
- [ ] First Superadmin can be created once; repeated setup rejected.
- [ ] Login, logout, CSRF, Origin, session expiry and rate-limit behavior verified.
- [ ] Onboarding profile reloads; invalid timezone rejected; DNS diagnostic timestamp shown.
- [ ] SSH tunnel works after install and after managed-domain activation.
- [ ] Managed public domain TLS verified from an external network.
- [ ] Existing same-host proxy mode tested with the dedicated 18082 ingress and secure cookie.
- [ ] Repair tested with a pre-existing .env and PostgreSQL named volume.
- [ ] Update approval bound to exact SHA; deployment only after operator execution.
- [ ] Successful update preserves .env, named DB volume, deployed SHA, and runtime Caddyfile.
- [ ] Failed update rolls application source back and confirms previous health.
- [ ] Domain failures (DNS, occupied ports, Compose, start, TLS) restore previous state and private access.

## Backup and recovery
- [ ] Remote Restic backend is outside the VPS/provider failure domain.
- [ ] Restic repository encryption password is recoverable independently of the VPS.
- [ ] Encrypted backup completed and snapshot ID recorded.
- [ ] Restore drill completed in isolated PostgreSQL container.
- [ ] Replacement-host recovery procedure reviewed and rehearsed.
- [ ] RPO/RTO chosen from measurement; alert owner and retention policy assigned.

## Security and operations
- [ ] Threat model updated and independently reviewed.
- [ ] Host access, Docker daemon, secrets, audit and retention policy reviewed.
- [ ] Incident response and vulnerability disclosure contact/process published.
- [ ] Monitoring, alert ownership and recovery runbooks tested.
- [ ] Privacy, acceptable-use, support and abuse policy reviewed before customer-facing beta.

## Evidence record template

~~~text
Release version:
Repository:
Commit SHA:
GitHub Actions run URL:
Tester / operator:
Test UTC start/end:
OS / version:
Architecture:
Host resource profile (redacted):
Install result:
Repair result:
Update target SHA:
Rollback result:
Private SSH recovery result:
Managed domain TLS result:
Existing proxy result:
Backup snapshot ID:
Restore drill result:
Threat-model reviewer:
Known issues:
Residual risks / exceptions:
Approval record:
~~~

## Current release state

A-R-S-Y remains **single-VPS foundation / pre-alpha / not production-ready** until all required evidence above is complete. A current Actions run in queued or pending state is not a pass. Real host, public DNS/TLS, off-site backup and restore evidence cannot be fabricated by CI.
