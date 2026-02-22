# OpenClaw Pi Sandbox

Run OpenClaw on a Raspberry Pi with sandboxed accounts, capped finances, and kill-switch controls — so the AI agent can act on your behalf without blowing up your life.

## Philosophy

Give the agent **real capabilities** but inside a **blast radius you control**:

- Every account is net-new and disposable — nothing touches your real identity
- Financial exposure is hard-capped by a prepaid card with no overdraft
- The Pi is isolated on your network and hardened at the OS level
- You can kill the agent instantly via SSH or physical power-off
- Every action is logged and auditable

---

## What You Do vs What the Agent Does

Understanding this split is critical. OpenClaw is designed to evolve, but it needs you to set the initial boundaries.

### You Must Do (Manual, One-Time)

| Task | Why |
|---|---|
| Flash Pi OS and harden the system | The agent doesn't exist yet |
| Create all burner accounts (email, phone, messaging) | Requires human identity verification (CAPTCHAs, phone verification) |
| Set up the prepaid payment card | Requires human identity and a bank account |
| Install Node.js and OpenClaw | System-level install before the agent is running |
| Write initial SOUL.md | Defines who the agent IS — it can't bootstrap its own personality from nothing |
| Write initial AGENTS.md | The operating contract and safety rules — these must come from you |
| Write initial USER.md | Who you are — the agent doesn't know you yet |
| Write initial TOOLS.md | Which tools are enabled/disabled — security boundary you control |
| Write initial HEARTBEAT.md | What to check proactively — the agent shouldn't decide this itself at first |
| Connect channels (Telegram bot, email IMAP) | Requires API keys and authentication you set up in Phase 0 |
| Set up the kill switch and log backups | External monitoring the agent can't self-provision |
| Enter API keys (Anthropic, Brave, etc.) | Secrets you manage |

### The Agent Does (Autonomous, Over Time)

| Task | How |
|---|---|
| Update SOUL.md as it learns who it is | It will ask permission before modifying its soul |
| Update MEMORY.md with facts about you | Learned from conversations — your preferences, patterns, context |
| Write daily logs to memory/YYYY-MM-DD.md | Automatic conversation summaries |
| Compact old memories | Keeps MEMORY.md from growing forever — drops noise, keeps facts |
| Update USER.md preferences section | As it learns what you like (bullet points vs paragraphs, timing, etc.) |
| Run heartbeat checks | Reads HEARTBEAT.md every 30 min, reports or stays quiet |
| Draft email replies | Prepares responses for your approval |
| Send messages on approved channels | Within the rate limits you set |
| Search the web and summarize findings | Using Brave Search API |
| Schedule reminders and cron jobs | Within the 5-job limit |

### Key Insight

**You build the cage. The agent furnishes the room.**

The initial config files (SOUL, AGENTS, USER, TOOLS, HEARTBEAT) are your guardrails. Once those are in place, the agent operates autonomously within them and gradually learns to be more useful. You expand its permissions over time by editing those files.

---

## Config File Setup Order

OpenClaw reads 8 core Markdown files from your workspace. Here's the order to configure them and what each does:

| Order | File | What It Does | Who Writes It |
|---|---|---|---|
| 1 | **AGENTS.md** | Operating contract — priorities, boundaries, safety rules, memory policy | You (initial), you (ongoing) |
| 2 | **SOUL.md** | Personality — voice, values, behavioral constraints | You (initial), agent (evolves with permission) |
| 3 | **USER.md** | About you — name, timezone, preferences, communication style | You (initial), agent (learns preferences) |
| 4 | **TOOLS.md** | What tools are enabled/disabled and rate limits | You (always — security boundary) |
| 5 | **IDENTITY.md** | Structured identity (name, role, avatar) — optional, the onboarding wizard fills this | Agent or you |
| 6 | **HEARTBEAT.md** | Proactive check list — what to monitor every 30 min | You (initial), you (expand over time) |
| 7 | **MEMORY.md** | Long-term memory — facts, compressed history | Agent (automatic) |
| 8 | **BOOTSTRAP.md** | First-run interview script — skip after initial setup | Pre-built, one-time use |

**First message to your agent:** "Hey, let's get you set up. Read BOOTSTRAP.md and walk me through it." This triggers the onboarding conversation where the agent fills in IDENTITY.md and starts learning about you.

**After bootstrap:** Edit AGENTS.md, SOUL.md, and HEARTBEAT.md yourself. Don't let the agent write its own safety rules.

### SOUL.md vs HEARTBEAT.md — Which First?

