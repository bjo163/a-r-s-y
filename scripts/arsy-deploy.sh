#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/arsy"
LOG_DIR="/var/log/arsy"
LOCK_FILE="/run/lock/arsy-deploy.lock"
TARGET_SHA="${1:-}"

log() { printf '[ARSY-DEPLOY] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Must run as root."
[[ "$TARGET_SHA" =~ ^[0-9a-f]{40}$ ]] || die "Expected a 40-character lowercase Git commit SHA."
[[ -d "$APP_DIR/.git" ]] || die "Git checkout not found at $APP_DIR."
command -v docker >/dev/null 2>&1 || die "Docker is not installed."
command -v curl >/dev/null 2>&1 || die "curl is not installed."
command -v flock >/dev/null 2>&1 || die "flock is not installed."
command -v openssl >/dev/null 2>&1 || die "openssl is not installed."

install -d -m 0750 "$LOG_DIR" /run/lock
install -d -m 0755 /var/lib/arsy
chmod 0755 /var/lib/arsy
exec 9>"$LOCK_FILE"
flock -n 9 || die "Another deployment is already running."
exec > >(tee -a "$LOG_DIR/deploy.log") 2>&1

cd "$APP_DIR"
[[ -f .env ]] || die "Missing $APP_DIR/.env."
chmod 0600 .env
bash "$APP_DIR/scripts/arsy-env-migrate.sh" "$APP_DIR/.env"

# Runtime gateway configuration must survive Git checkouts and updates.
install -d -m 0755 /var/lib/arsy
if [[ ! -f /var/lib/arsy/Caddyfile ]]; then
  install -m 0644 "$APP_DIR/Caddyfile" /var/lib/arsy/Caddyfile
fi

OLD_SHA="$(cat /var/lib/arsy/deployed-sha 2>/dev/null || true)"

ensure_env() {
  local key="$1" value="$2"
  if ! grep -qE "^${key}=" .env; then
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

ensure_env ARSY_HTTP_PORT "18080"
ensure_env ARSY_PUBLIC_HTTP_BIND "127.0.0.1"
ensure_env ARSY_PUBLIC_HTTP_PORT "18081"
ensure_env ARSY_PUBLIC_HTTPS_BIND "127.0.0.1"
ensure_env ARSY_PUBLIC_HTTPS_PORT "18444"
ensure_env TZ "Asia/Jakarta"
ensure_env POSTGRES_DB "arsy"
ensure_env POSTGRES_USER "arsy"
ensure_env POSTGRES_PASSWORD "$(openssl rand -hex 32)"
ensure_env ARSY_SESSION_SECRET "$(openssl rand -hex 48)"
ensure_env ARSY_SETUP_TOKEN "$(openssl rand -hex 32)"
ensure_env ARSY_COOKIE_SECURE "false"

log "Fetching approved source revision."
git fetch --prune origin main
git cat-file -e "${TARGET_SHA}^{commit}" 2>/dev/null || die "Target commit is not available."
git checkout --detach "$TARGET_SHA"
git reset --hard "$TARGET_SHA"

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

rollback() {
  local reason="$1"
  log "Deployment failed: $reason"
  if [[ -n "$OLD_SHA" ]] && git cat-file -e "${OLD_SHA}^{commit}" 2>/dev/null; then
    log "Restoring previous source revision $OLD_SHA."
    git checkout --detach "$OLD_SHA"
    git reset --hard "$OLD_SHA"
    if compose_up; then
      log "Previous stack restored. Database migrations are additive and must remain backward-compatible."
    else
      log "CRITICAL: rollback failed. Inspect Docker Compose logs and preserve the database volume."
    fi
  else
    log "No previous deployment is recorded. Initial deployment requires manual repair if it fails."
    compose down --remove-orphans || true
  fi
  exit 1
}

log "Pulling gateway and database images."
compose pull gateway || rollback "Gateway image pull failed."
if compose config --services | grep -qx 'db'; then
  compose pull db || rollback "PostgreSQL image pull failed."
fi

log "Building application and starting services."
compose_up || rollback "Compose deployment failed."

HTTP_PORT="$(sed -n 's/^ARSY_HTTP_PORT=//p' .env | tail -n1 | tr -d '\r')"
HTTP_PORT="${HTTP_PORT:-18080}"
[[ "$HTTP_PORT" =~ ^[0-9]{1,5}$ ]] && (( HTTP_PORT >= 1 && HTTP_PORT <= 65535 )) || rollback "ARSY_HTTP_PORT is invalid."

HEALTH_URL="http://127.0.0.1:${HTTP_PORT}/healthz"
healthy=0
for attempt in $(seq 1 60); do
  if curl -fsS --connect-timeout 2 --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
[[ "$healthy" -eq 1 ]] || rollback "Health check failed at $HEALTH_URL."

printf '%s\n' "$TARGET_SHA" > /var/lib/arsy/deployed-sha.tmp
install -m 0444 -o root -g root /var/lib/arsy/deployed-sha.tmp /var/lib/arsy/deployed-sha
rm -f /var/lib/arsy/deployed-sha.tmp

install -m 0755 scripts/arsy-deploy.sh /usr/local/sbin/arsy-deploy
install -m 0755 scripts/arsy-update.sh /usr/local/sbin/arsy-update
install -m 0755 scripts/arsy-doctor.sh /usr/local/sbin/arsy-doctor
install -m 0755 scripts/arsy-domain.sh /usr/local/sbin/arsy-domain
install -m 0755 scripts/arsy-env-migrate.sh /usr/local/sbin/arsy-env-migrate
install -m 0755 scripts/arsy-network.sh /usr/local/sbin/arsy-network.sh

log "SUCCESS: $TARGET_SHA is deployed and healthy."
compose ps
