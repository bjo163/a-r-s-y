# A-R-S-Y — Update Policy (Consent First)

## Product rule

A-R-S-Y must NEVER update itself silently.

The dashboard checks whether a newer commit exists and asks the Superadmin:
- **Update now:** explicitly approve the exact commit.
- **Later:** dismiss the notice. Keep the current version and data unchanged.

A Git push, merge to main, new release, or version detection must never trigger a VPS deployment by itself.

## Current single-VPS flow

1. The app reads the installed commit from /var/lib/arsy/deployed-sha.
2. An authenticated Superadmin dashboard checks GitHub main.
3. When a newer commit exists, the dashboard displays the current version, available version, and commit message.
4. The Superadmin chooses Update now and confirms.
5. The Core API records the approval and displays a command containing the exact approved SHA.
6. The operator runs that exact command in the VPS terminal.
7. The updater verifies that the approved commit still belongs to main, then deploys that commit.
8. The deploy runner builds the app, validates Compose, starts services, checks health, and attempts rollback on failure.

The browser never receives root credentials, a Docker socket, or an unrestricted shell. The terminal step is deliberate in this foundation build. A future host-side update agent may apply a confirmed request without exposing host privileges to the web process.

## Terminal check

~~~bash
sudo arsy-update
~~~

This checks the current main, shows the commit, and asks for confirmation. Any answer other than yes leaves the running system unchanged.

## GitHub behavior

- Pushes to main run CI only.
- Publishing a GitHub Release does not deploy to the VPS.
- No GitHub SSH deploy key or VPS deploy secret is required.
- A new commit only becomes an available update; installation always requires operator consent.

## Safety

- Serialize deployments with a host-side lock.
- Deploy the exact approved commit SHA; never silently switch to a newer SHA after approval.
- Validate Compose before starting services.
- Health-check the web application and database.
- Attempt rollback to the last known-good source revision if startup or health checks fail.
- Preserve .env and persistent PostgreSQL volumes.
- Database schema changes must be backward-compatible and additive until a tested migration framework exists.
- Never delete persistent volumes during update or rollback.
