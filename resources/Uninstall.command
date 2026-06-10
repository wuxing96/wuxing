#!/bin/sh
set -eu

LABEL="com.wuxing.mushi-signal"
OLD_LABEL="com.wuxing.ai-traffic-light"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
OLD_PLIST="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"

/bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$PLIST" 2>/dev/null || true
/bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$OLD_PLIST" 2>/dev/null || true
/bin/rm -f "$PLIST"
/bin/rm -f "$OLD_PLIST"

if [ -d "$HOME/Applications/Mushi Signal.app" ]; then
  /bin/rm -rf "$HOME/Applications/Mushi Signal.app"
fi

if [ -d "$HOME/Applications/AITrafficLight.app" ]; then
  /bin/rm -rf "$HOME/Applications/AITrafficLight.app"
fi

if [ -d "/Applications/Mushi Signal.app" ] && [ -w "/Applications" ]; then
  /bin/rm -rf "/Applications/Mushi Signal.app"
fi

if [ -d "/Applications/AITrafficLight.app" ] && [ -w "/Applications" ]; then
  /bin/rm -rf "/Applications/AITrafficLight.app"
fi

echo "Mushi Signal uninstalled for the current user."
