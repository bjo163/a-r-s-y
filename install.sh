#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/arsy"
REPO_URL="https://github.com/bjo163/a-r-s-y.git"

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

if [[ -f /var/lib/arsy/deployed-sha && "${1:-}" != "--repair" ]]; then
  log "A-R-S-Y is already installed."
  log "Use 'sudo arsy-update' to check for an update, or run 'sudo bash install.sh --repair' for an explicit repair/reinstall."
  exit 0
fi
if [[ -n "${1:-}" && "${1:-}" != "--repair" ]]; then
  die "Usage: sudo bash install.sh [--repair]"
fi

log "Preflight summary"
printf '  OS             %s %s\n' "$PRETTY_NAME" "${VERSION_ID:-}"
printf '  Architecture   %s\n' "$(dpkg --print-architecture)"
printf '  Hostname       %s\n' "$(hostname -f 2>/dev/null || hostname)"
printf '  CPU cores      %s\n' "$(nproc)"
printf '  Memory         %s\n' "$(awk '/MemTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
printf '  Root disk free %s\n' "$(df -h / | awk 'NR==2 {print $4}')"
printf '  Docker         %s\n' "$(command -v docker >/dev/null 2>&1 && docker --version || echo 'will be installed')"
printf '  Panel bind     127.0.0.1:18080 (private by default)\n'
printf '  Public ports   80/443 are not opened by this installer\n'
printf '\nThe installer will install prerequisites if missing, create /opt/arsy, create secrets, and start PostgreSQL + A-R-S-Y Core. Existing firewall and SSH settings will not be changed.\n'
if [[ -t 0 ]]; then
  read -r -p "Continue with installation? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || die "Installation cancelled. No changes made."
elif [[ "${ARSY_INSTALL_CONFIRM:-}" != "1" ]]; then
  die "Non-interactive install requires ARSY_INSTALL_CONFIRM=1 after reviewing this script."
fi

log "Installing basic tools."
apt-get update
apt-get install -y ca-certificates curl git openssl

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
  log "Using existing A-R-S-Y checkout at $APP_DIR."
elif [[ -e "$APP_DIR" && -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  die "$APP_DIR exists and is not an A-R-S-Y checkout. Move it before installing."
else
  install -d -m 0755 "$(dirname "$APP_DIR")"
  log "Cloning A-R-S-Y."
  git clone --branch main "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
git fetch --quiet origin main
TARGET_SHA="$(git rev-parse refs/remotes/origin/main)"
git checkout --detach "$TARGET_SHA"

ensure_env() {
  local key="$1" value="$2"
  if ! grep -qE "^${key}=" .env 2>/dev/null; then
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

touch .env
ensure_env ARSY_HTTP_BIND "127.0.0.1"
ensure_env ARSY_HTTP_PORT "18080"
ensure_env TZ "Asia/Jakarta"
ensure_env POSTGRES_DB "arsy"
ensure_env POSTGRES_USER "arsy"
ensure_env POSTGRES_PASSWORD "$(openssl rand -hex 32)"
ensure_env ARSY_SESSION_SECRET "$(openssl rand -hex 48)"
ensure_env ARSY_SETUP_TOKEN "$(openssl rand -hex 32)"
ensure_env ARSY_COOKIE_SECURE "false"
chmod 0600 .env

install -d -m 0750 /var/log/arsy
install -d -m 0755 /var/lib/arsy
chmod 0755 /var/lib/arsy
install -m 0755 scripts/arsy-deploy.sh /usr/local/sbin/arsy-deploy
install -m 0755 scripts/arsy-update.sh /usr/local/sbin/arsy-update
install -m 0755 scripts/arsy-doctor.sh /usr/local/sbin/arsy-doctor
install -m 0755 scripts/arsy-domain.sh /usr/local/sbin/arsy-domain

log "Installing A-R-S-Y Core and database. This may take a few minutes."
/usr/local/sbin/arsy-deploy "$TARGET_SHA"

PORT="$(sed -n 's/^ARSY_HTTP_PORT=//p' .env | tail -n1)"
PORT="${PORT:-18080}"
SETUP_TOKEN="$(sed -n 's/^ARSY_SETUP_TOKEN=//p' .env | tail -n1)"

cat <<OUT

A-R-S-Y is installed.

  Web              http://127.0.0.1:$PORT
  Health           http://127.0.0.1:$PORT/healthz
  Setup            http://127.0.0.1:$PORT/setup
  App directory    $APP_DIR

FIRST SUPERADMIN SETUP KEY (save it):
$SETUP_TOKEN

Open the web app through an SSH tunnel, create the first Superadmin, and keep
the setup key private. After setup, initial enrollment is permanently closed.

Check updates any time:
  sudo arsy-update

Updates are detected first and require your approval.
OUT
