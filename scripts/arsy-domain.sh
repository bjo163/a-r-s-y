#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_MODE="${ARSY_TEST_MODE:-0}"
APP_DIR="${ARSY_APP_DIR:-/opt/arsy}"
STATE_DIR="${ARSY_STATE_DIR:-/var/lib/arsy}"
ENV_FILE="${ARSY_ENV_FILE:-$APP_DIR/.env}"
CADDY_FILE="${ARSY_CADDY_FILE:-$STATE_DIR/Caddyfile}"
DOMAIN_STATE_FILE="${ARSY_DOMAIN_STATE_FILE:-$STATE_DIR/domain-state}"
COMPOSE_FILE="${ARSY_COMPOSE_FILE:-$APP_DIR/compose.yaml}"
HEALTH_ATTEMPTS="${ARSY_DOMAIN_HEALTH_ATTEMPTS:-90}"
HEALTH_INTERVAL="${ARSY_DOMAIN_HEALTH_INTERVAL:-2}"
source "$SCRIPT_DIR/arsy-network.sh"
log(){ printf '\\n[ARSY DOMAIN] %s\\n' "$*"; }
die(){ printf '\\n[ARSY DOMAIN][ERROR] %s\\n' "$*" >&2; exit 1; }
if [[ "$TEST_MODE" == "1" ]]; then
  [[ "$APP_DIR" != "/opt/arsy" && "$STATE_DIR" != "/var/lib/arsy" ]] || die "Test mode requires isolated temporary app/state directories."
else
  [[ "$EUID" -eq 0 ]] || die "Run with sudo."
fi
[[ -f "$ENV_FILE" && -f "$COMPOSE_FILE" ]] || die "A-R-S-Y installation not found at $APP_DIR."
MODE="${1:-}"
[[ "$MODE" == "apply" || "$MODE" == "proxy" ]] || die "Usage: arsy-domain apply --hostname panel.example.com [--ipv4 1.2.3.4] | proxy --hostname panel.example.com"
shift
HOSTNAME=""
IPV4=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname) HOSTNAME="${2:-}"; shift 2 ;;
    --ipv4) IPV4="${2:-}"; shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
[[ "$HOSTNAME" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ ]] || die "Provide a valid hostname, e.g. panel.example.com."
HOSTNAME="${HOSTNAME,,}"

set_env(){
  local key="$1" value="$2" tmp
  tmp="$(mktemp "$APP_DIR/.env.XXXXXX")"
  if grep -q "^$key=" "$ENV_FILE"; then
    sed "s|^$key=.*|$key=$value|" "$ENV_FILE" > "$tmp"
  else
    cat "$ENV_FILE" > "$tmp"; printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi
  chmod 0600 "$tmp"; mv -f "$tmp" "$ENV_FILE"; chmod 0600 "$ENV_FILE"
}
if [[ "$MODE" == "proxy" ]]; then
  log "Existing reverse proxy mode selected."
  log "Keep SSH recovery on 127.0.0.1:18080. Configure the same-host TLS proxy upstream to http://127.0.0.1:18082."
  cat <<EOF

Nginx example (TLS must terminate at your existing proxy):

server {
    listen 443 ssl;
    server_name $HOSTNAME;
    location / {
        proxy_pass http://127.0.0.1:18082;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
    }
}

Only after HTTPS is working at the proxy, run:
  sudo sed -i 's/^ARSY_COOKIE_SECURE=.*/ARSY_COOKIE_SECURE=true/' $ENV_FILE
  cd $APP_DIR && docker compose up -d app gateway
EOF
  exit 0
fi

require_command() {
  local name="$1"
  if [[ "$TEST_MODE" == "1" && "${ARSY_TEST_MISSING_COMMAND:-}" == "$name" ]]; then
    die "Required command '$name' is unavailable (simulated test). No host changes were made."
  fi
  command -v "$name" >/dev/null 2>&1 || die "The $name command is required. No host changes were made."
}
require_command ss
require_command curl
require_command getent
for port in 80 443; do
  if ss -ltn "( sport = :$port )" | grep -q LISTEN; then
    die "TCP port $port is already in use. Nothing changed. Use existing-proxy mode or free the port deliberately."
  fi
done
if [[ -z "$IPV4" ]]; then
  IPV4="$(curl -4fsS --max-time 8 https://api.ipify.org || true)"
