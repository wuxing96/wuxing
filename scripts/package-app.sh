#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Mushi Signal.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
SIGN_IDENTITY="${MUSHI_SIGNAL_SIGN_IDENTITY:-Mushi Signal Local Code Signing}"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/ai-traffic-light" "$MACOS/mushi-signal"
cp "$ROOT/resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/resources/MushiSignal.icns" "$RESOURCES/MushiSignal.icns"
cp "$ROOT/resources/Assets/mushi-bug.png" "$RESOURCES/mushi-bug.png"
mkdir -p "$RESOURCES/mushi-status"
cp "$ROOT/resources/Assets/mushi-status"/mushi-status-*.png "$RESOURCES/mushi-status/"
chmod +x "$MACOS/mushi-signal"
if /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -F "\"$SIGN_IDENTITY\"" >/dev/null 2>&1; then
  /usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" "$APP" >/dev/null
else
  /usr/bin/codesign --force --deep --sign - "$APP" >/dev/null
fi

printf '%s\n' "$APP"
