#!/bin/sh
set -eu
export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$ROOT/resources/Info.plist")"
BUILD_ID="$(/bin/date +%Y%m%d%H%M%S)"
DOWNLOADS="${DOWNLOADS:-$HOME/Downloads}"
APP_NAME="Mushi Signal"
APP="$ROOT/dist/$APP_NAME.app"
STAGE="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/ai-traffic-light-dmg.XXXXXX")"
COMPONENT_ROOT="$STAGE/component"
SCRIPTS_DIR="$STAGE/scripts"
DMG_ROOT="$STAGE/dmg"
PKG_NAME="Install Mushi Signal.pkg"
PKG="$STAGE/$PKG_NAME"
DMG="$DOWNLOADS/MushiSignal-$VERSION-$BUILD_ID.dmg"

cleanup() {
  /bin/rm -rf "$STAGE"
}
trap cleanup EXIT

"$ROOT/scripts/package-app.sh" >/dev/null

/bin/mkdir -p "$COMPONENT_ROOT/Applications" "$SCRIPTS_DIR" "$DMG_ROOT"
/usr/bin/ditto --norsrc "$APP" "$COMPONENT_ROOT/Applications/$APP_NAME.app"

SIGN_IDENTITY="${MUSHI_SIGNAL_SIGN_IDENTITY:-Mushi Signal Local Code Signing}"
if /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -F "\"$SIGN_IDENTITY\"" >/dev/null 2>&1; then
  /usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" "$COMPONENT_ROOT/Applications/$APP_NAME.app" >/dev/null
else
  /usr/bin/codesign --force --deep --sign - "$COMPONENT_ROOT/Applications/$APP_NAME.app" >/dev/null
fi
/usr/bin/xattr -cr "$COMPONENT_ROOT"

/bin/cp "$ROOT/scripts/pkg-postinstall.sh" "$SCRIPTS_DIR/postinstall"
/bin/chmod 755 "$SCRIPTS_DIR/postinstall"

/usr/bin/pkgbuild \
  --root "$COMPONENT_ROOT" \
  --scripts "$SCRIPTS_DIR" \
  --identifier "com.wuxing.mushi-signal.pkg" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG" >/dev/null

/bin/cp "$PKG" "$DMG_ROOT/$PKG_NAME"
/usr/bin/ditto --norsrc "$COMPONENT_ROOT/Applications/$APP_NAME.app" "$DMG_ROOT/$APP_NAME.app"
/bin/cp "$ROOT/resources/Install.command" "$DMG_ROOT/Install.command"
/bin/cp "$ROOT/resources/Uninstall.command" "$DMG_ROOT/Uninstall.command"
/bin/cp "$ROOT/resources/DMG-README.txt" "$DMG_ROOT/README.txt"
/bin/chmod 755 "$DMG_ROOT/Install.command" "$DMG_ROOT/Uninstall.command"
/usr/bin/xattr -cr "$DMG_ROOT"

/bin/mkdir -p "$DOWNLOADS"
/usr/bin/hdiutil create \
  -volname "Mushi Signal $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  "$DMG" >/dev/null

printf '%s\n' "$DMG"
