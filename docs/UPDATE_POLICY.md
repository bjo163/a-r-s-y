# A-R-S-Y — Update Policy (Consent First)

## Product rule

A-R-S-Y must NEVER update itself silently.

The application detects that a newer version is available and asks the operator:

> A-R-S-Y update available. Do you want to update now?

The operator chooses:
- **Update now:** show the update details and explicitly confirm. Only then start the update.
- **Later:** dismiss the notification. Keep the current version and data unchanged.

A Git push, merge to main, new release, or detected version must never trigger a VPS deployment by itself.

## Simple first-VPS behavior

The current foundation is a static gateway, so the full one-click application update flow is not available yet. For now:

1. The installed app version is recorded in `/var/lib/arsy/deployed-sha` and served as `/version.json`.
2. The operator can check for an update by running `sudo arsy-update`.
3. The script compares the installed commit with GitHub main.
4. It displays the current and available commit and asks `Do you want to update A-R-S-Y now? [y/N]`.
5. Only an explicit yes deploys the exact commit. Any other answer exits without changing the running version.

The future Core Console will perform the detection and show the same question inside the app. The authenticated Core API will execute the same local update runner only after an authenticated operator confirms. Do not expose a root shell or Docker socket to the browser.

## Rules for the future app UI

- Check the official release channel (preferred) or configured update channel.
- Show installed version, available version, release date, and concise changelog.
- Never force an update or reload the page without approval.
- "Later" must preserve the installed version and allow another check later.
- "Update now" must show a confirmation step and state whether a restart or brief downtime is expected.
- The backend must re-check the target version and authorization before starting.
- Serialize updates; do not run two updates concurrently.
- Validate configuration, apply the update, run health checks, and attempt rollback on failure.
- Display progress and the final result. Never report success before health verification.
- Preserve customer configuration and persistent data.
- Do not use an untrusted client-supplied commit SHA. Resolve an approved release from the server-side update channel.

## GitHub behavior

- GitHub pushes to main run CI only.
- GitHub Releases do not deploy automatically.
- No GitHub Actions SSH key, VPS deploy secret, or deployment workflow is required.
- A human may trigger a release, but publishing it only makes an update available; it does not install it.

## Manual emergency update

On the VPS:

~~~bash
sudo arsy-update
~~~

To inspect current deployed version:

~~~bash
cat /var/lib/arsy/deployed-sha
cat /opt/arsy/site/version.json
~~~

To inspect update logs:

~~~bash
sudo tail -n 100 /var/log/arsy/deploy.log
~~~
