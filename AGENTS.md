# A-R-S-Y — Instructions for AI coding agents

Before changing code, read these files in order:

1. `README.md` — current product status and safe operator workflow.
2. `docs/LOCAL_AI_HANDOFF.md` — authoritative handoff, current verified state, constraints, and next work.
3. `docs/00-narrative-and-positioning.md` — product identity and positioning.
4. `docs/02-master-blueprint.md` — current architecture versus future target.
5. `docs/05-roadmap.md` — milestone gates and priorities.
6. Relevant operational docs: `docs/ARCHITECTURE.md`, `docs/INSTALLATION.md`, `docs/SECURITY.md`, and `docs/UPDATE_POLICY.md`.

## Authority and conflict resolution

- The actual code and current tests define implemented behavior. Documentation must be corrected when it disagrees with code.
- `docs/LOCAL_AI_HANDOFF.md` defines current scope, hard constraints, verified status, and immediate priorities.
- The master blueprint defines intended architecture, not permission to implement every future component now.
- If a requirement is ambiguous or conflicts with a safety boundary, stop and document the question; do not invent product behavior.
- Update the handoff, roadmap, and affected operational docs in the same change as meaningful behavior changes.

## Non-negotiable product constraints

- Single VPS first. Keep the initial installation simple and operable by one person.
- Hybrid onboarding: CLI for installation, preflight, and explicit host-level activation; Web for Superadmin setup, workspace, installation profile, node identity, language/timezone, access mode, domain information, DNS check, and progress.
- No mandatory Kubernetes, K3s, CloudStack, Keycloak, second VPS, DNS provider token, billing account, cloud API key, or SSH private key in the first-VPS flow.
- Private SSH-tunnel access is the default and recovery path.
- Public managed domain requires an explicit operator action, correct DNS A record, and provider firewall TCP 80/443. Existing reverse proxy is a separate mode.
- Never silently change host firewall or SSH daemon settings.
- Never silently expose public ports, deploy updates, restart services for an unapproved change, or delete persistent data.
- Update detection is informational. Apply only the exact commit explicitly approved by the Superadmin and confirmed by the operator in the VPS terminal.
- Do not claim HA, global CDN, Anycast, volumetric DDoS mitigation, multi-region resilience, or production readiness without architecture and test evidence.
- Do not run untrusted customer workloads on the control-plane VPS or expose Docker socket to the web application.
- Mandatory runtime dependencies must be OSI-approved open source. Verify exact licenses, editions, images, plugins, and transitive dependencies.

## Engineering rules

- Inspect repository state, relevant files, tests, and open issues before editing.
- Prefer small, cohesive changes. Avoid speculative abstractions, placeholder modules, duplicate docs, and unnecessary dependencies.
- Keep the initial application a modular monolith. Extract services only for a demonstrated deployment, scale, ownership, or security boundary.
- Preserve existing secrets, database volumes, runtime Caddy configuration, and operator settings during update/repair.
- Database changes must be additive and backward-compatible until a tested migration framework exists.
- Shell scripts use strict mode, quote variables, validate inputs, explain host changes, and fail safely.
- Add regression tests for every fix where practical. Test failure paths, not only happy paths.
- Never say tests passed unless the exact test command completed successfully. A queued GitHub Actions run is not a pass.
- Never report a VPS smoke test unless it was run on a real supported VPS.
- Do not commit secrets, local env files, private keys, credentials, customer data, or generated runtime state.

## Git and delivery

- `main` is the stable branch. Use `dev` for integration when active; feature branches use `feat/<scope>-<name>`, fixes `fix/<scope>-<name>`, and maintenance `chore/<scope>-<name>`.
- Use Conventional Commits.
- Never force-push or overwrite concurrent work. Fetch the latest branch head and use a lease/expected SHA for ref updates.
- CI and GitHub Releases must never deploy to a VPS.
- Before declaring a task complete: inspect the diff, run relevant tests/checks, update docs, commit, and verify the resulting branch head.
- Report completed work, exact commit, tests and their actual status, unresolved risks, and the next actionable step.
