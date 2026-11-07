#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${ARSY_APP_DIR:-/opt/arsy}"
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

install -d -m 0750 "$LOG_DIR" /run/lock
exec 9>"$LOCK_FILE"
flock -n 9 || die "Another deployment is already running."
exec > >(tee -a "$LOG_DIR/deploy.log") 2>&1

cd "$APP_DIR"
[[ -f .env && -f compose.yaml ]] || die "Missing .env or compose.yaml."
OLD_SHA="$(cat /var/lib/arsy/deployed-sha 2>/dev/null || true)"

log "Fetching main and release tags."
git fetch --prune --tags origin '+refs/heads/main:refs/remotes/origin/main'
git cat-file -e "${TARGET_SHA}^{commit}" 2>/dev/null || die "Target commit $TARGET_SHA is not present after fetch."

rollback() {
  local reason="$1"
  log "Deployment failed: $reason"
  if [[ -n "$OLD_SHA" ]] && git cat-file -e "${OLD_SHA}^{commit}" 2>/dev/null; then
    log "Rolling back source and Compose stack to $OLD_SHA."
    git checkout --detach "$OLD_SHA"
    git reset --hard "$OLD_SHA"
    if docker compose --env-file .env -f compose.yaml config --quiet && docker compose --env-file .env -f compose.yaml up -d --remove-orphans; then
      log "Rollback stack started."
    else
      log "CRITICAL: rollback stack could not be started; inspect docker compose logs."
    fi
  else
    log "No previous commit exists; the initial deployment cannot be rolled back."
  fi
  exit 1
}

log "Checking out target commit $TARGET_SHA."
git checkout --detach "$TARGET_SHA"
git reset --hard "$TARGET_SHA"

docker compose --env-file .env -f compose.yaml config --quiet || rollback "Compose configuration is invalid."
docker compose --env-file .env -f compose.yaml pull || rollback "Image pull failed."
docker compose --env-file .env -f compose.yaml up -d --remove-orphans || rollback "Compose startup failed."

HTTP_PORT="$(sed -n 's/^ARSY_HTTP_PORT=//p' .env | tail -n1 | tr -d '\r')"
HTTP_PORT="${HTTP_PORT:-18080}"
[[ "$HTTP_PORT" =~ ^[0-9]{1,5}$ ]] && (( HTTP_PORT >= 1 && HTTP_PORT <= 65535 )) || rollback "ARSY_HTTP_PORT in .env is invalid."
HEALTH_URL="http://127.0.0.1:${HTTP_PORT}/healthz"
healthy=0
for attempt in $(seq 1 45); do
  if curl -fsS --connect-timeout 2 --max-time 4 "$HEALTH_URL" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
[[ "$healthy" -eq 1 ]] || rollback "Health check did not pass at $HEALTH_URL."

printf '%s\n' "$TARGET_SHA" > /var/lib/arsy-deployed-sha.tmp
install -m 0640 -o root -g root /var/lib/arsy-deployed-sha.tmp /var/lib/arsy/deployed-sha
rm -f /var/lib/arsy-deployed-sha.tmp

# Refresh privileged entrypoints only after the new release is healthy.
if [[ -f scripts/arsy-deploy.sh && -f scripts/arsy-deploy-gate.sh ]]; then
  install -m 0755 scripts/arsy-deploy.sh /usr/local/sbin/arsy-deploy
  install -m 0755 scripts/arsy-deploy-gate.sh /usr/local/sbin/arsy-deploy-gate
fi

log "SUCCESS: $TARGET_SHA is deployed and healthy."
docker compose --env-file .env -f compose.yaml ps
