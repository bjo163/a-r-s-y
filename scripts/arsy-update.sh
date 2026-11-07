#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${ARSY_APP_DIR:-/opt/arsy}"
DEPLOY_BIN="/usr/local/sbin/arsy-deploy"

log() { printf '[ARSY-UPDATE] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run with sudo: sudo arsy-update"
[[ -d "$APP_DIR/.git" ]] || die "A-R-S-Y repository not found at $APP_DIR."
[[ -x "$DEPLOY_BIN" ]] || die "Deployment runner not installed. Re-run install.sh."
command -v git >/dev/null 2>&1 || die "git is required."

cd "$APP_DIR"
log "Checking GitHub for the latest main update..."
git fetch --quiet origin main
CURRENT_SHA="$(cat /var/lib/arsy/deployed-sha 2>/dev/null || git rev-parse HEAD)"
LATEST_SHA="$(git rev-parse refs/remotes/origin/main)"

if [[ "$CURRENT_SHA" == "$LATEST_SHA" ]]; then
  log "A-R-S-Y is already up to date (${CURRENT_SHA:0:12})."
  exit 0
fi

log "An update is available."
printf '  Current: %s\n  Latest : %s\n' "$CURRENT_SHA" "$LATEST_SHA"
git --no-pager log -1 --format='  Changes: %s (%h)' "$LATEST_SHA"
printf '\n'

case "${1:-}" in
  --yes)
    log "Applying update already approved by the application."
    exec "$DEPLOY_BIN" "$LATEST_SHA"
    ;;
  "")
    read -r -p "Do you want to update A-R-S-Y now? [y/N] " answer
    case "$answer" in
      y|Y|yes|YES)
        exec "$DEPLOY_BIN" "$LATEST_SHA"
        ;;
      *)
        log "Update skipped. Nothing has been changed."
        exit 0
        ;;
    esac
    ;;
  *)
    die "Usage: sudo arsy-update [--yes]"
    ;;
esac
