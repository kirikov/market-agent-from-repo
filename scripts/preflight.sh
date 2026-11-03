#!/usr/bin/env bash
# Usage: preflight.sh <project-dir>
# Checks what a build, deploy or test hire needs. Prints key names and lengths, never values.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
dir="${1:?usage: preflight.sh <project-dir>}"
fail=0
ok()   { echo "OK    $*"; }
bad()  { echo "FAIL  $*"; fail=1; }
warn() { echo "WARN  $*"; }

use_node24 && ok "node $(node -v)"
if who=$(cd "$dir" && timeout 60 npx vercel whoami 2>/dev/null | tail -1) && [[ -n "$who" ]]; then
  ok "vercel login: $who (scope $VERCEL_SCOPE)"
else
  bad "vercel: not logged in; ask the user to run 'npx vercel login' in their terminal"
fi
docker info --format '{{.ServerVersion}}' >/dev/null 2>&1 && ok "docker (local sandbox)" || warn "docker missing: local smoke tests cannot run a sandbox"
[[ -f "$dir/.vercel/project.json" ]] && ok "vercel project: $(project_name "$dir")" || warn "vercel project not linked yet"

if [[ -f "$dir/.env.local" ]]; then
  [[ "$(stat -c %a "$dir/.env.local")" == 600 ]] || warn ".env.local is not chmod 600"
  for name in NEARAI_API_KEY MARKET_AGENT_TOKEN MARKET_WEBHOOK_SECRET; do
    v=$(env_value "$dir" "$name")
    [[ -n "$v" ]] && ok "$name set (${#v} chars)" || warn "$name empty"
  done
  [[ -n "$(env_value "$dir" VERCEL_OIDC_TOKEN)$(env_value "$dir" AI_GATEWAY_API_KEY)" ]] \
    && ok "AI Gateway credentials for local web_search" || warn "no VERCEL_OIDC_TOKEN/AI_GATEWAY_API_KEY: web_search fails locally (fine on Vercel)"
else
  bad "$dir/.env.local missing"
fi

key=$(env_value "$dir" NEARAI_API_KEY)
if [[ -n "$key" ]]; then
  r=$(curl -sS -m 60 https://cloud-api.near.ai/v1/chat/completions -H "authorization: Bearer $key" \
      -H 'content-type: application/json' \
      -d '{"model":"anthropic/claude-haiku-5-5","max_tokens":5,"messages":[{"role":"user","content":"Say ok"}]}' \
    | python3 -I -c 'import json,sys
d=json.load(sys.stdin)
print("OK" if d.get("choices") else "ERR "+json.dumps(d.get("error",d))[:200])' 2>&1)
  [[ "$r" == OK ]] && ok "NEAR AI key works and has credit" || bad "NEAR AI: $r (402 = out of credit: the user must top up)"
fi

token=$(env_value "$dir" MARKET_AGENT_TOKEN)
if [[ -n "$token" ]]; then
  code=$(curl -sS -m 30 -o /dev/null -w '%{http_code}' -H "authorization: Bearer $token" "$MARKET_BASE_URL/v1/agents/me/assignments?limit=1")
  [[ "$code" == 200 ]] && ok "market agent token accepted" || bad "market agent token: HTTP $code"
  "$SKILL_DIR/scripts/active-assignments.sh" "$dir" | tail -1
fi
exit $fail
