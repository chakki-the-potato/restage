#!/bin/bash
# 배포용 restage.app과 zip을 만든다.
#
# 로컬 빌드와 다른 점은 서명뿐이다. make-app.sh는 이 컴퓨터의 인증서를 자동으로
# 골라 쓰는데, 그 인증서는 Apple Development라 배포에 쓸 수 없다. 그것으로 서명한
# 앱은 받은 사람의 맥에서 Gatekeeper가 거부하고, 인증서는 1년 뒤 만료된다.
# 그래서 여기서는 adhoc으로 고정한다.
#
# 받은 사람은 첫 실행에 한 번 우클릭 열기를 해야 한다. 이것을 없애려면 유료
# Apple Developer Program의 Developer ID 인증서로 서명하고 공증해야 한다.
# 계정이 생기면 RESTAGE_SIGN_IDENTITY로 신원을 넘기고 아래에 notarytool 단계를
# 추가하면 된다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"

if [ -z "$VERSION" ]; then
  echo "사용법: make-release.sh <버전>   예: make-release.sh 0.1.0" >&2
  exit 2
fi

OUT="$ROOT/build/release"
APP="$OUT/restage.app"
ZIP="$OUT/restage-$VERSION-macos.zip"

rm -rf "$OUT"
mkdir -p "$OUT"

RESTAGE_SIGN_IDENTITY="-" RESTAGE_VERSION="$VERSION" "$ROOT/scripts/make-app.sh" "$APP"

# ditto를 쓰는 이유는 번들의 심볼릭 링크와 실행 권한, 확장 속성을 보존하기 때문이다.
# zip 명령은 이것들을 잃어 받은 쪽에서 앱이 열리지 않을 수 있다.
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "만들어짐: $ZIP"
codesign --verify --strict "$APP" && echo "서명 검증 통과 (adhoc)"
