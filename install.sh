#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/bjo163/a-r-s-y.git"
APP_DIR="${ARSY_APP_DIR:-/opt/arsy}"
DEPLOY_USER="arsy-deploy"
PUBLIC_KEY="${ARSY_DEPLOY_PUBLIC_KEY:-}"

log() { printf '\n[ARSY] %s\n' "$*"; }
die() { printf '\n[ARSY][ERROR] %s\n' "$*" >&2; exit 1; }
require_root() { [[ "$EUID" -eq 0 ]] || die "Run as root: sudo bash install.sh"; }

validate_public_key() {
  local key="$1" key_type key_blob key_comment
  [[ -n "$key" ]] || die "ARSY_DEPLOY_PUBLIC_KEY is empty."
  [[ "$key" != *$'\n'* ]] || die "Provide exactly one SSH public key on a single line."
  read -r key_type key_blob key_comment <<< "$key"
  [[ "$key_type" == "ssh-ed25519" ]] || die "Only ssh-ed25519 deploy keys are accepted."
  [[ -n "$key_blob" ]] || die "SSH public key payload is missing."
  printf '%s' "$key_blob" | base64 -d >/dev/null 2>&1 || die "SSH public key payload is not valid base64."
}

configure_deploy_key() {
  validate_public_key "$PUBLIC_KEY"
  id "$DEPLOY_USER" >/dev/null 2>&1 || useradd --create-home --user-group --shell /bin/bash "$DEPLOY_USER"
  install -d -m 0700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
  printf 'restrict,command="/usr/local/sbin/arsy-deploy-gate" %s\n' "$PUBLIC_KEY" > "/home/$DEPLOY_USER/.ssh/authorized_keys"
  chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"
  chmod 0600 "/home/$DEPLOY_USER/.ssh/authorized_keys"

  cat > /etc/sudoers.d/arsy-deploy <<SUDOERS
Defaults:$DEPLOY_USER !requiretty
$DEPLOY_USER ALL=(root) NOPASSWD: /usr/local/sbin/arsy-deploy
SUDOERS
  chmod 0440 /etc/sudoers.d/arsy-deploy
  visudo -cf /etc/sudoers.d/arsy-deploy >/dev/null || die "Generated sudoers file failed validation."
  log "Restricted GitHub deploy key configured for $DEPLOY_USER."
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Docker Engine and Compose plugin already available; leaving the existing installation untouched."
    return
  fi

  . /etc/os-release
  local distro="${ID:-}" codename="${VERSION_CODENAME:-}"
  [[ "$distro" == "ubuntu" || "$distro" == "debian" ]] || die "Unsupported Linux distribution: ${PRETTY_NAME:-unknown}. Use Ubuntu 22.04+ or Debian 12+."
  if [[ "$distro" == "ubuntu" ]]; then
    [[ "${VERSION_ID%%.*}" -ge 22 ]] || die "Ubuntu 22.04 or newer is required."
  else
    [[ "${VERSION_ID%%.*}" -ge 12 ]] || die "Debian 12 or newer is required."
  fi
  [[ -n "$codename" ]] || die "Could not determine OS release codename."

  if command -v docker >/dev/null 2>&1; then
    log "Docker exists but Compose v2 is missing. Installing the official Compose plugin without replacing the existing engine package."
  else
    log "Installing Docker Engine from the official Docker APT repository."
  fi

  apt-get update
  apt-get install -y ca-certificates curl git gnupg jq openssh-client
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$distro/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
    "$(dpkg --print-architecture)" "$distro" "$codename" > /etc/apt/sources.list.d/docker.list
  apt-get update

  if command -v docker >/dev/null 2>&1; then
    apt-get install -y docker-compose-plugin
  else
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  systemctl enable --now docker
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 installation failed."
}

