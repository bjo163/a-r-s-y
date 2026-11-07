# A-R-S-Y — Platform Contracts and Data Model

Target constraints only. Do not implement the entire model during first-VPS alpha.

## Contract principles
PostgreSQL is durable control-plane source of truth. Introduce public /api/v1 with OpenAPI and JSON Schema when the API stabilizes. Keep infrastructure engines behind adapters. Separate versioned desired state from observed/applied state. Side effects require authorization, idempotency, audit correlation, validation and recoverability. Never expose secrets through APIs.

## Conceptual domain
Identity: User, Identity, Session, Credential, APIKey, MFAFactor.
Tenancy: Organization, Membership, Role, Permission, Project, Environment.
Infrastructure: Region, Node, NodeEnrollment, Resource, ResourceType, Relationship.
Services: ServiceDefinition, ServiceInstance, Domain, DNSZone, DNSRecord, Network, Address, Route, Tunnel, Connector, Origin, EdgePolicy, Bucket, Volume, Snapshot, ComputeInstance.
Operations: ProvisioningJob, JobAttempt, DesiredConfiguration, ObservedConfiguration, HealthCheck, Alert, Incident, MaintenanceWindow.
Governance: AuditEvent, Policy, Approval, SecretReference, UsageEvent, Quota, Subscription, Invoice, SupportCase, AbuseReport.
These are conceptual aggregates, not a mandate to create placeholder tables.

## Tenant isolation
Before customer tenancy: every tenant-owned row has organization scope; authorization is enforced in every service/query/mutation; client-supplied tenant IDs are never trusted. PostgreSQL RLS is defense in depth, not a replacement for application authorization. Jobs carry tenant context and re-check authorization. Negative tests cover list/read/update/delete/export/search/logs/metrics/object access and direct APIs. Define audited, time-bounded break-glass access. Current schema is not tenant-ready.

## Resource lifecycle
requested → validating → queued → provisioning → active → updating → deleting → deleted. Failure/health states: failed, degraded, suspended, unknown.
Persist stable ID, tenant, type, placement, owner, desired config version, redacted secret references, observed version, health, timestamps and audit correlation. Never report active until target adapter confirms applied state. Retries are bounded, observable and idempotent.

## Jobs and events
Start with PostgreSQL-backed jobs when asynchronous provisioning is needed; no broker before measured need. Jobs need idempotency, lease/claim, bounded retry, timeout, cancellation, dead-letter visibility and replay safety. Events are versioned, attributable, correlated and redacted. Webhooks require signatures, timestamp tolerance, replay protection, retries and secret rotation. Events do not prove side-effect success; reconcile observed state.

## API conventions
JSON over HTTPS; structured errors with code, safe message, request ID and field errors; bounded stable pagination; allowlisted filters/sorts; idempotency keys for side effects; ETags/version preconditions where useful; UTC RFC3339 timestamps and separately stored IANA timezone; per-identity/tenant/operation rate limits; audit privileged mutations. CI must lint OpenAPI, validate schemas and detect breaking changes before SDK/public release.

## Secrets and migrations
Separate control-plane, node enrollment, customer application and provider credentials. Define rotation, revocation, backup, recovery and audit before supporting each secret type. Never put secrets in desired-state JSON, logs, URLs or issue text. Use expand/migrate/contract migrations; preserve backward compatibility until migration and rollback are tested. Production destructive migrations require operator approval.
