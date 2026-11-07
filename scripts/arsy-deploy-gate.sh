#!/usr/bin/env bash
set -Eeuo pipefail

# ForcedCommand entrypoint for the dedicated arsy-deploy SSH key.
# Only accepts: deploy <40-character commit SHA>
COMMAND="${SSH_ORIGINAL_COMMAND:-}"
if [[ "$COMMAND" =~ ^deploy[[:space:]]([0-9a-f]{40})$ ]]; then
  exec /usr/bin/sudo -n /usr/local/sbin/arsy-deploy "${BASH_REMATCH[1]}"
fi
printf '%s\n' 'A-R-S-Y deploy key only accepts: deploy <commit-sha>' >&2
exit 64
