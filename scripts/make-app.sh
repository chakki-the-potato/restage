#!/bin/bash
# restage.app 번들을 만든다.
#
# SwiftPM은 앱 번들을 만들지 못하므로 릴리스 바이너리를 빌드한 뒤 번들 구조를 직접 조립한다.
# 번들이 필요한 이유는 둘이다. 로그인 시 자동 실행(SMAppService)이 번들을 요구하고,
# Finder에서 더블클릭으로 실행하려면 번들이어야 한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build/restage.app}"
BUNDLE_ID="com.chakki.restage"
# 릴리스는 태그에서 받은 버전을 박는다. 로컬 빌드는 기본값을 쓴다.
VERSION="${RESTAGE_VERSION:-0.1.0}"

cd "$ROOT"

# Homebrew처럼 이미 샌드박스 안에서 도는 환경에서는 SwiftPM이 자기 샌드박스를 또 걸다가
# "sandbox_apply: Operation not permitted"로 실패한다. 그런 곳에서
# RESTAGE_SWIFT_FLAGS=--disable-sandbox 를 넘긴다.
SWIFT_FLAGS="${RESTAGE_SWIFT_FLAGS:-}"

# shellcheck disable=SC2086
swift build -c release --product restage $SWIFT_FLAGS
BINARY="$(swift build -c release --product restage --show-bin-path $SWIFT_FLAGS)/restage"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/restage"

# SwiftPM이 만든 자원 번들을 함께 옮긴다. 번역 문구가 그 안에 있어 빠지면 화면에 키가
# 그대로 보인다. 서명은 이 뒤에 하므로 번들도 서명에 포함된다.
for bundle in "$(dirname "$BINARY")"/*.bundle; do
  [ -e "$bundle" ] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done

# 아이콘은 restage-icon이 그린 .iconset을 iconutil이 .icns로 굽는다.
# 그림 자체가 코드라 별도 바이너리 에셋을 저장소에 두지 않는다.
ICONSET="$ROOT/build/restage.iconset"
rm -rf "$ICONSET"
swift run -c release $SWIFT_FLAGS restage-icon "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/restage.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>restage</string>
  <key>CFBundleExecutable</key>
  <string>restage</string>
  <key>CFBundleIconFile</key>
  <string>restage</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>브라우저 탭을 열기 위해 자동화 권한이 필요합니다.</string>
</dict>
</plist>
PLIST

# 서명 신원을 고르는 순서: 환경변수 -> 이 컴퓨터의 인증서 -> adhoc.
#
# 인증서로 서명해야 하는 이유는 접근성 승인이 유지되기 때문이다. macOS는 승인을
# designated requirement에 묶는데, 둘의 형태가 다르다.
#
#   adhoc      designated => cdhash H"f3b2..."
#   인증서      designated => identifier "com.chakki.restage" and anchor apple generic
#                            and certificate leaf[subject.CN] = "Apple Development: ..."
#
# adhoc은 코드 해시에 묶이므로 소스가 같아도 다시 컴파일하면 신원이 바뀌고 승인이 풀린다.
# 인증서는 식별자와 인증서에 묶이므로 몇 번을 다시 빌드해도 같은 신원이다.
#
# Xcode에 Apple 계정을 로그인하면 무료로 Apple Development 인증서가 생긴다. 결제가
# 필요한 것은 Developer ID이며, 그것은 남에게 배포할 때(공증) 필요하다. 내 컴퓨터에서
# 쓰는 데는 Apple Development로 충분하다.
if [ -n "${RESTAGE_SIGN_IDENTITY:-}" ]; then
  IDENTITY="$RESTAGE_SIGN_IDENTITY"
else
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)"
fi

if [ -n "$IDENTITY" ]; then
  # 배포용 서명에는 hardened runtime과 타임스탬프가 필요하다. 공증이 그것을 요구하고,
  # 타임스탬프가 있어야 인증서가 만료된 뒤에도 이미 받아 간 앱이 계속 열린다.
  # shellcheck disable=SC2086
  codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" \
    ${RESTAGE_SIGN_OPTIONS:-} "$APP"
else
  echo "경고: 코드 서명 인증서가 없어 adhoc으로 서명합니다."
  echo "      재빌드할 때마다 접근성 승인이 풀립니다."
  echo "      Xcode에 Apple 계정을 로그인하면 무료 인증서가 생깁니다."
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
fi

echo "만들어짐: $APP"
codesign -dv "$APP" 2>&1 | grep -E "Identifier|Signature|Authority" | head -3
