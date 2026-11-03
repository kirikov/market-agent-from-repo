#!/usr/bin/env bash
# Usage: push-env.sh <project-dir>
# Copies the filled values from <project>/.env.local into the Vercel project's production env.
# Values go through stdin and are never printed. VERCEL_* values (the CLI's own) are skipped.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
dir="${1:?usage: push-env.sh <project-dir>}"
cd "$dir"
[[ -f .vercel/project.json ]] || die "not linked: run 'npx vercel link --yes --project <name> --scope $VERCEL_SCOPE' first"
while IFS= read -r line; do
  [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]] || continue
  name="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
  value="${value%\"}"; value="${value#\"}"
  [[ -z "$value" || "$name" == VERCEL_* ]] && continue
  printf '%s' "$value" | npx vercel env add "$name" production --force --scope "$VERCEL_SCOPE" >/dev/null 2>&1 \
    && echo "set $name" || echo "FAILED $name"
done < .env.local
echo "env changes take effect on the next deploy"
