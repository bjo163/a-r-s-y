#!/usr/bin/env bash
set -Eeuo pipefail

TEST_MODE="${ARSY_TEST_MODE:-0}"
APP_DIR="${ARSY_APP_DIR:-/opt/arsy}"
STATE_DIR="${ARSY_STATE_DIR:-/var/lib/arsy}"
LOG_DIR="${ARSY_LOG_DIR:-/var/log/arsy}"
LOCK_FILE="${ARSY_DEPLOY_LOCK_FILE:-/run/lock/arsy-deploy.lock}"
HOST_BIN_DIR="${ARSY_HOST_BIN_DIR:-/usr/local/sbin}"
TARGET_SHA="${1:-}"

log() { printf '[ARSY-DEPLOY] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

if [[ "$TEST_MODE" == "1" ]]; then
  [[ "$APP_DIR" != "/opt/arsy" && "$STATE_DIR" != "/var/lib/arsy" && "$HOST_BIN_DIR" != "/usr/local/sbin" ]] || die "Test mode requires isolated temporary paths."
else
  [[ "$EUID" -eq 0 ]] || die "Must run as root."
fi
[[ "$TARGET_SHA" =~ ^[0-9a-f]{40}$ ]] || die "Expected a 40-character lowercase Git commit SHA."
[[ -d "$APP_DIR/.git" ]] || die "Git checkout not found at $APP_DIR."
command -v docker >/dev/null 2>&1 || die "Docker is not installed."
command -v curl >/dev/null 2>&1 || die "curl is not installed."
command -v flock >/dev/null 2>&1 || die "flock is not installed."
command -v openssl >/dev/null 2>&1 || die "openssl is not installed."

install -d -m 0750 "$LOG_DIR" "$(dirname -- "$LOCK_FILE")"
install -d -m 0755 "$STATE_DIR"
chmod 0755 "$STATE_DIR"
install -d -m 0755 "$HOST_BIN_DIR"
exec 9>"$LOCK_FILE"
flock -n 9 || die "Another deployment is already running."
exec > >(tee -a "$LOG_DIR/deploy.log") 2>&1

cd "$APP_DIR"
[[ -f .env ]] || die "Missing $APP_DIR/.env."
chmod 0600 .env

# Preserve operator-owned environment across migration and a failed deployment.
ENV_BACKUP="$(mktemp "$APP_DIR/.env.deploy-backup.XXXXXX")"
cp -p .env "$ENV_BACKUP"
cleanup_env_backup() {
  local status="$?"
  trap - EXIT
  if (( status != 0 )) && [[ -f "$ENV_BACKUP" ]]; then
    if cp -p "$ENV_BACKUP" "$APP_DIR/.env.restore.tmp"; then
      chmod 0600 "$APP_DIR/.env.restore.tmp"
      mv -f "$APP_DIR/.env.restore.tmp" "$APP_DIR/.env"
      log "Original .env restored after deployment failure."
    else
      log "CRITICAL: .env backup retained at $ENV_BACKUP; manual recovery is required."
      exit "$status"
    fi
  fi
  rm -f -- "$ENV_BACKUP"
  exit "$status"
}
trap cleanup_env_backup EXIT

# Runtime gateway configuration must survive Git checkouts and updates.
install -d -m 0755 "$STATE_DIR"
if [[ ! -f "$STATE_DIR/Caddyfile" ]]; then
  install -m 0644 "$APP_DIR/Caddyfile" "$STATE_DIR/Caddyfile"
fi

OLD_SHA="$(cat "$STATE_DIR/deployed-sha" 2>/dev/null || true)"

ensure_env() {
  local key="$1" value="$2"
  if ! grep -qE "^${key}=" .env; then
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

log "Fetching approved source revision."
git fetch --prune origin main
git cat-file -e "${TARGET_SHA}^{commit}" 2>/dev/null || die "Target commit is not available."
git checkout --detach "$TARGET_SHA"
git reset --hard "$TARGET_SHA"
# Run the migration from the approved target tree so existing installations
# without this helper can safely transition before the new Compose mapping.
# Environment migration runs after rollback handlers are defined.

compose() {
  docker compose --env-file .env -f compose.yaml "$@"
}

compose_up() {
  compose config --quiet
  if compose config --services | grep -qx 'app'; then
    compose build --pull app
  fi
  compose up -d --remove-orphans
}

wait_for_health() {
  local http_port health_url attempt healthy=0
  local health_attempts="${ARSY_DEPLOY_HEALTH_ATTEMPTS:-60}"
  local health_interval="${ARSY_DEPLOY_HEALTH_INTERVAL:-2}"
  http_port="$(sed -n 's/^ARSY_HTTP_PORT=//p' .env | tail -n1 | tr -d '\r')"
  http_port="${http_port:-18080}"
  [[ "$http_port" =~ ^[0-9]{1,5}$ ]] && (( http_port >= 1 && http_port <= 65535 )) || return 1
  health_url="http://127.0.0.1:${http_port}/healthz"
  for attempt in $(seq 1 "$health_attempts"); do
    if curl -fsS --connect-timeout 2 --max-time 5 "$health_url" >/dev/null 2>&1; then
      healthy=1
      break
    fi
    sleep "$health_interval"
  done
  [[ "$healthy" -eq 1 ]]
}

restore_env_backup() {
  [[ -f "$ENV_BACKUP" ]] || return 0
  cp -p "$ENV_BACKUP" "$APP_DIR/.env.restore.tmp"
  chmod 0600 "$APP_DIR/.env.restore.tmp"
  mv -f "$APP_DIR/.env.restore.tmp" "$APP_DIR/.env"
}

rollback() {
  local reason="$1"
  log "Deployment failed: $reason"
  restore_env_backup || log "CRITICAL: could not restore the original .env; backup retained at $ENV_BACKUP."
  if [[ -n "$OLD_SHA" ]] && git cat-file -e "${OLD_SHA}^{commit}" 2>/dev/null; then
    log "Restoring previous source revision $OLD_SHA."
    git checkout --detach "$OLD_SHA"
    git reset --hard "$OLD_SHA"
    if compose_up && wait_for_health; then
      log "Previous stack restored and health-checked. Persistent volumes were preserved."
    else
      log "CRITICAL: rollback or its health check failed. Inspect Docker Compose logs and preserve the database volume."
    fi
  else
    log "No previous deployment is recorded. Initial deployment requires manual repair if it fails."
    compose down --remove-orphans || true
  fi
  exit 1
}

# Migrate only after the rollback path exists. Any partial migration or later
# deployment failure restores the exact pre-deployment .env backup.
if ! bash "$APP_DIR/scripts/arsy-env-migrate.sh" "$APP_DIR/.env"; then
  rollback "Environment migration failed."
fi

# Defaults are intentionally added only after the legacy layout has been migrated.
ensure_env ARSY_HTTP_PORT "18080"
ensure_env ARSY_PUBLIC_HTTP_BIND "127.0.0.1"
ensure_env ARSY_PUBLIC_HTTP_PORT "18081"
ensure_env ARSY_PUBLIC_HTTPS_BIND "127.0.0.1"
ensure_env ARSY_PUBLIC_HTTPS_PORT "18444"
ensure_env ARSY_PROXY_HTTP_PORT "18082"
ensure_env TZ "Asia/Jakarta"
ensure_env POSTGRES_DB "arsy"
ensure_env POSTGRES_USER "arsy"
ensure_env POSTGRES_PASSWORD "$(openssl rand -hex 32)"
ensure_env ARSY_SESSION_SECRET "$(openssl rand -hex 48)"
ensure_env ARSY_SETUP_TOKEN "$(openssl rand -hex 32)"
ensure_env ARSY_COOKIE_SECURE "false"

log "Pulling gateway and database images."
compose pull gateway || rollback "Gateway image pull failed."
if compose config --services | grep -qx 'db'; then
  compose pull db || rollback "PostgreSQL image pull failed."
fi

log "Building application and starting services."
compose_up || rollback "Compose deployment failed."

wait_for_health || rollback "Health check failed after deployment."

printf '%s\n' "$TARGET_SHA" > "$STATE_DIR/deployed-sha.tmp"
if [[ "$TEST_MODE" == "1" ]]; then
  install -m 0444 "$STATE_DIR/deployed-sha.tmp" "$STATE_DIR/deployed-sha"
else
  install -m 0444 -o root -g root "$STATE_DIR/deployed-sha.tmp" "$STATE_DIR/deployed-sha"
fi
rm -f "$STATE_DIR/deployed-sha.tmp"

install -m 0755 scripts/arsy-deploy.sh "$HOST_BIN_DIR/arsy-deploy"
install -m 0755 scripts/arsy-update.sh "$HOST_BIN_DIR/arsy-update"
install -m 0755 scripts/arsy-doctor.sh "$HOST_BIN_DIR/arsy-doctor"
install -m 0755 scripts/arsy-domain.sh "$HOST_BIN_DIR/arsy-domain"
install -m 0755 scripts/arsy-env-migrate.sh "$HOST_BIN_DIR/arsy-env-migrate"
install -m 0755 scripts/arsy-network.sh "$HOST_BIN_DIR/arsy-network.sh"
install -m 0755 scripts/arsy-backup.sh "$HOST_BIN_DIR/arsy-backup"
install -m 0755 scripts/arsy-restore-drill.sh "$HOST_BIN_DIR/arsy-restore-drill"

log "SUCCESS: $TARGET_SHA is deployed and healthy."
compose ps
