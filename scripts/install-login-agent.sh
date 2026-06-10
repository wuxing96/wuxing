#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BINARY="$ROOT/dist/AITrafficLight.app/Contents/MacOS/ai-traffic-light"
PLIST="$HOME/Library/LaunchAgents/com.wuxing.ai-traffic-light.plist"

if [ ! -x "$BINARY" ]; then
  "$ROOT/scripts/package-app.sh" >/dev/null
fi

mkdir -p "$HOME/Library/LaunchAgents"

/usr/bin/python3 - "$BINARY" "$PLIST" <<'PY'
import plistlib
import sys

binary, plist_path = sys.argv[1], sys.argv[2]
plist = {
    "Label": "com.wuxing.ai-traffic-light",
    "ProgramArguments": [binary],
    "RunAtLoad": True,
    "KeepAlive": False,
    "StandardOutPath": "/tmp/ai-traffic-light.log",
    "StandardErrorPath": "/tmp/ai-traffic-light.err",
}
with open(plist_path, "wb") as f:
    plistlib.dump(plist, f)
PY

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/com.wuxing.ai-traffic-light"
printf '%s\n' "$PLIST"
