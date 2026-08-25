#!/bin/bash
# Assembles the restage.app bundle.
#
# SwiftPM can't produce an app bundle, so this builds the release binary and puts the bundle
# together by hand. A bundle is needed for two reasons: opening at login (SMAppService)
# requires one, and so does launching by double-click in Finder.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build/restage.app}"
BUNDLE_ID="com.chakki.restage"
# The release script passes the version it read from the tag. Without it, fall back to this
# repository's latest tag, and to 0.0.0 in a tarball build where git isn't around.
#
# A real version must not be the default. Forgetting to pass one would stamp a plausible
# number and hide the mistake. That happened: the formula and the installer both left this
# out, so every installed app believed it was 0.1.0 and the update check always claimed a
# newer version was available.
VERSION="${RESTAGE_VERSION:-}"
if [ -z "$VERSION" ]; then
  VERSION="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
fi
VERSION="${VERSION:-0.0.0}"

cd "$ROOT"

# Inside an already-sandboxed environment such as Homebrew, SwiftPM applying its own sandbox
# fails with "sandbox_apply: Operation not permitted". Those places pass
# RESTAGE_SWIFT_FLAGS=--disable-sandbox.
SWIFT_FLAGS="${RESTAGE_SWIFT_FLAGS:-}"

# shellcheck disable=SC2086
swift build -c release --product restage $SWIFT_FLAGS
BINARY="$(swift build -c release --product restage --show-bin-path $SWIFT_FLAGS)/restage"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/restage"

# Carry the resource bundle SwiftPM produced. The translations live inside it, and without
# it the screen shows raw keys. Signing happens after this, so the bundle is signed too.
for bundle in "$(dirname "$BINARY")"/*.bundle; do
  [ -e "$bundle" ] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done

# restage-icon draws the .iconset and iconutil bakes it into .icns.
# The drawing is code, so no binary asset is kept in the repository.
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
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>ko</string>
  </array>
  <key>NSAppleEventsUsageDescription</key>
  <string>restage needs automation permission to open browser tabs.</string>
</dict>
</plist>
PLIST

# The permission text is read per language from InfoPlist.strings, not from Info.plist. The
# system puts up that dialog, so it follows the system language, not the app's own setting.
mkdir -p "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/ko.lproj"
cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<'STRINGS'
"NSAppleEventsUsageDescription" = "restage needs automation permission to open browser tabs.";
STRINGS
cat > "$APP/Contents/Resources/ko.lproj/InfoPlist.strings" <<'STRINGS'
"NSAppleEventsUsageDescription" = "브라우저 탭을 열기 위해 자동화 권한이 필요합니다.";
STRINGS

# Choosing a signing identity: environment variable -> a certificate on this Mac -> adhoc.
#
# Signing with a certificate is what keeps the Accessibility approval. macOS ties the approval
# to the designated requirement, and the two forms differ.
#
#   adhoc      designated => cdhash H"f3b2..."
#   certificate  designated => identifier "com.chakki.restage" and anchor apple generic
#                            and certificate leaf[subject.CN] = "Apple Development: ..."
#
# Adhoc is tied to the code hash, so recompiling the same source changes the identity and
# drops the approval. A certificate is tied to the identifier and the certificate itself.
#
# Signing into Xcode with an Apple account gives a free Apple Development certificate. The one
# that costs money is Developer ID, needed to distribute to other people (notarization). For
# your own machine, Apple Development is enough.
if [ -n "${RESTAGE_SIGN_IDENTITY:-}" ]; then
  IDENTITY="$RESTAGE_SIGN_IDENTITY"
else
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)"
fi

if [ -n "$IDENTITY" ]; then
  # A distribution signature needs the hardened runtime and a timestamp. Notarization requires
  # them, and the timestamp keeps already-downloaded apps opening after the cert expires.
  # shellcheck disable=SC2086
  codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" \
    ${RESTAGE_SIGN_OPTIONS:-} "$APP"
else
  echo "Warning: no code signing certificate found, signing adhoc."
  echo "         The Accessibility approval drops on every rebuild."
  echo "         Signing into Xcode with an Apple account gives you a free certificate."
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
fi

echo "Built: $APP"
codesign -dv "$APP" 2>&1 | grep -E "Identifier|Signature|Authority" | head -3