**SOUL.md first.** It loads into the system prompt on every session start. Without it, the agent has no personality, no boundaries, no sense of its sandboxed environment. HEARTBEAT.md is only read during heartbeat cycles (every 30 min), so it can come second.

The config templates in `config/` are pre-written with sensible defaults for a Pi sandbox. The `install-openclaw.sh` script copies them into the workspace automatically.

---

## Phase 0: Sandboxed Account Setup (Do This First, From Your Laptop)

Set all of this up **before** the Pi is online. Use a password manager (1Password / Bitwarden) to store everything.

### 0.1 — Burner Email

| Option | Notes |
|---|---|
| ProtonMail (free tier) | End-to-end encrypted, no phone required to sign up |
| Gmail | Requires phone verification — use the burner number below |
| Tutanota | No phone required, EU-based |

Pick one. This email anchors every other account.

### 0.2 — Burner Phone Number

| Option | Cost | Notes |
|---|---|---|
| Google Voice | Free | Needs an existing Google account; US only. Can send/receive SMS and calls |
| Twilio | ~$1.50/mo + per-message | Programmable — OpenClaw can use the API directly for SMS/voice |
| MySudo | $0.99–$14.99/mo | Up to 9 separate phone lines, built for privacy |
| Prepaid SIM (Mint, Ultra, etc.) | $15–30/mo | Physical number, works everywhere. Pop it in an old phone as a dedicated 2FA device |

**Recommendation:** Twilio for programmable SMS/voice (the agent can use the API), plus a cheap prepaid SIM as a backup for accounts that demand a "real" phone number.

### 0.3 — Burner Messaging Accounts

Register these with the burner email + burner phone:

| Platform | Registration needs | OpenClaw channel |
|---|---|---|
| Telegram | Phone number | Built-in Telegram channel |
| WhatsApp | Phone number (prepaid SIM) | Built-in WhatsApp channel |
| Signal | Phone number | Built-in Signal channel |
| Slack | Email (create a new workspace) | Built-in Slack channel |

**Important:** Do NOT connect your personal accounts. The whole point is isolation.

### 0.4 — Prepaid Payment Card

This is the critical financial guardrail.

| Option | Why |
|---|---|
| **Privacy.com** | Virtual cards with per-card spending limits, pause/close instantly. Free tier gives 12 cards/month. **Best option.** |
| Revolut (prepaid mode) | Virtual + physical cards, set spending limits per card |
| Prepaid Visa/Mastercard (store-bought) | No overdraft by design. Load $50–100. When it's empty, it's empty |
| Cash App card | Debit-only, easy to lock/unlock from phone |

**Recommendation:** Privacy.com — create a dedicated virtual card for the agent with a **$50/month cap**. You can lower or pause it instantly from your phone.

**Rules:**
- No linked bank account with overdraft — ever
- Start with $20–50 loaded, raise only after you trust the setup
- Set up transaction alerts to your real phone (so you see every charge)
- Create separate cards for separate services if the agent needs to pay for multiple things

### 0.5 — Summary Checklist

```
[ ] Burner email created (ProtonMail / Gmail / Tutanota)
[ ] Burner phone number active (Twilio / prepaid SIM)
[ ] Telegram account on burner phone
[ ] WhatsApp account on burner phone
[ ] Signal account on burner phone
[ ] Discord account on burner email
[ ] Privacy.com card created with $50/mo cap
[ ] All credentials stored in password manager
[ ] Transaction alerts enabled to your real phone
```

---

## Phase 1: Raspberry Pi Hardening

Assumes you've already flashed Raspberry Pi OS Lite and can SSH in (see [01-pi-setup](../01-pi-setup/)).

### Automated

```bash
# Copy your SSH key to the Pi first
ssh-copy-id pi@raspberrypi.local

# Then run the hardening script
scp scripts/harden-pi.sh pi@raspberrypi.local:~
ssh pi@raspberrypi.local './harden-pi.sh'
```

The script handles everything: updates, hostname, dedicated `openclaw` user, SSH lockdown, firewall (SSH only), auto security updates, Docker install, and resource limits.

Configure with environment variables before running:

```bash
CLAWPI_HOSTNAME=clawpi CLAWPI_TIMEZONE=America/New_York ssh pi@raspberrypi.local './harden-pi.sh'
```

### What the Script Does (Manual Reference)

1. **Updates** all packages
2. **Sets hostname** to `clawpi` (configurable)
3. **Creates `openclaw` user** — dedicated, no password, copies your SSH key
4. **Locks SSH** — key-only auth, no root login, max 3 attempts
5. **Firewall** — deny all incoming except SSH. Port 18789 (Gateway) is NOT exposed
6. **Auto security updates** via unattended-upgrades
7. **Docker** — installed for browser/skill sandboxing
8. **Resource limits** — prevents openclaw user from consuming all RAM/CPU

