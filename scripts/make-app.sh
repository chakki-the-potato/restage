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

cd "$ROOT"
swift build -c release --product restage
BINARY="$(swift build -c release --product restage --show-bin-path)/restage"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/restage"

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
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>브라우저 탭을 열기 위해 자동화 권한이 필요합니다.</string>
</dict>
</plist>
PLIST

# 식별자를 고정하면 재빌드해도 같은 이름으로 서명된다.
# 다만 adhoc 서명은 designated requirement가 코드 해시에 묶이므로
# 접근성 승인이 재빌드 후에도 유지되는지는 별도로 확인해야 한다.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

echo "만들어짐: $APP"
codesign -dv "$APP" 2>&1 | grep -E "Identifier|Signature"
