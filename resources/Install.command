#!/bin/sh
set -eu

LABEL="com.wuxing.mushi-signal"
OLD_LABEL="com.wuxing.ai-traffic-light"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/Mushi Signal.app"
TARGET_DIR="/Applications"

if [ ! -d "$SOURCE_APP" ]; then
  echo "Cannot find Mushi Signal.app next to this installer." >&2
  exit 1
fi

if [ ! -w "$TARGET_DIR" ]; then
  TARGET_DIR="$HOME/Applications"
  /bin/mkdir -p "$TARGET_DIR"
fi

TARGET_APP="$TARGET_DIR/Mushi Signal.app"
OLD_TARGET_APP="$TARGET_DIR/AITrafficLight.app"
BINARY="$TARGET_APP/Contents/MacOS/mushi-signal"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
OLD_PLIST="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"

/bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$OLD_PLIST" 2>/dev/null || true
/bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$PLIST" 2>/dev/null || true
/bin/rm -f "$OLD_PLIST"
/bin/rm -rf "$OLD_TARGET_APP"
/bin/rm -rf "$TARGET_APP"
/usr/bin/ditto --norsrc "$SOURCE_APP" "$TARGET_APP"
/usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

if [ ! -x "$BINARY" ]; then
  echo "Installed binary is missing: $BINARY" >&2
  exit 1
fi

/bin/mkdir -p "$HOME/Library/LaunchAgents"
/bin/cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BINARY</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>/tmp/mushi-signal.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/mushi-signal.err</string>
</dict>
</plist>
PLIST

/bin/chmod 644 "$PLIST"
/bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$PLIST"
/bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/$LABEL"

echo "Mushi Signal installed to: $TARGET_APP"
echo "LaunchAgent: $PLIST"
echo "It reads Codex logs from: $HOME/.codex/sessions"
