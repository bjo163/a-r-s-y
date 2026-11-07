#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR="${ARSY_STATE_DIR:-/var/lib/arsy}"
BACKUP_CONFIG="${ARSY_BACKUP_CONFIG:-/etc/arsy/backup.env}"
RESTORE_IMAGE="${ARSY_RESTORE_POSTGRES_IMAGE:-postgres:17-alpine}"
SNAPSHOT="${1:-latest}"
log(){ printf '[ARSY-RESTORE-DRILL] %s\n' "$*"; }
die(){ log "ERROR: $*" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run with sudo."
[[ $# -le 1 ]] || die "Usage: sudo arsy-restore-drill [latest|snapshot-id]"
[[ "$SNAPSHOT" == "latest" || "$SNAPSHOT" =~ ^[a-f0-9]{8,64}$ ]] || die "Snapshot must be latest or a hexadecimal Restic ID."
[[ -r "$BACKUP_CONFIG" ]] || die "Missing backup config: $BACKUP_CONFIG"
[[ "$(stat -c '%u' "$BACKUP_CONFIG")" == "0" ]] || die "Backup config must be owned by root."
CONFIG_MODE="$(stat -c '%a' "$BACKUP_CONFIG")"
[[ "$CONFIG_MODE" == "600" || "$CONFIG_MODE" == "400" ]] || die "Backup config must use mode 0600 or 0400."
set -a
# shellcheck disable=SC1090
. "$BACKUP_CONFIG"
set +a

[[ -n "${RESTIC_REPOSITORY:-}" && -n "${RESTIC_PASSWORD_FILE:-}" && -f "$RESTIC_PASSWORD_FILE" ]] || die "Remote Restic repository/password configuration is incomplete."
[[ "$(stat -c '%u' "$RESTIC_PASSWORD_FILE")" == "0" ]] || die "Restic password file must be owned by root."
PASSWORD_MODE="$(stat -c '%a' "$RESTIC_PASSWORD_FILE")"
[[ "$PASSWORD_MODE" == "600" || "$PASSWORD_MODE" == "400" ]] || die "Restic password file must use mode 0600 or 0400."
[[ "$RESTIC_REPOSITORY" =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]] || die "RESTIC_REPOSITORY must use a remote backend URI."
case "$RESTIC_REPOSITORY" in
  file:*|local:*|/*|./*|../*) die "Restore drill requires an off-site repository." ;;
esac
for command_name in restic docker openssl; do
  command -v "$command_name" >/dev/null 2>&1 || die "Required command is missing: $command_name"
done

install -d -m 0755 "$STATE_DIR"
RESTORE_DIR="$(mktemp -d "$STATE_DIR/restore-drill.XXXXXX")"
chmod 0700 "$RESTORE_DIR"
DRILL_NAME="arsy-restore-drill-$(date +%s)-$$"
DRILL_PASSWORD="$(openssl rand -hex 24)"
cleanup(){
  docker rm -f "$DRILL_NAME" >/dev/null 2>&1 || true
  [[ -n "${RESTORE_DIR:-}" && -d "$RESTORE_DIR" ]] && rm -rf -- "$RESTORE_DIR"
}
trap cleanup EXIT

log "Restoring a tagged snapshot into a temporary directory."
restic restore "$SNAPSHOT" --tag arsy --target "$RESTORE_DIR"
DUMP_FILE="$(find "$RESTORE_DIR" -type f -name database.dump -print -quit)"
ENV_BACKUP="$(find "$RESTORE_DIR" -type f -path '*/host/.env' -print -quit)"
CADDY_BACKUP="$(find "$RESTORE_DIR" -type f -path '*/host/Caddyfile' -print -quit)"
SHA_BACKUP="$(find "$RESTORE_DIR" -type f -path '*/host/deployed-sha' -print -quit)"
[[ -n "$DUMP_FILE" && -s "$DUMP_FILE" ]] || die "Restored PostgreSQL dump is missing or empty."
[[ -n "$ENV_BACKUP" && -s "$ENV_BACKUP" ]] || die "Restored A-R-S-Y environment file is missing."
[[ -n "$CADDY_BACKUP" && -s "$CADDY_BACKUP" ]] || die "Restored Caddy configuration is missing."
[[ -n "$SHA_BACKUP" && -s "$SHA_BACKUP" ]] || die "Restored deployed SHA is missing."

log "Starting an isolated PostgreSQL restore target with no network and no published ports."
docker run -d --name "$DRILL_NAME" --network none --restart=no \
  -e POSTGRES_PASSWORD="$DRILL_PASSWORD" "$RESTORE_IMAGE" >/dev/null
ready=0
for attempt in $(seq 1 60); do
  if docker exec "$DRILL_NAME" pg_isready -U postgres >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[[ "$ready" -eq 1 ]] || die "Temporary PostgreSQL did not become ready."

docker exec "$DRILL_NAME" createdb -U postgres arsy_restore_drill
docker cp "$DUMP_FILE" "$DRILL_NAME:/tmp/arsy-restore.dump" >/dev/null
docker exec "$DRILL_NAME" pg_restore --no-owner --exit-on-error \
  -U postgres -d arsy_restore_drill /tmp/arsy-restore.dump
TABLE_COUNT="$(docker exec "$DRILL_NAME" psql -U postgres -d arsy_restore_drill -Atc \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")"
SETTINGS_COUNT="$(docker exec "$DRILL_NAME" psql -U postgres -d arsy_restore_drill -Atc \
  "SELECT COUNT(*) FROM arsy_settings")"
[[ "$TABLE_COUNT" =~ ^[0-9]+$ ]] && (( TABLE_COUNT >= 5 )) || die "Restore verification failed: expected A-R-S-Y tables, got '$TABLE_COUNT'."
[[ "$SETTINGS_COUNT" =~ ^[0-9]+$ ]] && (( SETTINGS_COUNT >= 1 )) || die "Restore verification failed: required platform settings are missing."

log "PASS: encrypted snapshot restored; PostgreSQL schema and platform settings are readable."
log "Temporary database was isolated with Docker network=none; production containers and volumes were not modified."
