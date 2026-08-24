#!/bin/bash
# 배포용 restage.app, dmg, zip을 만든다.
#
# 서명 신원을 어떻게 고르는지가 로컬 빌드와 다르다. make-app.sh는 이 컴퓨터의 아무
# 인증서나 쓰는데, 그중 Apple Development는 배포에 쓸 수 없다. 그것으로 서명한 앱은
# 받은 사람의 맥에서 Gatekeeper가 거부하고 1년 뒤 만료된다.
#
# 그래서 여기서는 Developer ID만 찾는다. 있으면 서명하고 공증한다. 없으면 adhoc으로
# 만든다. adhoc 앱은 받은 사람이 첫 실행에 한 번 우클릭 열기를 해야 한다.
#
# 공증에 필요한 자격증명은 한 번만 저장하면 된다.
#
#   xcrun notarytool store-credentials restage \
#     --apple-id <애플 계정> --team-id <팀 ID> --password <앱 암호>
#
# 앱 암호는 appleid.apple.com에서 만든다. 계정 비밀번호가 아니다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
NOTARY_PROFILE="${RESTAGE_NOTARY_PROFILE:-restage}"

if [ -z "$VERSION" ]; then
  echo "사용법: make-release.sh <버전>   예: make-release.sh 0.2.0" >&2
  exit 2
fi

OUT="$ROOT/build/release"
APP="$OUT/restage.app"
ZIP="$OUT/restage-$VERSION-macos.zip"
DMG="$OUT/restage-$VERSION.dmg"

rm -rf "$OUT"
mkdir -p "$OUT"

# 1. 서명 신원 고르기
#
# 환경변수로 넘어온 것이 있으면 그것을 믿는다. CI에서 키체인에 넣은 신원을 가리킬 때 쓴다.
IDENTITY="${RESTAGE_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)".*/\1/p' | head -1)"
fi

if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
  echo "서명 신원: $IDENTITY"
  SIGNED=1
else
  echo "Developer ID 인증서가 없어 adhoc으로 만듭니다."
  echo "  받은 사람은 첫 실행에 우클릭 > 열기를 해야 합니다."
  IDENTITY="-"
  SIGNED=0
fi

# 2. 앱 만들기
#
# 배포용 서명에는 hardened runtime이 필요하다. 공증이 그것을 요구한다.
RESTAGE_SIGN_IDENTITY="$IDENTITY" \
RESTAGE_SIGN_OPTIONS="${RESTAGE_SIGN_OPTIONS:---options runtime --timestamp}" \
RESTAGE_VERSION="$VERSION" \
  "$ROOT/scripts/make-app.sh" "$APP"

# 3. 공증
#
# 서명된 앱만 공증할 수 있다. 자격증명이 없으면 건너뛴다.
NOTARIZED=0
if [ "$SIGNED" = "1" ]; then
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "공증하는 중... (Apple 서버가 처리하므로 몇 분 걸립니다)"
    NOTARY_ZIP="$OUT/notarize.zip"
    ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" \
      --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$NOTARY_ZIP"

    # 티켓을 앱에 박아둔다. 그래야 인터넷 없이도 검증되고, 나중에 인증서가 만료돼도
    # 이미 받은 사람은 계속 열 수 있다.
    xcrun stapler staple "$APP"
    NOTARIZED=1
  else
    echo "공증 자격증명($NOTARY_PROFILE)이 없어 건너뜁니다."
    echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id ... --team-id ... --password ..."
  fi
fi

# 4. dmg
#
# 드래그로 설치하는 창을 만든다. 터미널을 모르는 사람이 쓸 수 있는 유일한 경로다.
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "restage" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

# dmg 자체도 서명해야 받는 쪽에서 손대지 않았음이 확인된다.
if [ "$SIGNED" = "1" ]; then
  codesign --force --sign "$IDENTITY" --timestamp "$DMG"
  if [ "$NOTARIZED" = "1" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

# 5. zip
#
# ditto를 쓰는 이유는 번들의 심볼릭 링크와 실행 권한, 확장 속성을 보존하기 때문이다.
# zip 명령은 이것들을 잃어 받은 쪽에서 앱이 열리지 않을 수 있다.
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "만들어짐:"
echo "  $DMG"
echo "  $ZIP"
codesign --verify --strict "$APP" && echo "서명 검증 통과"

if [ "$NOTARIZED" = "1" ]; then
  spctl --assess --type execute "$APP" && echo "Gatekeeper 통과 — 받는 사람이 바로 열 수 있습니다"
else
  echo "공증하지 않음 — 받는 사람은 우클릭 > 열기가 필요합니다"
fi
