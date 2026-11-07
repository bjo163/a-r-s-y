#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATOR="$ROOT/scripts/arsy-env-migrate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
assert_value(){
  local file="$1" key="$2" expected="$3" actual
  actual="$(awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,"");v=$0} END{print v}' "$file")"
  [[ "$actual" == "$expected" ]] || fail "$key expected '$expected', got '$actual'"
}

legacy="$TMP/legacy.env"
cat > "$legacy" <<'ENV'
POSTGRES_PASSWORD=preserve-this-value
ARSY_HTTP_BIND=0.0.0.0
ARSY_HTTP_PORT=80
ARSY_HTTPS_BIND=0.0.0.0
ARSY_HTTPS_PORT=443
ENV
bash "$MIGRATOR" "$legacy" >/dev/null
assert_value "$legacy" POSTGRES_PASSWORD "preserve-this-value"
assert_value "$legacy" ARSY_HTTP_PORT "18080"
assert_value "$legacy" ARSY_PUBLIC_HTTP_PORT "80"
assert_value "$legacy" ARSY_PUBLIC_HTTPS_PORT "443"
assert_value "$legacy" ARSY_PUBLIC_HTTP_BIND "127.0.0.1"
assert_value "$legacy" ARSY_PUBLIC_HTTPS_BIND "127.0.0.1"
assert_value "$legacy" ARSY_ENV_LAYOUT_VERSION "2"
[[ "$(stat -c '%a' "$legacy")" == "600" ]] || fail ".env mode must remain 0600"
bash "$MIGRATOR" "$legacy" >/dev/null
assert_value "$legacy" ARSY_PUBLIC_HTTP_BIND "127.0.0.1"

custom="$TMP/custom.env"
cat > "$custom" <<'ENV'
ARSY_HTTP_PORT=18080
ARSY_PUBLIC_HTTP_BIND=127.0.0.1
ARSY_PUBLIC_HTTP_PORT=18090
ARSY_PUBLIC_HTTPS_BIND=127.0.0.1
ARSY_PUBLIC_HTTPS_PORT=18490
ARSY_SESSION_SECRET=keep-me
ENV
bash "$MIGRATOR" "$custom" >/dev/null
assert_value "$custom" ARSY_HTTP_PORT "18080"
assert_value "$custom" ARSY_PUBLIC_HTTP_PORT "18090"
assert_value "$custom" ARSY_PUBLIC_HTTPS_PORT "18490"
assert_value "$custom" ARSY_SESSION_SECRET "keep-me"
printf '[PASS] .env migration preserves secrets and keeps public binds loopback.\n'