configure_deploy_key_mode() {
  [[ -n "$PUBLIC_KEY" ]] || die "Set ARSY_DEPLOY_PUBLIC_KEY before using --configure-deploy-key."
  [[ -x /usr/local/sbin/arsy-deploy-gate ]] || die "A-R-S-Y is not installed yet. Run install.sh normally first."
  configure_deploy_key
  printf '\nAdd GitHub Actions secrets: ARSY_DEPLOY_HOST, ARSY_DEPLOY_USER,\nARSY_DEPLOY_SSH_KEY, and ARSY_DEPLOY_KNOWN_HOSTS. See docs/AUTO_DEPLOY.md.\n'
}

main() {
  require_root
  if [[ "${1:-}" == "--configure-deploy-key" ]]; then
    configure_deploy_key_mode
    exit 0
  fi
  [[ -f /etc/os-release ]] || die "/etc/os-release not found."
  install_docker
  command -v git >/dev/null 2>&1 || apt-get install -y git
  command -v curl >/dev/null 2>&1 || apt-get install -y curl
  command -v flock >/dev/null 2>&1 || apt-get install -y util-linux

  if [[ -d "$APP_DIR/.git" ]]; then
    log "Existing A-R-S-Y checkout found at $APP_DIR. Preserving local .env and data."
  elif [[ -e "$APP_DIR" && -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    die "$APP_DIR exists and is not an A-R-S-Y Git checkout. Move it or set ARSY_APP_DIR to a new path."
  else
    install -d -m 0755 "$(dirname "$APP_DIR")"
    git clone --branch main "$REPO_URL" "$APP_DIR"
  fi

  cd "$APP_DIR"
  [[ -f compose.yaml && -f .env.example && -f scripts/arsy-deploy.sh ]] || die "Repository is missing required bootstrap files."
  if [[ ! -f .env ]]; then
    local http_bind="${ARSY_HTTP_BIND:-127.0.0.1}"
    local http_port="${ARSY_HTTP_PORT:-18080}"
    local timezone="${TZ:-Asia/Jakarta}"
    [[ "$http_port" =~ ^[0-9]{1,5}$ ]] && (( http_port >= 1 && http_port <= 65535 )) || die "ARSY_HTTP_PORT must be between 1 and 65535."
    printf 'ARSY_HTTP_BIND=%s\nARSY_HTTP_PORT=%s\nTZ=%s\n' "$http_bind" "$http_port" "$timezone" > .env
    chmod 0600 .env
  else
    chmod 0600 .env
    log "Preserving existing .env. Review listener settings if the port is already in use."
  fi

  install -m 0755 scripts/arsy-deploy.sh /usr/local/sbin/arsy-deploy
  install -m 0755 scripts/arsy-deploy-gate.sh /usr/local/sbin/arsy-deploy-gate
  install -d -m 0750 /var/log/arsy /var/lib/arsy
  systemctl enable --now docker
  docker info >/dev/null 2>&1 || die "Docker daemon is not responding."
  if [[ -n "$PUBLIC_KEY" ]]; then configure_deploy_key; fi

  git fetch origin main --tags --prune
  local target_sha
  target_sha="$(git rev-parse refs/remotes/origin/main)"
  log "Deploying initial main commit $target_sha."
  /usr/local/sbin/arsy-deploy "$target_sha"

  local port
  port="$(sed -n 's/^ARSY_HTTP_PORT=//p' .env | tail -n1)"
  printf '\nA-R-S-Y Core Node bootstrap is installed.\n'
  printf '  App directory : %s\n  Local health  : http://127.0.0.1:%s/healthz\n' "$APP_DIR" "${port:-18080}"
  printf '  Local portal  : http://127.0.0.1:%s/\n' "${port:-18080}"
  printf '\nThe listener is loopback-only by default. Inspect through an SSH tunnel.\n'
  if [[ -z "$PUBLIC_KEY" ]]; then
    printf '\nAutomatic GitHub deployment is not enabled yet.\n'
    printf 'Run: sudo ARSY_DEPLOY_PUBLIC_KEY="ssh-ed25519 AAAA... comment" bash %s/install.sh --configure-deploy-key\n' "$APP_DIR"
  fi
}

main "$@"
