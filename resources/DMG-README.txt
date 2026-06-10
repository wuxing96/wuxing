AI Traffic Light

Install:
1. Double-click "Install AI Traffic Light.pkg".
2. Finish the macOS Installer.
3. The widget starts automatically for the current macOS user.

Fallback install:
- If the package installer is blocked, right-click Install.command and choose Open.

What it reads:
- Codex session logs from ~/.codex/sessions
- Token usage events from the same Codex logs

Requirement:
- Codex must already be installed and run at least once on this Mac.
- macOS 13 or newer.

After install:
- App: /Applications/AITrafficLight.app, or ~/Applications/AITrafficLight.app if /Applications is not writable
- LaunchAgent: ~/Library/LaunchAgents/com.wuxing.ai-traffic-light.plist
- Logs: /tmp/ai-traffic-light.log and /tmp/ai-traffic-light.err

If macOS blocks the unsigned installer:
- Right-click "Install AI Traffic Light.pkg" and choose Open.

Uninstall:
Double-click Uninstall.command.
