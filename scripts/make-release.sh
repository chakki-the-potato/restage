#!/bin/bash
# Builds restage.app, a dmg, and a zip for distribution.
#
# Choosing the signing identity is what differs from a local build. make-app.sh takes any
# certificate on this Mac, and Apple Development among them can't be used for distribution:
# an app signed with it is refused by Gatekeeper on someone else's Mac and expires in a year.
#
# So this looks only for Developer ID. With one, it signs and notarizes. Without one it makes
# an adhoc build, which the recipient has to right-click-open once.
#
# The credentials for notarization are stored once.
#
#   xcrun notarytool store-credentials restage \
#     --apple-id <apple account> --team-id <team id> --password <app password>
#
# The app password is created at appleid.apple.com. It is not the account password.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
NOTARY_PROFILE="${RESTAGE_NOTARY_PROFILE:-restage}"

if [ -z "$VERSION" ]; then
  echo "usage: make-release.sh <version>   e.g. make-release.sh 0.2.0" >&2
  exit 2
fi

OUT="$ROOT/build/release"
APP="$OUT/restage.app"
ZIP="$OUT/restage-$VERSION-macos.zip"
DMG="$OUT/restage-$VERSION.dmg"

rm -rf "$OUT"
mkdir -p "$OUT"

# 1. Choose a signing identity
#
# An identity passed by environment variable is trusted. CI uses it to point at the one it
# put into the keychain.
IDENTITY="${RESTAGE_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)".*/\1/p' | head -1)"
fi

if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
  echo "Signing identity: $IDENTITY"
  SIGNED=1
else
  echo "No Developer ID certificate, building adhoc."
  echo "  The recipient has to right-click > Open on first launch."
  IDENTITY="-"
  SIGNED=0
fi

# 2. Build the app
#
# A distribution signature needs the hardened runtime. Notarization requires it.
RESTAGE_SIGN_IDENTITY="$IDENTITY" \
RESTAGE_SIGN_OPTIONS="${RESTAGE_SIGN_OPTIONS:---options runtime --timestamp}" \
RESTAGE_VERSION="$VERSION" \
  "$ROOT/scripts/make-app.sh" "$APP"

# 3. Notarize
#
# Only a signed app can be notarized. Without credentials, skip it.
NOTARIZED=0
if [ "$SIGNED" = "1" ]; then
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "Notarizing... (Apple's servers do the work, so this takes a few minutes)"
    NOTARY_ZIP="$OUT/notarize.zip"
    ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" \
      --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$NOTARY_ZIP"

    # Staple the ticket into the app so it verifies without a network, and keeps opening for
    # people who already have it even after the certificate expires.
    xcrun stapler staple "$APP"
    NOTARIZED=1
  else
    echo "No notarization credentials ($NOTARY_PROFILE), skipping."
    echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id ... --team-id ... --password ..."
  fi
fi

# 4. dmg
#
# Makes the drag-to-install window. It is the only path for someone who doesn't use a terminal.
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "restage" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

# The dmg is signed too, so the recipient can tell it wasn't tampered with.
if [ "$SIGNED" = "1" ]; then
  codesign --force --sign "$IDENTITY" --timestamp "$DMG"
  if [ "$NOTARIZED" = "1" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

# 5. zip
#
# ditto is used because it preserves the bundle's symlinks, executable bits, and extended
# attributes. The zip command loses them and the app may not open on the other side.
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Built:"
echo "  $DMG"
echo "  $ZIP"
codesign --verify --strict "$APP" && echo "Signature verified"

if [ "$NOTARIZED" = "1" ]; then
  spctl --assess --type execute "$APP" && echo "Gatekeeper passed — recipients can open it directly"
else
  echo "Not notarized — recipients need right-click > Open"
fi
