# Shared helpers for the market-agent-from-repo scripts. Source it; do not run it.
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_URL="https://github.com/fadeevab/market-agent-template"
VERCEL_SCOPE="${VERCEL_SCOPE:-near-agentic-market}"
MARKET_BASE_URL="${MARKET_BASE_URL:-https://market.near.ai}"

die() { echo "error: $*" >&2; exit 1; }

# eve needs Node 24, and the Bash tool shell does not load nvm.
use_node24() {
  local major
  major=$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/') || true
  if [[ "${major:-0}" -lt 24 ]]; then
    local bin
    bin=$(ls -d "$HOME"/.nvm/versions/node/v2[4-9].* 2>/dev/null | sort -V | tail -1)
    [[ -n "$bin" ]] || die "Node 24 not found: run 'nvm install 24'"
    export PATH="$bin/bin:$PATH"
  fi
}

# Prints one value from <project>/.env.local without the surrounding quotes. Never echo the result.
env_value() {
  local file="$1/.env.local" name="$2"
  [[ -f "$file" ]] || return 0
  grep -E "^${name}=" "$file" | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'
}

project_name() {
  python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['projectName'])" "$1/.vercel/project.json" 2>/dev/null
}
