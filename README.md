# Mushi Signal

Small local macOS floating status light for Codex sessions.

## Run

```sh
cd ~/ai-traffic-light
./scripts/run.sh
```

The panel stays in the bottom-right corner, floats above normal windows, and watches `~/.codex/sessions`.

## Status

- Red: a session is working or has a pending tool call.
- Yellow: a session is waiting for approval or input.
- Green: recent sessions are complete and waiting for the next prompt.
- Gray: no recent Codex sessions.

Click the light to expand or collapse the multi-session list. Drag it to move it. Right-click it to quit.

## Start At Login

```sh
cd ~/ai-traffic-light
./scripts/package-app.sh
./scripts/install-login-agent.sh
```
