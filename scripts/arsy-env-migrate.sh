#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="${1:-/opt/arsy/.env}"
ENV_DIR="$(dirname -- "$ENV_FILE")"
log(){ printf '[ARSY-ENV] %s\n' "$*"; }
die(){ printf '[ARSY-ENV][ERROR] %s\n' "$*" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || die "Environment file not found: $ENV_FILE"
chmod 0600 "$ENV_FILE"

get_env() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); value=$0; found=1 } END { if (found) print value }' "$ENV_FILE"
}
has_env() { grep -qE "^$1=" "$ENV_FILE"; }
valid_port() {
  [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}
set_env() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp "$ENV_DIR/.arsy-env.XXXXXX")"
  awk -v key="$key" -v value="$value" '
    BEGIN { FS="="; found=0 }
    $1 == key { print key "=" value; found=1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "$ENV_FILE" > "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$ENV_FILE"
}

[[ "$(get_env ARSY_ENV_LAYOUT_VERSION || true)" == "2" ]] && exit 0

legacy_http_port="$(get_env ARSY_HTTP_PORT || true)"
legacy_https_port="$(get_env ARSY_HTTPS_PORT || true)"
legacy_http_bind="$(get_env ARSY_HTTP_BIND || true)"
legacy_https_bind="$(get_env ARSY_HTTPS_BIND || true)"
modern_layout=0
for key in ARSY_PUBLIC_HTTP_BIND ARSY_PUBLIC_HTTP_PORT ARSY_PUBLIC_HTTPS_BIND ARSY_PUBLIC_HTTPS_PORT; do
  if has_env "$key"; then modern_layout=1; fi
done

if (( modern_layout == 0 )); then
  public_http_port="18081"
  if [[ -n "$legacy_http_port" && "$legacy_http_port" != "18080" ]]; then
    if valid_port "$legacy_http_port"; then
      public_http_port="$legacy_http_port"
    else
      log "Legacy HTTP port '$legacy_http_port' is invalid; using 18081."
    fi
  fi
  public_https_port="18444"
  if [[ -n "$legacy_https_port" ]]; then
    if valid_port "$legacy_https_port"; then
      public_https_port="$legacy_https_port"
    else
      log "Legacy HTTPS port '$legacy_https_port' is invalid; using 18444."
    fi
  fi
  set_env ARSY_HTTP_PORT "18080"
  set_env ARSY_PUBLIC_HTTP_PORT "$public_http_port"
  set_env ARSY_PUBLIC_HTTPS_PORT "$public_https_port"
  set_env ARSY_PUBLIC_HTTP_BIND "127.0.0.1"
  set_env ARSY_PUBLIC_HTTPS_BIND "127.0.0.1"
else
  [[ -n "$(get_env ARSY_HTTP_PORT || true)" ]] || set_env ARSY_HTTP_PORT "18080"
  [[ -n "$(get_env ARSY_PUBLIC_HTTP_PORT || true)" ]] || set_env ARSY_PUBLIC_HTTP_PORT "18081"
  [[ -n "$(get_env ARSY_PUBLIC_HTTPS_PORT || true)" ]] || set_env ARSY_PUBLIC_HTTPS_PORT "18444"
  [[ -n "$(get_env ARSY_PUBLIC_HTTP_BIND || true)" ]] || set_env ARSY_PUBLIC_HTTP_BIND "127.0.0.1"
  [[ -n "$(get_env ARSY_PUBLIC_HTTPS_BIND || true)" ]] || set_env ARSY_PUBLIC_HTTPS_BIND "127.0.0.1"
fi

set_env ARSY_ENV_LAYOUT_VERSION "2"
if [[ "$legacy_http_bind" == "0.0.0.0" || "$legacy_https_bind" == "0.0.0.0" ]]; then
  log "Legacy wildcard bind detected. Public exposure was NOT migrated; new public binds remain loopback."
fi
log "Environment layout migrated. Private recovery listener: 127.0.0.1:$(get_env ARSY_HTTP_PORT)."
