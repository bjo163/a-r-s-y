#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DOMAIN="$ROOT/scripts/arsy-domain.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }

make_case() {
  local name="$1" dir="$TMP/$name"
  mkdir -p "$dir/app" "$dir/state" "$dir/bin"
  printf 'ARSY_HTTP_PORT=18080\nARSY_PUBLIC_HTTP_BIND=127.0.0.1\nARSY_PUBLIC_HTTP_PORT=18081\nARSY_PUBLIC_HTTPS_BIND=127.0.0.1\nARSY_PUBLIC_HTTPS_PORT=18444\nARSY_COOKIE_SECURE=false\n' > "$dir/app/.env"
  printf 'PRIVATE-CADDY-CONFIG\n' > "$dir/state/Caddyfile"
  printf 'services: {}\n' > "$dir/app/compose.yaml"
  printf '{"status":"active","hostname":"old.example.com","verifiedAt":"2026-01-01T00:00:00Z"}\n' > "$dir/state/domain-state"
  cat > "$dir/bin/ss" <<'SH'
#!/usr/bin/env bash
[[ "${MOCK_PORT_BUSY:-0}" == "1" ]] && printf 'LISTEN\n'
SH
  cat > "$dir/bin/getent" <<'SH'
#!/usr/bin/env bash
case "$1" in
  ahostsv4)
    if [[ "${MOCK_A_MODE:-records}" == "empty" ]]; then exit 0; fi
    for ip in ${MOCK_A_RECORDS:-93.184.216.34}; do printf '%s STREAM %s\n' "$ip" "$2"; done
    ;;
  ahostsv6)
    for ip in ${MOCK_AAAA_RECORDS:-}; do printf '%s STREAM %s\n' "$ip" "$2"; done
    ;;
esac
SH
  cat > "$dir/bin/curl" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *--resolve*) [[ "${MOCK_TLS_FAIL:-0}" == "1" ]] && exit 28 || exit 0 ;;
  *) printf '93.184.216.34\n' ;;
esac
SH
  cat > "$dir/bin/docker" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_DOCKER_LOG"
if [[ "${MOCK_DOCKER_FAIL_CONFIG:-0}" == "1" && "$*" == *"config"* ]]; then exit 1; fi
if [[ "${MOCK_DOCKER_FAIL_FIRST_UP:-0}" == "1" && "$*" == *"up -d app gateway"* && ! -f "$MOCK_DOCKER_COUNTER" ]]; then
  touch "$MOCK_DOCKER_COUNTER"
  exit 1
fi
exit 0
SH
  cat > "$dir/bin/sleep" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$dir/bin/"*
}

run_domain() {
  local dir="$1" extra="${2:-}" input="${3:-y}"
  env PATH="$dir/bin:$PATH" \
    ARSY_TEST_MODE=1 ARSY_APP_DIR="$dir/app" ARSY_STATE_DIR="$dir/state" \
    ARSY_ENV_FILE="$dir/app/.env" ARSY_CADDY_FILE="$dir/state/Caddyfile" \
    ARSY_DOMAIN_STATE_FILE="$dir/state/domain-state" \
    ARSY_DOMAIN_HEALTH_ATTEMPTS=2 ARSY_DOMAIN_HEALTH_INTERVAL=0 \
    MOCK_DOCKER_LOG="$dir/docker.log" MOCK_DOCKER_COUNTER="$dir/docker.counter" \
    $extra bash "$DOMAIN" apply --hostname panel.example.com --ipv4 93.184.216.34 <<< "$input"
}

