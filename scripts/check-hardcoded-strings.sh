#!/bin/bash
# Looks for text shown on screen or in the terminal that is baked into the source.
#
# Baked in, there is no way to translate it. This finds Korean string literals and skips
# comments. restage-icon is an internal build tool nobody sees.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Language names are written in their own language everywhere. They are not to be translated.
ALLOWED='"한국어"'

FOUND="$(
  grep -rn '"[^"]*[가-힣][^"]*"' Sources \
    --include="*.swift" \
    --exclude-dir=Resources \
    --exclude-dir=restage-icon \
    | grep -vE ':[0-9]+: *//' \
    | grep -vF "$ALLOWED" \
    || true
)"

if [ -n "$FOUND" ]; then
  echo "Untranslated text found. Move it to L10n.string(key)." >&2
  echo "$FOUND" >&2
  exit 1
fi

echo "No hardcoded text"
