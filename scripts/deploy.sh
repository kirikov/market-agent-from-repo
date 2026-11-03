#!/usr/bin/env bash
# Usage: deploy.sh <project-dir> [--during-job]
# Type-checks and deploys to Vercel production, then probes the production alias.
# Refuses while the agent has an in_progress assignment, unless the user explicitly allowed --during-job.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
dir="${1:?usage: deploy.sh <project-dir> [--during-job]}"; force="${2:-}"
cd "$dir"
[[ -f .vercel/project.json ]] || die "not linked: run 'npx vercel link --yes --project <name> --scope $VERCEL_SCOPE' first"

set +e; "$SKILL_DIR/scripts/active-assignments.sh" . ; rc=$?; set -e
if [[ $rc -eq 3 && "$force" != "--during-job" ]]; then
  die "a customer job is running; the user's rule is not to redeploy during a job (pass --during-job only on their explicit say-so)"
elif [[ $rc -eq 2 ]]; then
  die "could not check the agent's queue; not deploying blind"
fi

use_node24
npx tsc
log=$(mktemp)
if ! npx vercel deploy --prod --yes --scope "$VERCEL_SCOPE" > "$log" 2>&1; then
  tail -30 "$log"; die "deploy failed (full log: $log)"
fi
grep -o '"message": "[^"]*"' "$log" | tail -1 || tail -5 "$log"
url="https://$(project_name .).vercel.app"

# The production alias can lag a few seconds behind the deploy.
for _ in $(seq 1 12); do
  curl -sf -m 10 "$url/eve/v1/health" >/dev/null && break
  sleep 5
done
echo "health: $(curl -sS -m 10 "$url/eve/v1/health" || echo unreachable)"
code=$(curl -sS -m 20 -o /tmp/deploy-probe.$$ -w '%{http_code}' -X POST "$url/market/webhook" -d '{}' || true)
case "$code" in
  401) echo "webhook: OK (unsigned request refused) at $url/market/webhook" ;;
  500) echo "webhook: secrets missing: $(head -c 200 /tmp/deploy-probe.$$)  (expected before update_agent + push-env)" ;;
  *)   echo "webhook: unexpected HTTP $code: $(head -c 200 /tmp/deploy-probe.$$)" ;;
esac
rm -f /tmp/deploy-probe.$$ "$log"
