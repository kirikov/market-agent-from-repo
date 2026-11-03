#!/usr/bin/env bash
# Usage: scaffold.sh <project-dir> [<source-repo-dir>]
# Clones Sasha's market agent template into <project-dir> and prepares it for a NEAR AI model:
# assignment-id patch, agent.ts with the output-token fix, web_search tool, dependencies, empty .env.local.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
dir="${1:?usage: scaffold.sh <project-dir> [<source-repo-dir>]}"
src="${2:-}"
[[ -e "$dir" ]] && die "$dir already exists"

git clone --quiet "$TEMPLATE_URL" "$dir"
cd "$dir"
# A push must never go to Sasha's repo by accident.
git remote rename origin template
template_sha=$(git rev-parse HEAD)

if grep -q 'Assignment id:' agent/lib/market/protocol.ts; then
  echo "template already names the assignment id; patch not needed"
else
  git apply "$SKILL_DIR/assets/protocol-assignment-id.patch" && echo "applied the assignment-id patch"
fi
cp "$SKILL_DIR/assets/agent.ts" agent/agent.ts
mkdir -p agent/tools
cp "$SKILL_DIR/assets/web_search.ts" agent/tools/web_search.ts

use_node24
npm i --ignore-scripts --no-audit --no-fund --loglevel=error

(umask 077
 printf '%s\n' '# Secrets for this agent. Gitignored, chmod 600. Never print the values.' \
   'NEARAI_API_KEY=' 'MARKET_AGENT_TOKEN=' 'MARKET_WEBHOOK_SECRET=' > .env.local)

{
  echo "# Sources"
  echo
  echo "- Template: $TEMPLATE_URL @ $template_sha"
  if [[ -n "$src" ]]; then
    echo "- Source: $(git -C "$src" remote get-url origin) @ $(git -C "$src" rev-parse HEAD)"
    lic=$(ls "$src" | grep -i -E '^(license|licence|copying)' | head -1 || true)
    echo "- License file: ${lic:-NONE FOUND}"
  fi
  echo
  echo "## Changes to the vendored source"
  echo
  echo "- (list each change, so an upstream update can be merged by hand)"
} > SOURCE.md

npx tsc && echo "typecheck OK"
echo "scaffolded $dir (template $(git rev-parse --short "$template_sha")); next: map the repo, write agent/instructions.md, fill .env.local"
