# A-R-S-Y — Operations, Quality and Release Engineering

## Testing model
Use unit tests for pure logic; integration tests with disposable PostgreSQL; API/adapter/webhook contract tests; shell tests for install/update/repair/domain/rollback; end-to-end onboarding tests; real-host acceptance on supported OS/architectures; and failure injection for outage, timeout, disk pressure, interrupted update and partial provisioning. Tests must be deterministic, isolated, repeatable and cleaned up. Never use production credentials/data.

## CI gates
Formatting/lint/static analysis; Node tests; Bash syntax and shell tests; Compose config with dummy values; disposable DB schema/migration checks; dependency/license and secret scans; container build/image scan for release candidates; docs link checks; OpenAPI lint and compatibility after public API exists. Queued, cancelled, skipped or absent checks are not passes. Report green only for successful checks on exact commit.

## Environments
Local uses disposable data/dummy secrets. CI uses ephemeral services and no deploy credentials. Preview is isolated and access controlled. Staging is production-like with explicit data policy. Production requires operator-controlled deploy, backup, monitoring, rollback and incident ownership. CI and GitHub releases never deploy to VPS.

## Deployment and rollback
Use immutable commit/image references. Record deployed and configuration versions. Preflight compatibility, disk, backup freshness, migration plan and health. Roll back application artifacts without deleting persistent volumes. Never assume database migrations are reversible. Preserve runtime gateway config and operator settings.

## Backup and disaster recovery
Set RPO/RTO only after measurement. Back up database, critical configuration, encrypted secret material and customer data under defined retention. Store copies outside primary VPS/provider failure domain. Test restore into isolation and verify application usability, not only archive extraction. Document key recovery and loss scenarios.

## Observability and incidents
Use structured redacted logs, health/readiness and metrics/traces when justified. Define SLO only after evidence. Every alert needs owner, severity, runbook and actionable signal. Maintain incident timeline, customer communication, containment, recovery and postmortem templates.

## Release lifecycle
Internal alpha → private beta → commercial MVP → generally available. Each release records version, commit, image digest, migration notes, SBOM, known issues, advisories, compatibility, backup/restore evidence and rollback path. Publish release notes and deprecation policy. No SLA/global/security guarantee beyond measured evidence.

## First-VPS evidence
Record OS/version, architecture, resource profile, install command, test commit, CI run, Superadmin, private recovery, domain mode, update, rollback, backup and restore. Redact hostname, IP, email and secrets. A real VPS test exists only when an operator records it.
