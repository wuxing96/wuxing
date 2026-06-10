#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Mushi Signal.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/ai-traffic-light" "$MACOS/mushi-signal"
cp "$ROOT/resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$MACOS/mushi-signal"

printf '%s\n' "$APP"
