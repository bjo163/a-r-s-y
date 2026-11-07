# Commercial and service guardrails

## Launch stages

| Stage | What may be offered | Claims not permitted |
|---|---|---|
| Internal alpha | Internal DNS/edge experiments and trusted preview apps | Public SLA, global CDN, DDoS protection |
| Private beta | Limited DNS/edge/tunnel pilot with explicit limits | HA unless independently tested; global network |
| Commercial MVP | Specific products with metering, backup, status, and support | Guarantees beyond tested capability |
| Multi-region | Regional edge/DNS/storage with tested failover | Global claims without coverage and routing evidence |

## Service transparency

Every service page must show service status, region, redundancy level, data location, backup/retention policy, quota, rate limits, upstream dependencies, exclusions, incident communication, and support contact.

## Abuse operations

Before accepting paying customers, publish acceptable-use rules and build workflows for abuse reports, compromised credentials, malware/phishing reports, suspension review, evidence retention, and appeal. DNS, tunnel, storage, and compute services can be abused; operating procedures are part of product readiness.

## Billing correctness

- Use append-only usage events with idempotency keys.
- Keep pricing plans versioned.
- Reconcile aggregates against raw events.
- Provide customer-visible usage and invoice line items.
- Distinguish estimates, finalized invoices, payment status, refunds, and credit adjustments.
- Do not charge automatically until retry, duplicate-event, and reconciliation tests pass.

## Customer data

Document collected data, purpose, retention, and deletion. Avoid logging customer payloads. Redact authorization headers, keys, tokens, and secrets. Provide export/deletion processes subject to legal obligations. Keep backups outside the primary VPS failure domain.
