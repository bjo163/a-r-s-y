#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${ARSY_APP_DIR:-/opt/arsy}"
STATE_DIR="${ARSY_STATE_DIR:-/var/lib/arsy}"
ENV_FILE="${ARSY_ENV_FILE:-$APP_DIR/.env}"
CADDY_FILE="${ARSY_CADDY_FILE:-$STATE_DIR/Caddyfile}"
DEPLOYED_SHA_FILE="${ARSY_DEPLOYED_SHA_FILE:-$STATE_DIR/deployed-sha}"
BACKUP_CONFIG="${ARSY_BACKUP_CONFIG:-/etc/arsy/backup.env}"
LOCK_FILE="${ARSY_BACKUP_LOCK_FILE:-/run/lock/arsy-backup.lock}"
log(){ printf '[ARSY-BACKUP] %s\n' "$*"; }
die(){ log "ERROR: $*" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run with sudo."
[[ -r "$BACKUP_CONFIG" ]] || die "Missing backup config: $BACKUP_CONFIG"
[[ -f "$ENV_FILE" && -f "$CADDY_FILE" && -f "$DEPLOYED_SHA_FILE" ]] || die "A-R-S-Y runtime files are incomplete."
[[ "$(stat -c '%u' "$BACKUP_CONFIG")" == "0" ]] || die "Backup config must be owned by root."
CONFIG_MODE="$(stat -c '%a' "$BACKUP_CONFIG")"
[[ "$CONFIG_MODE" == "600" || "$CONFIG_MODE" == "400" ]] || die "Backup config must use mode 0600 or 0400."

# This is an intentionally root-only shell configuration file. Keep provider
# credentials and the Restic password-file path out of command-line arguments.
set -a
# shellcheck disable=SC1090
. "$BACKUP_CONFIG"
set +a

[[ -n "${RESTIC_REPOSITORY:-}" ]] || die "RESTIC_REPOSITORY is required."
[[ -n "${RESTIC_PASSWORD_FILE:-}" && -f "$RESTIC_PASSWORD_FILE" ]] || die "RESTIC_PASSWORD_FILE must point to an existing password file."
[[ "$(stat -c '%u' "$RESTIC_PASSWORD_FILE")" == "0" ]] || die "Restic password file must be owned by root."
PASSWORD_MODE="$(stat -c '%a' "$RESTIC_PASSWORD_FILE")"
[[ "$PASSWORD_MODE" == "600" || "$PASSWORD_MODE" == "400" ]] || die "Restic password file must use mode 0600 or 0400."
[[ "$RESTIC_REPOSITORY" =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]] || die "RESTIC_REPOSITORY must use a remote Restic backend URI."
case "$RESTIC_REPOSITORY" in
  file:*|local:*|/*|./*|../*) die "Local filesystem repositories are not accepted for off-site backups." ;;
esac

for command_name in restic docker flock; do
  command -v "$command_name" >/dev/null 2>&1 || die "Required command is missing: $command_name"
done

install -d -m 0755 "$STATE_DIR" "$(dirname -- "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock -n 9 || die "Another A-R-S-Y backup is running."

STAGE="$(mktemp -d "$STATE_DIR/backup-stage.XXXXXX")"
chmod 0700 "$STAGE"
cleanup(){ [[ -n "${STAGE:-}" && -d "$STAGE" ]] && rm -rf -- "$STAGE"; }
trap cleanup EXIT

install -d -m 0700 "$STAGE/host"
install -m 0600 "$ENV_FILE" "$STAGE/host/.env"
install -m 0600 "$CADDY_FILE" "$STAGE/host/Caddyfile"
install -m 0600 "$DEPLOYED_SHA_FILE" "$STAGE/host/deployed-sha"
if [[ -f "$STATE_DIR/domain-state" ]]; then
  install -m 0600 "$STATE_DIR/domain-state" "$STAGE/host/domain-state"
fi

log "Creating a consistent PostgreSQL custom-format dump."
docker compose --env-file "$ENV_FILE" -f "$APP_DIR/compose.yaml" exec -T db \
  sh -ec 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$STAGE/database.dump"
[[ -s "$STAGE/database.dump" ]] || die "Database dump is empty."

{
  printf 'created_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'deployed_sha=%s\n' "$(tr -d '\r\n' < "$DEPLOYED_SHA_FILE")"
  printf 'host_label=%s\n' "$(hostname -s 2>/dev/null || hostname)"
} > "$STAGE/metadata.txt"
chmod 0600 "$STAGE/metadata.txt"

log "Checking remote Restic repository."
restic snapshots >/dev/null
log "Uploading encrypted snapshot to the configured remote repository."
restic backup --tag arsy --tag arsy-core --host "$(hostname -s 2>/dev/null || hostname)" "$STAGE"
log "Backup completed. No retention pruning or local data deletion was performed."
