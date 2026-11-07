#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REMOTE="$TMP/origin.git"
TARGET_SHA="$(git -C "$ROOT" rev-parse HEAD)"
git init --bare "$REMOTE" >/dev/null
git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main
git -C "$ROOT" push "$REMOTE" "$TARGET_SHA:refs/heads/main" >/dev/null 2>&1
OLD_SHA="$(git -C "$ROOT" rev-parse "${TARGET_SHA}^")"

fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
make_case(){
  local name="$1" dir="$TMP/$name"
  mkdir -p "$dir/state" "$dir/log" "$dir/hostbin" "$dir/lock" "$dir/bin"
  git clone "$REMOTE" "$dir/app" >/dev/null 2>&1
  git -C "$dir/app" checkout --detach "$OLD_SHA" >/dev/null 2>&1
  cat > "$dir/app/.env" <<'ENV'
ARSY_ENV_LAYOUT_VERSION=2
ARSY_HTTP_PORT=18080
ARSY_PUBLIC_HTTP_BIND=127.0.0.1
ARSY_PUBLIC_HTTP_PORT=18081
ARSY_PUBLIC_HTTPS_BIND=127.0.0.1
ARSY_PUBLIC_HTTPS_PORT=18444
ARSY_PROXY_HTTP_PORT=18082
POSTGRES_DB=arsy
POSTGRES_USER=arsy
POSTGRES_PASSWORD=preserve-this-db-password
ARSY_SETUP_TOKEN=preserve-this-bootstrap-token
ARSY_SESSION_SECRET=preserve-this-session-secret
ARSY_COOKIE_SECURE=false
TZ=Asia/Jakarta
ENV
  chmod 0600 "$dir/app/.env"
  cp "$dir/app/Caddyfile" "$dir/state/Caddyfile"
  printf '%s\n' "$OLD_SHA" > "$dir/state/deployed-sha"
  cat > "$dir/bin/docker" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_DOCKER_LOG"
case "$*" in
  *"config --services"*) printf 'app\ndb\ngateway\n' ;;
  *"config --quiet"*) [[ "${MOCK_FAIL_CONFIG:-0}" == "1" ]] && exit 1 ;;
  *"up -d --remove-orphans"*)
    if [[ "${MOCK_FAIL_FIRST_UP:-0}" == "1" && ! -f "$MOCK_UP_MARKER" ]]; then
      touch "$MOCK_UP_MARKER"; exit 1
    fi
    ;;
  *"pull "*|*"build --pull app"*|*"down --remove-orphans"*|*" ps"*) ;;
  *) ;;
esac
exit 0
SH
  cat > "$dir/bin/curl" <<'SH'
#!/usr/bin/env bash
if [[ "${MOCK_FAIL_HEALTH_ONCE:-0}" == "1" && ! -f "$MOCK_HEALTH_MARKER" ]]; then
  touch "$MOCK_HEALTH_MARKER"; exit 28
fi
if [[ "${MOCK_FAIL_HEALTH_ALWAYS:-0}" == "1" ]]; then exit 28; fi
exit 0
SH
  chmod +x "$dir/bin/docker" "$dir/bin/curl"
}

run_deploy(){
  local dir="$1" extra="${2:-}"
  env PATH="$dir/bin:$PATH" ARSY_TEST_MODE=1 \
    ARSY_APP_DIR="$dir/app" ARSY_STATE_DIR="$dir/state" ARSY_LOG_DIR="$dir/log" \
    ARSY_DEPLOY_LOCK_FILE="$dir/lock/deploy.lock" ARSY_HOST_BIN_DIR="$dir/hostbin" \
    MOCK_DOCKER_LOG="$dir/docker.log" MOCK_UP_MARKER="$dir/up.marker" \
    MOCK_HEALTH_MARKER="$dir/health.marker" \
    ARSY_DEPLOY_HEALTH_ATTEMPTS=1 ARSY_DEPLOY_HEALTH_INTERVAL=0 $extra \
    bash "$ROOT/scripts/arsy-deploy.sh" "$TARGET_SHA"
}

make_case success
dir="$TMP/success"
cp "$dir/app/.env" "$dir/env.before"
cp "$dir/state/Caddyfile" "$dir/caddy.before"
run_deploy "$dir" > "$dir/output.log" 2>&1 || fail "successful update unexpectedly failed"
[[ "$(cat "$dir/state/deployed-sha")" == "$TARGET_SHA" ]] || fail "successful deploy SHA not recorded"
cmp -s "$dir/app/.env" "$dir/env.before" || fail ".env changed on successful update"
cmp -s "$dir/state/Caddyfile" "$dir/caddy.before" || fail "runtime Caddyfile changed on successful update"
grep -q 'SUCCESS:' "$dir/output.log" || fail "success log marker missing"