**Do NOT expose port 18789 (OpenClaw Gateway) to the network.** Access it via SSH tunnel only:

```bash
# From your laptop — tunnel the Gateway UI to localhost:18789
ssh -L 18789:127.0.0.1:18789 openclaw@clawpi.local
```

---

## Phase 2: Install OpenClaw

### Automated

```bash
# SSH as the openclaw user
ssh openclaw@clawpi.local

# Copy the project to the Pi (from your laptop)
scp -r scripts/ config/ openclaw@clawpi.local:~/openclaw-pi-sandbox/

# Run the install script
ssh openclaw@clawpi.local '~/openclaw-pi-sandbox/scripts/install-openclaw.sh'
```

The script handles: nvm + Node.js 22, OpenClaw install, interactive onboarding wizard, security defaults (loopback binding), copying config templates (SOUL.md, HEARTBEAT.md, etc.), and systemd service setup.

### What the Script Does (Manual Reference)

1. **Installs nvm** and **Node.js 22**
2. **Installs OpenClaw** globally via npm
3. **Runs `openclaw onboard`** — interactive wizard where you:
   - Bind gateway to `127.0.0.1:18789` (loopback only!)
   - Create workspace at `~/.openclaw/`
   - Enter your LLM provider API key (Anthropic/OpenAI)
   - Skip channels for now (we add them in Phase 3)
4. **Enforces loopback binding** — if the gateway is bound to 0.0.0.0, the script fixes it
5. **Copies config templates** from `config/` into the workspace (SOUL.md, HEARTBEAT.md, AGENTS.md, USER.md, TOOLS.md)
6. **Installs systemd service** — auto-starts on boot, runs even when not logged in

### Post-Install: Your First Message

After install, access the Gateway UI:

```bash
ssh -L 18789:127.0.0.1:18789 openclaw@clawpi.local
# Then open http://localhost:18789
```

Send this as your **very first message**:

> "Hey, let's get you set up. Read BOOTSTRAP.md and walk me through it."

This triggers the onboarding conversation where the agent fills in IDENTITY.md and starts learning about you. After that, it will use the SOUL.md, AGENTS.md, and other config files you pre-loaded.

---

## Phase 2.5: 1Password Setup

Secrets (API keys, tokens) are managed via 1Password so they're **never stored on disk in plaintext**. The setup uses two vaults:

| Vault | Purpose | Who manages it |
|---|---|---|
| `openclaw_read` | Credentials you set up (Anthropic key, Twilio, Brave, etc.) | You |
| `openclaw_write` | Items the bot creates/manages on its own | The agent |

### How It Works

1. A **1Password service account token** is stored at `~/.config/op/service-account-token` on the Pi (the only secret on disk)
2. An **env file** at `~/.config/op/env` maps environment variables to `op://` URIs (e.g., `ANTHROPIC_API_KEY=op://openclaw_read/anthropic-api-key/credential`)
3. The systemd service wraps `ExecStart` with **`op run --env-file`**, which resolves the `op://` references at startup and injects real values into the process environment
4. Secrets exist only in memory while the service runs — they're never written to config files

### Setup

The `install-openclaw.sh` script handles this automatically (Step 2.5). It:
- Installs the `op` CLI via the official apt repo
- Prompts for your service account token
- Copies `config/op-env.template` to `~/.config/op/env`
- Creates a systemd override that uses `op run` for secret injection

To set up manually or after install:

```bash
# 1. Create a service account at https://my.1password.com → Developer → Service Accounts
#    Grant it read access to openclaw_read vault and read+write to openclaw_write vault

# 2. Store the token on the Pi
mkdir -p ~/.config/op
echo "YOUR_TOKEN_HERE" > ~/.config/op/service-account-token
chmod 600 ~/.config/op/service-account-token

# 3. Copy and edit the env template
cp config/op-env.template ~/.config/op/env
nano ~/.config/op/env  # uncomment the secrets you need

# 4. Restart the service (the systemd override picks up the new env)
systemctl --user restart openclaw
```

### Template

See `config/op-env.template` for the full list of supported secret references.

---

## Phase 3: Connect Sandboxed Channels

Only connect the burner accounts from Phase 0.

### 3.1 — Telegram (Primary Control Channel)

Telegram is the easiest to set up and a good primary interface:

```bash
# Via the OpenClaw CLI or Gateway UI
# 1. Create a Telegram bot via @BotFather on the burner Telegram account
# 2. Get the bot token
# 3. Add it to OpenClaw config
```

