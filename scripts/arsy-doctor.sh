#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/arsy"
PORT="18080"
if [[ -f "$APP_DIR/.env" ]]; then
  PORT="$(sed -n 's/^ARSY_HTTP_PORT=//p' "$APP_DIR/.env" | tail -n1 | tr -d '\r')"
  PORT="${PORT:-18080}"
fi

ok() { printf '  [OK]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
fail=0

printf '\nA-R-S-Y Core Node doctor\n\n'
if command -v docker >/dev/null 2>&1; then ok "Docker: $(docker --version)"; else warn "Docker CLI missing"; fail=1; fi
if docker compose version >/dev/null 2>&1; then ok "Compose: $(docker compose version --short)"; else warn "Compose v2 missing"; fail=1; fi
if docker info >/dev/null 2>&1; then ok "Docker daemon responding"; else warn "Docker daemon unavailable"; fail=1; fi
if [[ -f "$APP_DIR/.env" ]]; then ok "Environment file exists"; else warn "Missing $APP_DIR/.env"; fail=1; fi
if [[ -f /var/lib/arsy/deployed-sha ]]; then ok "Version: $(cut -c1-12 /var/lib/arsy/deployed-sha)"; else warn "No successful deployment recorded"; fail=1; fi
if curl -fsS --connect-timeout 2 --max-time 4 "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then ok "Web and database health check passed"; else warn "Local health check failed on port $PORT"; fail=1; fi
if [[ -d "$APP_DIR/.git" ]]; then ok "Repository checkout exists"; else warn "Repository checkout missing"; fail=1; fi
printf '\nDisk: '; df -h "$APP_DIR" 2>/dev/null | tail -n1 || true
printf 'Memory: '; free -h 2>/dev/null | awk '/^Mem:/ {print $3 " used / " $2 " total"}' || true
printf '\n'
exit "$fail"