make_case compose-failure
dir="$TMP/compose-failure"
cp "$dir/app/.env" "$dir/env.before"
cp "$dir/state/Caddyfile" "$dir/caddy.before"
if run_deploy "$dir" "MOCK_FAIL_FIRST_UP=1" > "$dir/output.log" 2>&1; then fail "Compose failure should fail the deploy command"; fi
[[ "$(git -C "$dir/app" rev-parse HEAD)" == "$OLD_SHA" ]] || fail "source revision was not rolled back"
[[ "$(cat "$dir/state/deployed-sha")" == "$OLD_SHA" ]] || fail "deployed SHA changed after failed update"
cmp -s "$dir/app/.env" "$dir/env.before" || fail ".env changed after rollback"
cmp -s "$dir/state/Caddyfile" "$dir/caddy.before" || fail "runtime Caddyfile changed after rollback"
grep -q 'Previous stack restored and health-checked' "$dir/output.log" || fail "rollback health evidence missing"
if grep -q 'down .*-[vV]' "$dir/docker.log"; then fail "persistent volumes must never be removed"; fi

make_case legacy-migration-rollback
dir="$TMP/legacy-migration-rollback"
cat > "$dir/app/.env" <<'ENV'
ARSY_HTTP_BIND=0.0.0.0
ARSY_HTTP_PORT=80
ARSY_HTTPS_BIND=0.0.0.0
ARSY_HTTPS_PORT=443
POSTGRES_DB=arsy
POSTGRES_USER=arsy
POSTGRES_PASSWORD=preserve-this-db-password
ARSY_SETUP_TOKEN=preserve-this-bootstrap-token
ARSY_SESSION_SECRET=preserve-this-session-secret
ARSY_COOKIE_SECURE=false
TZ=Asia/Jakarta
ENV
chmod 0600 "$dir/app/.env"
cp "$dir/app/.env" "$dir/env.before"
cp "$dir/state/Caddyfile" "$dir/caddy.before"
if run_deploy "$dir" "MOCK_FAIL_FIRST_UP=1" > "$dir/output.log" 2>&1; then fail "legacy Compose failure should fail the deployment"; fi
cmp -s "$dir/app/.env" "$dir/env.before" || fail "legacy .env migration was not fully rolled back"
cmp -s "$dir/state/Caddyfile" "$dir/caddy.before" || fail "legacy rollback changed runtime Caddyfile"
[[ "$(cat "$dir/state/deployed-sha")" == "$OLD_SHA" ]] || fail "legacy rollback changed deployed SHA"
grep -q 'Original .env restored' "$dir/output.log" || fail "legacy environment rollback was not logged"

make_case health-failure
dir="$TMP/health-failure"
if run_deploy "$dir" "MOCK_FAIL_HEALTH_ONCE=1" > "$dir/output.log" 2>&1; then fail "first health check failure should fail the deployment"; fi
[[ "$(git -C "$dir/app" rev-parse HEAD)" == "$OLD_SHA" ]] || fail "health failure did not restore old source"
[[ "$(cat "$dir/state/deployed-sha")" == "$OLD_SHA" ]] || fail "deployed SHA changed after failed health check"
grep -q 'Previous stack restored and health-checked' "$dir/output.log" || fail "health-check rollback not recorded"

make_case repair
dir="$TMP/repair"
git -C "$dir/app" checkout --detach "$TARGET_SHA" >/dev/null 2>&1
printf '%s\n' "$TARGET_SHA" > "$dir/state/deployed-sha"
cp "$dir/app/.env" "$dir/env.before"
cp "$dir/state/Caddyfile" "$dir/caddy.before"
run_deploy "$dir" > "$dir/output.log" 2>&1 || fail "repair/redeploy failed"
cmp -s "$dir/app/.env" "$dir/env.before" || fail ".env changed during repair"
cmp -s "$dir/state/Caddyfile" "$dir/caddy.before" || fail "runtime Caddyfile changed during repair"
if grep -q 'down .*-[vV]' "$dir/docker.log"; then fail "repair must not remove persistent volumes"; fi

printf '[PASS] deploy update, compose rollback, health rollback, repair and persistent-config preservation.\n'
