Mushi Signal

Install:
1. Double-click "Install Mushi Signal.pkg".
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
- App: /Applications/Mushi Signal.app, or ~/Applications/Mushi Signal.app if /Applications is not writable
- LaunchAgent: ~/Library/LaunchAgents/com.wuxing.mushi-signal.plist
- Logs: /tmp/mushi-signal.log and /tmp/mushi-signal.err

If macOS blocks the unsigned installer:
- Right-click "Install Mushi Signal.pkg" and choose Open.

Uninstall:
Double-click Uninstall.command.
