#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/scripts/arsy-config-validate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
write_valid() {
cat > "$1" <<'ENV'
ARSY_ENV_LAYOUT_VERSION=2
ARSY_HTTP_PORT=18080
ARSY_PUBLIC_HTTP_BIND=127.0.0.1
ARSY_PUBLIC_HTTP_PORT=18081
ARSY_PUBLIC_HTTPS_BIND=127.0.0.1
ARSY_PUBLIC_HTTPS_PORT=18444
ARSY_PROXY_HTTP_PORT=18082
POSTGRES_DB=arsy
POSTGRES_USER=arsy
POSTGRES_PASSWORD=existing-database-password
ARSY_SETUP_TOKEN=existing-bootstrap-token
ARSY_SESSION_SECRET=existing-session-secret
ARSY_COOKIE_SECURE=false
ENV
}
expect_fail() { if bash "$VALIDATOR" "$2" >/dev/null 2>&1; then fail "$1 should have been rejected"; fi; }
valid="$TMP/valid.env"; write_valid "$valid"; bash "$VALIDATOR" "$valid" >/dev/null
empty="$TMP/empty.env"; write_valid "$empty"; sed -i 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=/' "$empty"; expect_fail "empty secret" "$empty"
duplicate="$TMP/duplicate.env"; write_valid "$duplicate"; printf 'ARSY_SESSION_SECRET=duplicate\n' >> "$duplicate"; expect_fail "duplicate key" "$duplicate"
bad_port="$TMP/bad-port.env"; write_valid "$bad_port"; sed -i 's/^ARSY_PUBLIC_HTTP_PORT=.*/ARSY_PUBLIC_HTTP_PORT=70000/' "$bad_port"; expect_fail "invalid port" "$bad_port"
bad_bind="$TMP/bad-bind.env"; write_valid "$bad_bind"; sed -i 's/^ARSY_PUBLIC_HTTP_BIND=.*/ARSY_PUBLIC_HTTP_BIND=192.0.2.10/' "$bad_bind"; expect_fail "invalid bind" "$bad_bind"
duplicate_port="$TMP/duplicate-port.env"; write_valid "$duplicate_port"; sed -i 's/^ARSY_PROXY_HTTP_PORT=.*/ARSY_PROXY_HTTP_PORT=18080/' "$duplicate_port"; expect_fail "duplicate port" "$duplicate_port"
bad_db="$TMP/bad-db.env"; write_valid "$bad_db"; sed -i 's/^POSTGRES_DB=.*/POSTGRES_DB=arsy;drop/' "$bad_db"; expect_fail "unsafe DB identifier" "$bad_db"
printf '[PASS] config validator rejects empty/duplicate keys, invalid ports/binds and unsafe database identifiers.\n'