fi
arsy_is_global_ipv4 "$IPV4" || die "Target must be a valid globally routable IPv4 address. Private, shared, documentation, benchmarking, multicast, and reserved ranges are rejected."
DNS_IPS="$(getent ahostsv4 "$HOSTNAME" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' || true)"
[[ -n "$DNS_IPS" ]] || die "No public A record found for $HOSTNAME. Create A $HOSTNAME -> $IPV4 and retry."
grep -qw "$IPV4" <<< "$DNS_IPS" || die "DNS A record ($DNS_IPS) does not include expected VPS IPv4 ($IPV4). Nothing changed."
DNS_IPV6="$(getent ahostsv6 "$HOSTNAME" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' || true)"
[[ -z "$DNS_IPV6" ]] || die "AAAA record(s) detected ($DNS_IPV6), but this single-VPS gateway currently binds IPv4 only. Remove the AAAA record or wait for explicit IPv6 support before applying."
log "Domain: $HOSTNAME"
log "DNS A record: $DNS_IPS"
log "Target IPv4: $IPV4"
log "This will bind public TCP 80/443, configure Caddy automatic HTTPS, and enable Secure cookies."
log "Private recovery access on 127.0.0.1:18080 will remain available through SSH tunnel."
log "Your provider firewall/security group must allow inbound TCP 80 and 443."
read -r -p "Apply these changes now? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || die "Cancelled. No changes made."

install -d -m 0755 "$STATE_DIR"
BACKUP="$STATE_DIR/domain-backup-$(date +%Y%m%d%H%M%S)"
mkdir -m 0700 "$BACKUP"
cp -a "$ENV_FILE" "$CADDY_FILE" "$BACKUP/"
if [[ -f "$DOMAIN_STATE_FILE" ]]; then cp -a "$DOMAIN_STATE_FILE" "$BACKUP/domain-state"; fi
ROLLBACK_DONE=0
rollback(){
  [[ "$ROLLBACK_DONE" -eq 0 ]] || return 0
  ROLLBACK_DONE=1
  trap - ERR
  set +e
  cp -a "$BACKUP/.env" "$ENV_FILE"
  cp -a "$BACKUP/Caddyfile" "$CADDY_FILE"
  if [[ -f "$BACKUP/domain-state" ]]; then
    install -m 0644 "$BACKUP/domain-state" "$DOMAIN_STATE_FILE"
  else
    rm -f "$DOMAIN_STATE_FILE"
  fi
  (cd "$APP_DIR" && compose up -d gateway app)
  local result=$?
  if [[ "$result" -eq 0 ]]; then
    log "Previous private/domain configuration restored."
  else
    log "CRITICAL: automatic rollback could not fully restore the stack. Keep the backup at $BACKUP and inspect Docker Compose logs."
  fi
  return "$result"
}
on_error(){
  local status="$1" line="$2" command="$3"
  trap - ERR
  if [[ "$ROLLBACK_DONE" -eq 0 ]]; then
    log "Unexpected failure at line $line while running: $command"
    rollback || true
  fi
  exit "$status"
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
cat > "$CADDY_FILE" <<EOF
$HOSTNAME {
    encode zstd gzip
    reverse_proxy app:3000
}

:8080 {
    reverse_proxy app:3000
}

:8081 {
    reverse_proxy app:3000 {
        header_up X-Forwarded-For {http.request.header.X-Forwarded-For}
        header_up X-Forwarded-Proto {http.request.header.X-Forwarded-Proto}
        header_up X-Forwarded-Host {http.request.header.X-Forwarded-Host}
    }
}
EOF
set_env ARSY_PUBLIC_HTTP_BIND "0.0.0.0"
set_env ARSY_PUBLIC_HTTP_PORT "80"
set_env ARSY_PUBLIC_HTTPS_BIND "0.0.0.0"
set_env ARSY_PUBLIC_HTTPS_PORT "443"
set_env ARSY_COOKIE_SECURE "true"
cd "$APP_DIR"
compose() { docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"; }
if ! compose config -q; then rollback; die "Compose validation failed. Previous config restored."; fi
if ! compose up -d app gateway; then
  rollback
  die "Could not recreate the app with secure-cookie settings and start the gateway. Previous configuration restored."
fi

# Resolve the hostname to loopback for the local check. This avoids depending
# on provider NAT loopback while preserving the real hostname for TLS/SNI.
healthy=0
for attempt in $(seq 1 "$HEALTH_ATTEMPTS"); do
  if curl --resolve "$HOSTNAME:443:127.0.0.1" -fsS --connect-timeout 2 --max-time 5 "https://$HOSTNAME/healthz" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep "$HEALTH_INTERVAL"
done
if [[ "$healthy" -ne 1 ]]; then
  rollback
  die "HTTPS health check failed after 180 seconds. Previous configuration restored. Check DNS, provider firewall (TCP 80/443), and Caddy logs."
fi
DOMAIN_STATE_TMP="$(mktemp "$STATE_DIR/domain-state.XXXXXX")"
printf '{"status":"active","hostname":"%s","verifiedAt":"%s"}\n' "$HOSTNAME" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DOMAIN_STATE_TMP"
chmod 0644 "$DOMAIN_STATE_TMP"
mv -f "$DOMAIN_STATE_TMP" "$DOMAIN_STATE_FILE"
log "HTTPS endpoint is responding: https://$HOSTNAME"
log "Private recovery access remains available: ssh -L 18080:127.0.0.1:18080 USER@VPS, then open http://127.0.0.1:18080."
log "Backup of previous configuration: $BACKUP"
