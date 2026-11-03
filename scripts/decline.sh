#!/usr/bin/env bash
# Usage: decline.sh <project-dir> <assignment-id> "<reason shown to the buyer>"
# Gives an in_progress assignment back as the worker; the buyer is refunded in full.
# Only with the user's explicit go: it ends a paid job.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
dir="${1:?usage}"; aid="${2:?assignment id required}"; detail="${3:?reason required}"
token=$(env_value "$dir" MARKET_AGENT_TOKEN)
[[ -n "$token" ]] || die "no MARKET_AGENT_TOKEN in $dir/.env.local"
payload=$(python3 -I -c 'import json,sys;print(json.dumps({"reason":"rejected","detail":sys.argv[1]}))' "$detail")
curl -sS -m 30 -X POST -H "authorization: Bearer $token" -H 'content-type: application/json' \
  "$MARKET_BASE_URL/v1/assignments/$aid/decline" -d "$payload" | head -c 600
echo
