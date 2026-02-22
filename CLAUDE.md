# Pi + OpenClaw Setup

## Pi Access

- **Admin user:** `ssh pi@<PI_IP>`
- **OpenClaw user:** `ssh openclaw@<PI_IP>`
- Hostname: `clawpi.local`

## Key Details

- Pi model: Raspberry Pi 5
- OS: Raspberry Pi OS Lite (64-bit / arm64)
- OpenClaw systemd service: `openclaw-gateway` (not `openclaw`)
- Gateway: loopback only (`127.0.0.1:18789`)
- Access Gateway UI via SSH tunnel: `ssh -L 18789:127.0.0.1:18789 openclaw@clawpi.local`

## OpenClaw Config (on Pi)

- Config home: `~/.openclaw/`
- Auth profiles: `~/.openclaw/agents/main/agent/auth-profiles.json`
- Auth config: `~/.openclaw/agents/main/agent/auth.json`
- Workspace configs: `~/.openclaw/workspaces/` (SOUL.md, HEARTBEAT.md, TOOLS.md, USER.md)
- Primary model: `anthropic/claude-sonnet-4-6`
- Fallback model: `google/gemini-2.5-pro`

## References

- OpenClaw docs: https://docs.openclaw.ai/

## Workflow Preferences

- Multi-line terminal commands go in `temp-for-terminal.sh` (gitignored), SCP to Pi via `/tmp/t.sh`
- NEVER suggest commands that echo API keys or secrets in terminal output — use `read -s` or interactive prompts
- Commit early and often
