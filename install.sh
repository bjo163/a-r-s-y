#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/bjo163/a-r-s-y.git"
APP_DIR="${ARSY_APP_DIR:-/opt/arsy}"

log() { printf '\n[ARSY] %s\n' "$*"; }
die() { printf '\n[ARSY][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run with sudo: sudo bash install.sh"
[[ -f /etc/os-release ]] || die "/etc/os-release not found."
. /etc/os-release

case "${ID:-}" in
  ubuntu)
    [[ "${VERSION_ID%%.*}" -ge 22 ]] || die "Ubuntu 22.04 or newer is required."
    DISTRO=ubuntu
    ;;
  debian)
    [[ "${VERSION_ID%%.*}" -ge 12 ]] || die "Debian 12 or newer is required."
    DISTRO=debian
    ;;
  *)
    die "Supported operating systems: Ubuntu 22.04+ or Debian 12+."
    ;;
esac

log "Installing basic tools."
apt-get update
apt-get install -y ca-certificates curl git

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  log "Installing Docker Engine and Compose from the official Docker repository."
  apt-get install -y gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$DISTRO/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
    "$(dpkg --print-architecture)" "$DISTRO" "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker.list
  apt-get update
  if command -v docker >/dev/null 2>&1; then
    apt-get install -y docker-compose-plugin
  else
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
fi

systemctl enable --now docker
docker info >/dev/null 2>&1 || die "Docker daemon is not responding."
docker compose version >/dev/null 2>&1 || die "Docker Compose plugin is not available."

if [[ -d "$APP_DIR/.git" ]]; then
  if [[ -s /var/lib/arsy/deployed-sha ]]; then
    log "A-R-S-Y is already installed. The installer will not update it automatically."
    log "Use the consent-based update command instead: sudo arsy-update"
    exit 0
  fi
  log "Existing pre-alpha checkout found. Preserving .env and local data."
elif [[ -e "$APP_DIR" && -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  die "$APP_DIR exists and is not an A-R-S-Y checkout. Move it or set ARSY_APP_DIR."
else
  install -d -m 0755 "$(dirname "$APP_DIR")"
  log "Cloning A-R-S-Y."
  git clone --branch main "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
[[ -f compose.yaml && -f .env.example && -f scripts/arsy-deploy.sh && -f scripts/arsy-update.sh ]] || die "Required A-R-S-Y files are missing."

if [[ ! -f .env ]]; then
  printf 'ARSY_HTTP_BIND=%s\nARSY_HTTP_PORT=%s\nTZ=%s\n' \
    "${ARSY_HTTP_BIND:-127.0.0.1}" "${ARSY_HTTP_PORT:-18080}" "${TZ:-Asia/Jakarta}" > .env
  chmod 0600 .env
else
  chmod 0600 .env
  log "Keeping existing .env unchanged."
fi

install -d -m 0750 /var/log/arsy /var/lib/arsy
install -m 0755 scripts/arsy-deploy.sh /usr/local/sbin/arsy-deploy
install -m 0755 scripts/arsy-update.sh /usr/local/sbin/arsy-update

git fetch --quiet origin main --tags
TARGET_SHA="$(git rev-parse refs/remotes/origin/main)"
log "Installing initial version ${TARGET_SHA:0:12}."
/usr/local/sbin/arsy-deploy "$TARGET_SHA"

PORT="$(sed -n 's/^ARSY_HTTP_PORT=//p' .env | tail -n1)"
PORT="${PORT:-18080}"
cat <<OUT

A-R-S-Y Core Node installed.

  App directory : $APP_DIR
  Local portal  : http://127.0.0.1:$PORT/
  Health check  : http://127.0.0.1:$PORT/healthz

Updates are NEVER installed automatically.
Check and approve an update with:

  sudo arsy-update

The web application will later show an update notification and ask for your approval.
OUT
