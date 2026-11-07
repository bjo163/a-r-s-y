# A-R-S-Y — Onboarding and Product Experience

## Principles
One coherent control plane; visible state; explain consequences; guide recovery; distinguish intent from verified reality. Use clear language, with advanced technical detail inspectable.

## First-install journey
1. CLI preflight detects OS/architecture, privilege, network, disk/memory, Docker/Compose and port conflicts. Explain packages, directories, services, ports and persistent data. Confirm before host changes; non-interactive use requires explicit confirmation.
2. Install protected configuration/secrets, start DB/app/gateway, verify health and show private access plus one-time setup token.
3. Create first Superadmin once; close setup after success; no public registration.
4. Web profile collects workspace/installation labels, environment, contact, node name, language and timezone. Distinguish metadata from operational settings.
5. Private SSH tunnel is default. Managed domain and existing proxy are optional with DNS/provider firewall/manual steps explained.
6. DNS check is observation only. Show expected/observed records and timestamp; never claim manual steps are complete without evidence.
7. Public activation requires CLI/operator confirmation and preserves private recovery.
8. Ready state shows actual app, DB, gateway, access route and last verified time. Unknown/failed critical checks cannot be called ready.

## Dashboard information architecture
Overview; Infrastructure; Services; Network & Security; Activity; Settings; Operations. Only implemented resource types get active controls. Future catalog entries are labelled planned/experimental.

## Status semantics
Use not configured, needs operator action, checking, healthy, degraded, failed, unknown and unsupported. Show last-check time and evidence. Saved config is not applied state; DNS resolution is not TLS/reachability; queued job is not completion; approved update is not installed update.

## Localization and accessibility
Support Indonesian and English foundations. Store language explicitly and IANA timezone; persist UTC timestamps and apply timezone for display/scheduling. Do not infer explicit preference from country. Use semantic controls, keyboard navigation, visible focus, contrast, responsive layouts and screen-reader labels. Never rely on color alone. Do not claim full localization if only preference metadata is stored.

## Privileged UX
Show exact target, impact, retained/deleted data, recovery path and command. Require typed confirmation or fresh auth for high-risk actions. Provide cancel and audit record. Never hide firewall, DNS, SSH, public exposure, billing or deletion consequences behind generic Continue.

## Maturity
Every service displays Concept, Prototype, Internal alpha, Private beta, Commercial MVP or Generally available. Feature flags do not replace authorization or maturity disclosure.