### 3.2 — Email (IMAP/SMTP via Himalaya)

```bash
# Install the himalaya email skill
# Configure with the burner email's IMAP/SMTP credentials
# This lets the agent read and send email as the burner identity
```

### 3.3 — SMS/Voice via Twilio

```bash
# Install the Twilio skill from ClawHub (after vetting — see Phase 5)
# Configure with Twilio Account SID, Auth Token, and burner phone number
# Set rate limits in Twilio dashboard:
#   - Max 10 SMS/hour
#   - Max 5 voice calls/hour
#   - Monthly spend cap: $10
```

### 3.4 — Payments

The agent doesn't get direct card credentials. Instead:

1. Use Privacy.com's API (if available) or configure specific merchant accounts
2. The agent can request purchases, but the actual card number stays in 1Password — not in OpenClaw's config
3. For services that need a card on file: use the capped Privacy.com virtual card

---

## Phase 4: Permission Guardrails

### 4.1 — Config Files (Pre-Written)

The `config/` directory contains ready-to-use templates. The install script copies them into the workspace:

- **`config/SOUL.md`** — Personality, boundaries, sandbox awareness. Includes spending limits, message rate limits, and the "don't act without permission" rules.
- **`config/AGENTS.md`** — Operating contract. Priorities (safety > usefulness > transparency), memory policy, anti-prompt-injection rules.
- **`config/TOOLS.md`** — Shell disabled, browser disabled, cron limited to 5 jobs, ClawHub auto-install disabled, rate limits on all channels.
- **`config/HEARTBEAT.md`** — Check email, calendar, system health every 30 min. Report-only mode for weeks 1-2.
- **`config/USER.md`** — Template for your details. Fill in your name, timezone, and preferences before or after install.

Edit these **before running `install-openclaw.sh`** to customize, or edit them in-place on the Pi at `~/.openclaw/workspaces/*/`.

### 4.3 — Twilio Rate Limits (External Guardrail)

Set these in the Twilio dashboard — the agent can't override them:

- SMS: 10/hour, 50/day
- Voice: 5/hour, 20/day
- Monthly spend: $10 hard cap

### 4.4 — Privacy.com Spending Limits (External Guardrail)

- Per-transaction limit: $10
- Monthly limit: $50
- Pause card from your phone instantly

---

## Phase 5: Skill Vetting (Critical)

**12–20% of ClawHub skills are malicious** (per Cisco security research). Do NOT enable auto-install.

### Rules:
1. **Never** enable ClawHub auto-install (`clawhub.auto_install: false`)
2. **Read the source** of every skill before installing — check the SKILL.md and any TypeScript
3. **Pin versions** — don't auto-update skills
4. **Start with official bundled skills only** — there are 53 of them
5. Only add community skills after reading the code yourself

```yaml
# In workspace config
clawhub:
  auto_install: false
  auto_update: false
```

---

## Phase 6: Monitoring & Kill Switch

### 6.1 — Log Backup (scripts/backup-logs.sh)

Run from your laptop. Syncs the entire `~/.openclaw/` directory to your machine:

```bash
# One-time sync
./scripts/backup-logs.sh

# Install hourly cron job
./scripts/backup-logs.sh --install-cron

# Remove cron job
./scripts/backup-logs.sh --uninstall-cron
```

Configure with environment variables: `CLAWPI_HOST`, `CLAWPI_USER`, `CLAWPI_LOG_DIR`, `CLAWPI_SSH_PORT`.

### 6.2 — Kill Switch (scripts/kill-agent.sh)

Run from your laptop. Multiple escalation levels:

```bash
# Check if agent is running
./scripts/kill-agent.sh --status

# Graceful stop (stop systemd service)
./scripts/kill-agent.sh

# Hard kill (SIGTERM then SIGKILL all Node processes)
./scripts/kill-agent.sh --hard

# Nuclear option (shut down the entire Pi)
./scripts/kill-agent.sh --shutdown
```

### 6.3 — External Kill Switches (Not Script-Dependent)

| Method | Speed | Scope |
|---|---|---|
| `./scripts/kill-agent.sh` | Instant | Stops the agent, keeps Pi running |
| Privacy.com: pause card from phone | Instant | Blocks all payments |
| Twilio: suspend account from dashboard | Instant | Blocks all SMS/voice |
| `./scripts/kill-agent.sh --shutdown` | ~10 seconds | Full Pi shutdown |
| Unplug the Pi | Instant | Nuclear option, no SSH needed |

### 6.4 — Alerts

