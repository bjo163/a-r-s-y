#!/usr/bin/env bash
set -Eeuo pipefail
ENV_FILE="${1:-/opt/arsy/.env}"
log(){ printf '[ARSY-CONFIG] %s\n' "$*"; }
die(){ log "ERROR: $*" >&2; exit 1; }
[[ -f "$ENV_FILE" && -r "$ENV_FILE" ]] || die "Environment file is missing or unreadable: $ENV_FILE"
read_value() {
  local key="$1" value
  if ! value="$(awk -F= -v key="$key" '$1 == key { count++; value=substr($0,index($0,"=")+1) } END { if (count != 1) exit 1; print value }' "$ENV_FILE")"; then
    die "$key must appear exactly once in $ENV_FILE."
  fi
  [[ -n "$value" ]] || die "$key must not be empty."
  printf '%s' "$value"
}
valid_port() { [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 )); }
declare -A values
keys=(ARSY_ENV_LAYOUT_VERSION ARSY_HTTP_PORT ARSY_PUBLIC_HTTP_BIND ARSY_PUBLIC_HTTP_PORT ARSY_PUBLIC_HTTPS_BIND ARSY_PUBLIC_HTTPS_PORT ARSY_PROXY_HTTP_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD ARSY_SETUP_TOKEN ARSY_SESSION_SECRET ARSY_COOKIE_SECURE)
for key in "${keys[@]}"; do values["$key"]="$(read_value "$key")"; done
for key in POSTGRES_PASSWORD ARSY_SETUP_TOKEN ARSY_SESSION_SECRET; do
  [[ "${values[$key]}" != CHANGE-ME-* ]] || die "$key still contains a template placeholder; generate a unique secret before deployment."
done
[[ "${values[ARSY_ENV_LAYOUT_VERSION]}" == "2" ]] || die "Unsupported environment layout; expected version 2."
[[ "${values[POSTGRES_DB]}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "POSTGRES_DB must be a simple PostgreSQL identifier."
[[ "${values[POSTGRES_USER]}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "POSTGRES_USER must be a simple PostgreSQL identifier."
[[ "${values[ARSY_COOKIE_SECURE]}" == "true" || "${values[ARSY_COOKIE_SECURE]}" == "false" ]] || die "ARSY_COOKIE_SECURE must be true or false."
for key in ARSY_HTTP_PORT ARSY_PUBLIC_HTTP_PORT ARSY_PUBLIC_HTTPS_PORT ARSY_PROXY_HTTP_PORT; do
  valid_port "${values[$key]}" || die "$key must be an integer from 1 to 65535."
done
[[ "${values[ARSY_PUBLIC_HTTP_BIND]}" == "127.0.0.1" || "${values[ARSY_PUBLIC_HTTP_BIND]}" == "0.0.0.0" ]] || die "ARSY_PUBLIC_HTTP_BIND must be 127.0.0.1 or 0.0.0.0."
[[ "${values[ARSY_PUBLIC_HTTPS_BIND]}" == "127.0.0.1" || "${values[ARSY_PUBLIC_HTTPS_BIND]}" == "0.0.0.0" ]] || die "ARSY_PUBLIC_HTTPS_BIND must be 127.0.0.1 or 0.0.0.0."
ports=("${values[ARSY_HTTP_PORT]}" "${values[ARSY_PUBLIC_HTTP_PORT]}" "${values[ARSY_PUBLIC_HTTPS_PORT]}" "${values[ARSY_PROXY_HTTP_PORT]}")
for ((i=0; i<${#ports[@]}; i++)); do
  for ((j=i+1; j<${#ports[@]}; j++)); do
    [[ "${ports[$i]}" != "${ports[$j]}" ]] || die "Host listener ports must be unique; duplicate port ${ports[$i]}."
  done
done
log "Environment structure, required values, listener binds and ports are valid."
