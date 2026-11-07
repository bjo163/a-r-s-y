# A-R-S-Y — Encrypted Backup and Restore Drill

## Purpose and status

A-R-S-Y includes an opt-in backup/restore toolchain using Restic and PostgreSQL custom-format dumps. It does not configure a storage provider, create credentials, schedule jobs, or claim a backup exists until an operator configures a remote repository and runs the backup.

The backup repository must be outside the VPS/provider failure domain. A local path, local Docker volume, or second directory on the same VPS is not an off-site backup.

## Required operator setup

1. Install a supported Restic release on the VPS using the distribution's trusted package source or Restic's official installation instructions.
2. Create a dedicated remote repository with the selected S3-compatible, REST, SFTP, B2, Azure, Google Cloud, or other supported remote backend.
3. Create a strong Restic repository password. Store it in a root-owned file separate from the repository and from the VPS image.
4. Create /etc/arsy/backup.env with owner root:root and mode 0600. It is a root-only shell environment file. It may contain provider credentials, so do not commit it or paste its contents into logs or support requests.

Example structure (replace placeholders using a secure editor; never commit real values):

~~~bash
RESTIC_REPOSITORY="s3:https://s3.example.invalid/arsy-backups"
RESTIC_PASSWORD_FILE="/etc/arsy/restic-password"
AWS_ACCESS_KEY_ID="REPLACE_WITH_PROVIDER_ACCESS_KEY"
AWS_SECRET_ACCESS_KEY="REPLACE_WITH_PROVIDER_SECRET_KEY"
~~~

Create the password file, set both files to root:root and mode 0600, then initialize the remote repository once:

~~~bash
sudo install -d -o root -g root -m 0700 /etc/arsy
sudo chown root:root /etc/arsy/backup.env /etc/arsy/restic-password
sudo chmod 0600 /etc/arsy/backup.env /etc/arsy/restic-password
sudo bash -c 'set -a; . /etc/arsy/backup.env; set +a; restic init'
~~~

Do not run restic init against an existing repository. Confirm the repository URL and account before initialization.

## Create a backup

~~~bash
sudo arsy-backup
~~~

The command:
- takes a root-only temporary staging copy of .env, runtime Caddyfile, deployed SHA, and optional managed-domain state;
- runs pg_dump -Fc against the live PostgreSQL service;
- encrypts and uploads the staging directory with Restic;
- does not run forget --prune, delete old snapshots, or remove production data.

The local staging directory is removed on exit. A machine/power failure can interrupt cleanup; verify and remove stale backup-stage directories only after confirming no backup process is running.

## Run an isolated restore drill

~~~bash
sudo arsy-restore-drill latest
~~~

The drill:
- restores the latest arsy-tagged snapshot into a temporary directory;
- verifies that .env, Caddyfile, deployed SHA and database dump are present;
- starts a disposable postgres:17-alpine container with --network none and no published ports;
- restores the dump and checks the A-R-S-Y schema and settings table;
- removes the temporary container and restored files.

It never overwrites /opt/arsy/.env, the live database volume, or the running Core service. A successful drill proves the backup archive can be restored into an isolated PostgreSQL instance; it does not prove application-level recovery on a replacement VPS.

## Retention, schedule and key recovery

Scheduling and retention are intentionally operator-configured. Before adding a systemd timer or Restic pruning policy, choose a measured RPO/RTO, retention window, repository capacity, credential rotation process, and an owner for failed-job alerts. Never run restic forget --prune automatically without a separately reviewed retention policy.

The Restic password and provider credentials must be recoverable independently of the VPS. Losing the repository password can make encrypted backups permanently unreadable. Keep at least one tested recovery path for the password and remote-provider access.

## Acceptance evidence

Record repository type (not credentials), snapshot ID, UTC time, deployed SHA, restore-drill exit status, temporary PostgreSQL image, table count, and operator. Redact bucket names if sensitive, provider account IDs, access keys, password paths where revealing them is a risk, hostnames, IPs and all secrets.

**Release status:** the tooling is present, but off-site backup is not considered operational until a remote backend is configured and a restore drill passes on the actual installation. P3.2 remains a release gate until that evidence exists.
