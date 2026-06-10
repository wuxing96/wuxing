#!/bin/sh
set -eu

LABEL="com.wuxing.mushi-signal"
OLD_LABEL="com.wuxing.ai-traffic-light"
APP="/Applications/Mushi Signal.app"
OLD_APP="/Applications/AITrafficLight.app"
BINARY="$APP/Contents/MacOS/mushi-signal"
CONSOLE_USER="$(/usr/bin/stat -f %Su /dev/console 2>/dev/null || true)"

if [ ! -x "$BINARY" ]; then
  echo "Mushi Signal binary is missing: $BINARY" >&2
  exit 1
fi

if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ] || [ "$CONSOLE_USER" = "loginwindow" ]; then
  echo "Mushi Signal installed, but no logged-in user was available for LaunchAgent setup."
  exit 0
fi

USER_HOME="$(/usr/bin/dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory | /usr/bin/awk '{print $2}')"
USER_UID="$(/usr/bin/id -u "$CONSOLE_USER")"
PLIST="$USER_HOME/Library/LaunchAgents/$LABEL.plist"
OLD_PLIST="$USER_HOME/Library/LaunchAgents/$OLD_LABEL.plist"

/bin/mkdir -p "$USER_HOME/Library/LaunchAgents"

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

/usr/sbin/chown "$CONSOLE_USER":staff "$PLIST"
/bin/chmod 644 "$PLIST"
/usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

/bin/launchctl bootout "gui/$USER_UID" "$OLD_PLIST" 2>/dev/null || true
/bin/launchctl bootout "gui/$USER_UID" "$PLIST" 2>/dev/null || true
/bin/rm -f "$OLD_PLIST"
/bin/rm -rf "$OLD_APP"
/bin/launchctl bootstrap "gui/$USER_UID" "$PLIST"
/bin/launchctl kickstart -k "gui/$USER_UID/$LABEL"

echo "Mushi Signal installed and started for $CONSOLE_USER."
