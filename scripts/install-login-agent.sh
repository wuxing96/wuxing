#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Mushi Signal.app"
BINARY="$APP/Contents/MacOS/mushi-signal"
LABEL="com.wuxing.mushi-signal"
OLD_LABEL="com.wuxing.ai-traffic-light"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
OLD_PLIST="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ ! -x "$BINARY" ]; then
  "$ROOT/scripts/package-app.sh" >/dev/null
fi

mkdir -p "$HOME/Library/LaunchAgents"

/usr/bin/python3 - "$BINARY" "$PLIST" <<'PY'
import plistlib
import sys

binary, plist_path = sys.argv[1], sys.argv[2]
plist = {
    "Label": "com.wuxing.mushi-signal",
    "ProgramArguments": ["/usr/bin/open", "-g", binary.rsplit("/Contents/MacOS/", 1)[0]],
    "RunAtLoad": True,
    "KeepAlive": False,
    "StandardOutPath": "/tmp/mushi-signal.log",
    "StandardErrorPath": "/tmp/mushi-signal.err",
}
with open(plist_path, "wb") as f:
    plistlib.dump(plist, f)
PY

launchctl bootout "gui/$(id -u)" "$OLD_PLIST" 2>/dev/null || true
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
/usr/bin/pkill -TERM -f "/Mushi Signal.app/Contents/MacOS/mushi-signal" 2>/dev/null || true
/bin/sleep 0.3
rm -f "$OLD_PLIST"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$APP" 2>/dev/null || true
fi
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/$LABEL"
printf '%s\n' "$PLIST"
