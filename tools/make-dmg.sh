#!/bin/bash
# Packages a built app as build/SilverRainMini-<version>.dmg (drag to Applications)
# and build/SilverRainMini-<version>.zip, and prints the SHA-256 the Homebrew cask needs.
# Usually run as `make dmg`. Self-signed, not notarized: see README for first launch.
#
#   tools/make-dmg.sh "build/Silver Rain Mini.app"
#
# REQUIRE_IDENTITY="SilverRainMini Self-Signed" refuses an app signed otherwise:
# CI sets it, because a release quietly signed ad-hoc would cost every user
# what macOS had granted the app (AllyKeyboard v1.2.0 shipped like that once).
set -euo pipefail

APP="${1:?usage: make-dmg.sh <path to .app>}"
OUT="$(dirname "$APP")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
NAME="SilverRainMini-$VERSION"

if [ -n "${REQUIRE_IDENTITY:-}" ]; then
    codesign -dv --verbose=2 "$APP" 2>&1 | grep -qxF "Authority=$REQUIRE_IDENTITY" || {
        echo "ERROR: $APP is not signed as '$REQUIRE_IDENTITY':" >&2
        codesign -dv --verbose=2 "$APP" 2>&1 | grep -E '^(Authority|Signature)=' >&2 || true
        exit 1
    }
fi
codesign --verify --strict "$APP"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"

rm -f "$OUT/$NAME.dmg" "$OUT/$NAME.zip"
hdiutil create -volname "Silver Rain Mini" -srcfolder "$STAGE" -ov -format UDZO "$OUT/$NAME.dmg" >/dev/null
ditto -c -k --keepParent "$APP" "$OUT/$NAME.zip"

echo "Built $OUT/$NAME.dmg and $OUT/$NAME.zip"
echo "SHA-256 of the .dmg (for the Homebrew cask):"
shasum -a 256 "$OUT/$NAME.dmg"
