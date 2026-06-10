#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/AITrafficLight.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/ai-traffic-light" "$MACOS/ai-traffic-light"
cp "$ROOT/resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$MACOS/ai-traffic-light"

printf '%s\n' "$APP"
