#!/bin/bash
# 화면과 터미널에 보이는 문구가 소스에 박혀 있는지 본다.
#
# 박혀 있으면 번역할 방법이 없다. 한글 문자열 리터럴을 찾되 주석은 제외한다.
# restage-icon은 아이콘을 굽는 내부 도구라 사용자가 보지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 언어 이름은 어느 언어에서도 제 이름 그대로 쓴다. 번역 대상이 아니다.
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
  echo "번역되지 않은 문구가 있습니다. L10n.string(키)로 옮기세요." >&2
  echo "$FOUND" >&2
  exit 1
fi

echo "하드코딩된 문구 없음"
