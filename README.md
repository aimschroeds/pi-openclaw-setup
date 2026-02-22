# Pi + OpenClaw Setup

Run an autonomous AI agent (OpenClaw) on a dedicated Raspberry Pi — with sandboxed accounts, capped finances, and kill-switch controls.

## What's Inside

| Directory | What | Time |
|---|---|---|
| [01-pi-setup/](01-pi-setup/) | Flash Raspberry Pi OS Lite and configure headless SSH access | ~30 min |
| [02-openclaw/](02-openclaw/) | Harden the Pi, install OpenClaw, connect sandboxed channels | ~1–2 hours |

## Quick Start

1. **Set up the Pi** — Follow [01-pi-setup/README.md](01-pi-setup/README.md) to flash the OS and get SSH access
2. **Create burner accounts** — See Phase 0 in [02-openclaw/README.md](02-openclaw/README.md) for email, phone, messaging, and payment accounts
3. **Harden and install** — Run the scripts in [02-openclaw/scripts/](02-openclaw/scripts/) to lock down the Pi and install OpenClaw
4. **Configure the agent** — Edit the templates in [02-openclaw/config/](02-openclaw/config/) to set personality, boundaries, and tools

## Philosophy

**You build the cage. The agent furnishes the room.**

- Every account is disposable — nothing touches your real identity
- Financial exposure is hard-capped by a prepaid card with no overdraft
- The Pi is isolated on your network and hardened at the OS level
- You can kill the agent instantly via SSH or physical power-off
- Every action is logged and auditable

## Requirements

- Raspberry Pi (any model with networking; tested on Pi 5)
- microSD card (16 GB+)
- Another computer on the same network (macOS or Linux)
- Google AI subscription ($20/mo) — or Anthropic/OpenAI API key

## Cost Estimate

| Item | Monthly |
|---|---|
| Google AI subscription | $20/mo flat |
| Twilio (SMS/Voice) | ~$5–15 |
| Privacy.com | Free |
| Prepaid SIM (optional) | $15–30 |
| ProtonMail | Free |
| **Total** | **~$40–65/mo** |

The Pi itself costs < $5/year in electricity.
