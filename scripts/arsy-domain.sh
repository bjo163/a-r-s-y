#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/arsy"
ENV_FILE="$APP_DIR/.env"
CADDY_FILE="/var/lib/arsy/Caddyfile"
COMPOSE_FILE="$APP_DIR/compose.yaml"
log(){ printf '\n[ARSY DOMAIN] %s\n' "$*"; }
die(){ printf '\n[ARSY DOMAIN][ERROR] %s\n' "$*" >&2; exit 1; }
[[ "$EUID" -eq 0 ]] || die "Run with sudo."
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
  log "Keep A-R-S-Y bound to 127.0.0.1:18080. Configure your proxy upstream to http://127.0.0.1:18080."
  cat <<EOF

Nginx example (TLS must terminate at your existing proxy):

server {
    listen 443 ssl;
    server_name $HOSTNAME;
    location / {
        proxy_pass http://127.0.0.1:18080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

Only after HTTPS is working at the proxy, run:
  sudo sed -i 's/^ARSY_COOKIE_SECURE=.*/ARSY_COOKIE_SECURE=true/' $ENV_FILE
  cd $APP_DIR && docker compose up -d app gateway
EOF
  exit 0
fi

command -v ss >/dev/null 2>&1 || die "The ss command is required (install iproute2 first). No host changes were made."
command -v curl >/dev/null 2>&1 || die "curl is required. No host changes were made."
command -v getent >/dev/null 2>&1 || die "getent is required. No host changes were made."
for port in 80 443; do
  if ss -ltn "( sport = :$port )" | grep -q LISTEN; then
    die "TCP port $port is already in use. Nothing changed. Use existing-proxy mode or free the port deliberately."
  fi
done
if [[ -z "$IPV4" ]]; then
  IPV4="$(curl -4fsS --max-time 8 https://api.ipify.org || true)"
fi
[[ "$IPV4" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "Could not determine public IPv4. Supply --ipv4 explicitly."
IFS=. read -r oct1 oct2 oct3 oct4 <<< "$IPV4"
for octet in "$oct1" "$oct2" "$oct3" "$oct4"; do
  (( 10#$octet <= 255 )) || die "Invalid IPv4 address: $IPV4"
done
if (( 10#$oct1 == 0 || 10#$oct1 == 10 || 10#$oct1 == 127 || 10#$oct1 >= 224 )) || \
   (( 10#$oct1 == 169 && 10#$oct2 == 254 )) || \
   (( 10#$oct1 == 172 && 10#$oct2 >= 16 && 10#$oct2 <= 31 )) || \
   (( 10#$oct1 == 192 && 10#$oct2 == 168 )) || \
   (( 10#$oct1 == 100 && 10#$oct2 >= 64 && 10#$oct2 <= 127 )); then
  die "The target must be a globally routable IPv4 address, not a private, link-local, loopback, shared, or reserved address."
fi
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

BACKUP="/var/lib/arsy/domain-backup-$(date +%Y%m%d%H%M%S)"
mkdir -m 0700 "$BACKUP"
cp -a "$ENV_FILE" "$CADDY_FILE" "$BACKUP/"
ROLLBACK_DONE=0
rollback(){
  [[ "$ROLLBACK_DONE" -eq 0 ]] || return 0
  ROLLBACK_DONE=1
  trap - ERR
  set +e
  cp -a "$BACKUP/.env" "$ENV_FILE"
  cp -a "$BACKUP/Caddyfile" "$CADDY_FILE"
  (cd "$APP_DIR" && docker compose up -d gateway app)
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
EOF
set_env ARSY_PUBLIC_HTTP_BIND "0.0.0.0"
set_env ARSY_PUBLIC_HTTP_PORT "80"
set_env ARSY_PUBLIC_HTTPS_BIND "0.0.0.0"
set_env ARSY_PUBLIC_HTTPS_PORT "443"
set_env ARSY_COOKIE_SECURE "true"
cd "$APP_DIR"
if ! docker compose config -q; then rollback; die "Compose validation failed. Previous config restored."; fi
if ! docker compose up -d app gateway; then
  rollback
  die "Could not recreate the app with secure-cookie settings and start the gateway. Previous configuration restored."
fi

# Resolve the hostname to loopback for the local check. This avoids depending
# on provider NAT loopback while preserving the real hostname for TLS/SNI.
healthy=0
for attempt in $(seq 1 90); do
  if curl --resolve "$HOSTNAME:443:127.0.0.1" -fsS --connect-timeout 2 --max-time 5 "https://$HOSTNAME/healthz" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ "$healthy" -ne 1 ]]; then
  rollback
  die "HTTPS health check failed after 180 seconds. Previous configuration restored. Check DNS, provider firewall (TCP 80/443), and Caddy logs."
fi
log "HTTPS endpoint is responding: https://$HOSTNAME"
log "Private recovery access remains available: ssh -L 18080:127.0.0.1:18080 USER@VPS, then open http://127.0.0.1:18080."
log "Backup of previous configuration: $BACKUP"