- **Privacy.com**: Transaction alerts to your real phone (already enabled in Phase 0)
- **Twilio**: Usage alerts when approaching limits
- **HEARTBEAT.md**: The agent reports system health (temp, disk) every 30 min via Telegram

### 6.5 — Weekly Review Routine

Run the automated review script from your laptop:

```bash
# Full review (syncs logs, checks config drift, audits 1P vault, checks Pi health)
./scripts/weekly-review.sh

# Skip log sync if you just ran backup-logs.sh
./scripts/weekly-review.sh --skip-sync
```

The script automates what it can and prints reminders for the rest:

```
Automated:
  ✓ Sync logs from Pi
  ✓ Diff SOUL.md, MEMORY.md, AGENTS.md, TOOLS.md against last backup
  ✓ List items in the 1Password read-write vault (what the bot stored)
  ✓ Check service status, disk usage, CPU temp on the Pi

Manual (script prints reminders):
  [ ] Review Privacy.com transaction history
  [ ] Review Twilio usage and charges
  [ ] Check for OpenClaw updates / security advisories
  [ ] Rotate API keys if anything looks off
```

Configure with env vars: `CLAWPI_HOST`, `CLAWPI_USER`, `CLAWPI_LOG_DIR`, `CLAWPI_SSH_PORT`, `CLAWPI_OP_RW_VAULT`.

---

## Phase 7: Suggested Starting Use Cases

Start small. Don't enable everything at once.

**Week 1 — Read only:**
- Agent can read emails and summarize them via Telegram
- Agent can check news/RSS feeds and brief you

**Week 2 — Low-stakes writes:**
- Agent can draft email replies (you approve before sending)
- Agent can send you Telegram reminders

**Week 3 — Supervised actions:**
- Agent can send emails on your behalf (to contacts you whitelist)
- Agent can send SMS via Twilio (rate-limited)

**Week 4+ — Expand gradually:**
- Payments (with $10/transaction cap)
- Scheduling calls
- More channel integrations

---

## Cost Estimate

| Item | Monthly cost |
|---|---|
| LLM API (Anthropic/OpenAI) | $20–60 depending on usage |
| Twilio (SMS/Voice) | ~$5–15 |
| Privacy.com | Free (capped at $50 spend) |
| Prepaid SIM (optional) | $15–30 |
| ProtonMail | Free |
| **Total** | **~$40–105/mo** (plus whatever you let the agent spend) |

The Pi itself costs nothing to run (< $5/year electricity).

---

## File Structure

```
openclaw-pi-sandbox/
├── README.md                ← this file (full setup plan)
├── config/
│   ├── SOUL.md              ← agent personality and boundaries (→ workspace)
│   ├── HEARTBEAT.md         ← proactive check list (→ workspace)
│   ├── AGENTS.md            ← operating contract and safety rules (→ workspace)
│   ├── USER.md              ← about you — fill in your details (→ workspace)
│   ├── TOOLS.md             ← enabled/disabled tools and rate limits (→ workspace)
│   └── op-env.template      ← 1Password op:// secret references (→ ~/.config/op/env)
├── scripts/
│   ├── harden-pi.sh         ← OS hardening (run as pi user)
│   ├── install-openclaw.sh  ← OpenClaw install + 1P setup + config copy (run as openclaw user)
│   ├── backup-logs.sh       ← sync logs to your laptop (run on laptop)
│   ├── kill-agent.sh        ← emergency stop (run on laptop)
│   └── weekly-review.sh     ← automated weekly review (run on laptop)
└── docs/
    └── account-setup.md     ← detailed account creation walkthrough (TODO)
```

All config files in `config/` are templates. `install-openclaw.sh` copies them into the OpenClaw workspace automatically. Edit the templates before running the install, or edit in-place after.

---

## Security Checklist

```
[ ] Pi firewall enabled, only SSH open
[ ] Gateway bound to 127.0.0.1 (loopback only)
[ ] Dedicated 'openclaw' user (not root, not pi)
[ ] SSH key-only auth, passwords disabled
[ ] All accounts are burner/sandboxed
[ ] No real financial accounts connected
[ ] Prepaid card has hard spending cap, no overdraft
[ ] ClawHub auto-install disabled
[ ] All skills manually vetted before install
[ ] Transaction alerts going to your real phone
[ ] Log sync running
[ ] Kill switch tested and working
[ ] Automatic OS security updates enabled
[ ] 1Password service account token stored with mode 600
[ ] op:// env file has only the secrets the agent needs
[ ] Service account has minimal vault permissions (read-only where possible)
[ ] ~/.config/op/ excluded from log backups (confirmed in rsync)
[ ] 1P read-write vault reviewed weekly (run weekly-review.sh)
```
