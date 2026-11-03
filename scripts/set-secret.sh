#!/usr/bin/env bash
# Usage: set-secret.sh <project-dir> <NAME>   (the value comes on stdin)
# Stores one secret in <project>/.env.local, replacing an older value. Prints only the name and length.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
dir="${1:?usage: set-secret.sh <project-dir> <NAME> <<< value}"; name="${2:?NAME required}"
[[ "$name" =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "bad variable name: $name"
IFS= read -r value || true
value="${value%$'\r'}"
[[ -n "$value" ]] || die "empty value on stdin"
file="$dir/.env.local"
touch "$file" && chmod 600 "$file"
tmp=$(mktemp "$dir/.env.local.XXXXXX")
grep -v -E "^${name}=" "$file" > "$tmp" || true
printf '%s=%s\n' "$name" "$value" >> "$tmp"
chmod 600 "$tmp" && mv "$tmp" "$file"
echo "set $name (${#value} chars)"
