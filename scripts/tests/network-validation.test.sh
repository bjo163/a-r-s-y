#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/arsy-network.sh"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
for ip in 1.1.1.1 8.8.8.8 93.184.216.34 203.0.114.1; do
  arsy_is_global_ipv4 "$ip" || fail "$ip should pass conservative global IPv4 validation"
done
for ip in 0.1.2.3 10.0.0.1 100.64.0.1 127.0.0.1 169.254.1.1 172.16.0.1 192.0.2.1 192.168.1.1 198.18.0.1 198.51.100.1 203.0.113.1 224.0.0.1 240.0.0.1 255.255.255.255 999.1.1.1 not-an-ip; do
  if arsy_is_global_ipv4 "$ip"; then fail "$ip must be rejected"; fi
done
printf '[PASS] special-use IPv4 ranges are rejected.\n'
