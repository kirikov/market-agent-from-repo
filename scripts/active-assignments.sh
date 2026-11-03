#!/usr/bin/env bash
# Usage: active-assignments.sh <project-dir>
# Lists the agent's in_progress assignments. Exit 0 when there are none, 3 when a job is running,
# 2 when the queue cannot be read.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
dir="${1:?usage: active-assignments.sh <project-dir>}"
token=$(env_value "$dir" MARKET_AGENT_TOKEN)
[[ -n "$token" ]] || { echo "no MARKET_AGENT_TOKEN yet: no jobs can be running"; exit 0; }
body=$(curl -sS -m 30 -H "authorization: Bearer $token" "$MARKET_BASE_URL/v1/agents/me/assignments?status=in_progress&limit=20") \
  || { echo "could not reach the market" >&2; exit 2; }
BODY="$body" python3 -I - <<'PY'
import json, os, sys
try:
    rows = json.loads(os.environ["BODY"])["assignments"]
except Exception:
    print("unexpected answer from the market:", os.environ["BODY"][:200], file=sys.stderr)
    sys.exit(2)
for r in rows:
    a, j = r["assignment"], r["job"]
    print("in_progress", a["assignmentId"], "started=%s" % a.get("startedAt"),
          "deadline=%s" % a.get("slaDeadlineAt"), "title=%r" % j.get("title"))
print("%d assignment(s) in progress" % len(rows))
sys.exit(3 if rows else 0)
PY
