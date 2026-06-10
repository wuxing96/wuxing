#!/bin/sh
set -eu

LABEL="com.wuxing.ai-traffic-light"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

/bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$PLIST" 2>/dev/null || true
/bin/rm -f "$PLIST"

if [ -d "$HOME/Applications/AITrafficLight.app" ]; then
  /bin/rm -rf "$HOME/Applications/AITrafficLight.app"
fi

if [ -d "/Applications/AITrafficLight.app" ] && [ -w "/Applications" ]; then
  /bin/rm -rf "/Applications/AITrafficLight.app"
fi

echo "AI Traffic Light uninstalled for the current user."