for case_name in invalid-host invalid-ip private-ip busy missing-a mismatch aaaa missing-command; do
  make_case "$case_name"
  dir="$TMP/$case_name"
  cp "$dir/app/.env" "$dir/env.before"
  cp "$dir/state/Caddyfile" "$dir/caddy.before"
  cp "$dir/state/domain-state" "$dir/domain.before"
  extra=""
  case "$case_name" in
    invalid-host) cmd=(bash "$DOMAIN" apply --hostname bad --ipv4 93.184.216.34) ;;
    invalid-ip) cmd=(bash "$DOMAIN" apply --hostname panel.example.com --ipv4 999.1.1.1) ;;
    private-ip) cmd=(bash "$DOMAIN" apply --hostname panel.example.com --ipv4 10.0.0.1) ;;
    busy) extra="MOCK_PORT_BUSY=1"; cmd=(bash "$DOMAIN" apply --hostname panel.example.com --ipv4 93.184.216.34) ;;
    missing-a) extra="MOCK_A_MODE=empty"; cmd=(bash "$DOMAIN" apply --hostname panel.example.com --ipv4 93.184.216.34) ;;
    mismatch) extra="MOCK_A_RECORDS=203.0.114.2"; cmd=(bash "$DOMAIN" apply --hostname panel.example.com --ipv4 93.184.216.34) ;;
    aaaa) extra="MOCK_AAAA_RECORDS=2001:db8::1"; cmd=(bash "$DOMAIN" apply --hostname panel.example.com --ipv4 93.184.216.34) ;;
    missing-command) extra="ARSY_TEST_MISSING_COMMAND=ss"; cmd=(bash "$DOMAIN" apply --hostname panel.example.com --ipv4 93.184.216.34) ;;
  esac
  if env PATH="$dir/bin:$PATH" ARSY_TEST_MODE=1 ARSY_APP_DIR="$dir/app" ARSY_STATE_DIR="$dir/state" ARSY_ENV_FILE="$dir/app/.env" ARSY_CADDY_FILE="$dir/state/Caddyfile" ARSY_DOMAIN_STATE_FILE="$dir/state/domain-state" $extra "${cmd[@]}" >/dev/null 2>&1; then fail "$case_name should fail"; fi
  cmp -s "$dir/app/.env" "$dir/env.before" || fail "$case_name modified .env"
  cmp -s "$dir/state/Caddyfile" "$dir/caddy.before" || fail "$case_name modified Caddyfile"
  cmp -s "$dir/state/domain-state" "$dir/domain.before" || fail "$case_name modified domain-state"
done

for failure in compose-config compose-up tls; do
  make_case "$failure"
  dir="$TMP/$failure"
  cp "$dir/app/.env" "$dir/env.before"
  cp "$dir/state/Caddyfile" "$dir/caddy.before"
  cp "$dir/state/domain-state" "$dir/domain.before"
  extra=""
  case "$failure" in
    compose-config) extra="MOCK_DOCKER_FAIL_CONFIG=1" ;;
    compose-up) extra="MOCK_DOCKER_FAIL_FIRST_UP=1" ;;
    tls) extra="MOCK_TLS_FAIL=1" ;;
  esac
  if run_domain "$dir" "$extra" >/dev/null 2>&1; then fail "$failure should fail"; fi
  cmp -s "$dir/app/.env" "$dir/env.before" || fail "$failure did not restore .env"
  cmp -s "$dir/state/Caddyfile" "$dir/caddy.before" || fail "$failure did not restore Caddyfile"
  cmp -s "$dir/state/domain-state" "$dir/domain.before" || fail "$failure did not restore domain-state"
done

make_case success
dir="$TMP/success"
run_domain "$dir" >/dev/null
grep -q '^ARSY_HTTP_PORT=18080$' "$dir/app/.env" || fail "private recovery port changed"
grep -q '^ARSY_PUBLIC_HTTP_BIND=0.0.0.0$' "$dir/app/.env" || fail "public HTTP bind not enabled"
grep -q '^ARSY_PUBLIC_HTTPS_BIND=0.0.0.0$' "$dir/app/.env" || fail "public HTTPS bind not enabled"
grep -q '^ARSY_COOKIE_SECURE=true$' "$dir/app/.env" || fail "Secure cookie flag not enabled"
grep -q '"status":"active"' "$dir/state/domain-state" || fail "success marker missing"
grep -q 'trusted_proxies static private_ranges' "$dir/state/Caddyfile" || fail "trusted proxy policy missing"
printf '[PASS] domain validation, private recovery, rollback and managed activation matrix.\n'
