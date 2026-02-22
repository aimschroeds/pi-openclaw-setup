#!/usr/bin/env bash
#
# install-openclaw.sh — Install OpenClaw on a hardened Raspberry Pi.
#
# Run this as the 'openclaw' user (created by harden-pi.sh).
#
# It will:
#   1. Install Node.js 22 via nvm
#   2. Install OpenClaw globally
#   2.5. Install 1Password CLI and configure service account token
#   3. Run onboarding (interactive — you enter API keys etc.)
#   4. Apply secure defaults (loopback binding, no auto-install)
#   5. Copy config templates (SOUL.md, HEARTBEAT.md, etc.)
#   6. Install as a systemd user service (with op run for secret injection)
#
# Usage:
#   ssh openclaw@clawpi.local
#   ./install-openclaw.sh
#

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
NODE_VERSION="${CLAWPI_NODE_VERSION:-22}"
OPENCLAW_HOME="$HOME/.openclaw"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Pre-flight checks ─────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    error "Don't run as root. Run as the 'openclaw' user."
    exit 1
fi

if [[ "$(whoami)" != "openclaw" ]]; then
    warn "Expected to run as 'openclaw' user, running as '$(whoami)' instead."
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         OpenClaw Installation for Raspberry Pi          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Install nvm and Node.js ───────────────────────────────
info "Installing nvm..."
if [[ -d "$HOME/.nvm" ]]; then
    warn "nvm already installed — skipping."
else
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

# Load nvm into current shell
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

info "Installing Node.js $NODE_VERSION..."
if command -v node &>/dev/null && node --version | grep -q "^v${NODE_VERSION}"; then
    warn "Node.js $(node --version) already installed — skipping."
else
    nvm install "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
fi

info "Node.js version: $(node --version)"
info "npm version: $(npm --version)"

# ── Step 2: Install OpenClaw ──────────────────────────────────────
info "Installing OpenClaw..."
if command -v openclaw &>/dev/null; then
    warn "OpenClaw already installed. Upgrading to latest..."
fi
npm install -g openclaw@latest --ignore-scripts
info "Running post-install build (skipping optional native addons)..."
OPENCLAW_PKG_DIR="$(npm root -g)/openclaw"
if [[ -d "$OPENCLAW_PKG_DIR" ]]; then
    (cd "$OPENCLAW_PKG_DIR" && npm rebuild --ignore-optional 2>&1) || warn "Some optional native addons failed to build (e.g. Discord opus) — this is OK if you don't use Discord."
else
    warn "Could not find openclaw package dir for rebuild — skipping. OpenClaw should still work."
fi
info "OpenClaw version: $(openclaw --version 2>/dev/null || echo 'installed')"

# ── Step 2.5: 1Password CLI setup ─────────────────────────────────
echo ""
read -rp "Set up 1Password CLI for secret injection? [Y/n] " op_confirm
if [[ ! "$op_confirm" =~ ^[Nn]$ ]]; then
    if command -v op &>/dev/null; then
        warn "1Password CLI already installed — skipping install."
    else
        info "Installing 1Password CLI..."
        # Add the 1Password apt repository and install
        curl -sS https://downloads.1password.com/linux/keys/1password.asc \
            | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
            | sudo tee /etc/apt/sources.list.d/1password-cli.list
        sudo apt-get update -qq && sudo apt-get install -y 1password-cli
        info "1Password CLI version: $(op --version)"
    fi

    # Prompt for service account token
    echo ""
    echo "A 1Password service account token lets the agent fetch secrets at runtime."
    echo "Create one at: https://my.1password.com → Developer → Service Accounts"
    echo ""
    read -rsp "Paste your 1Password service account token (input hidden): " OP_TOKEN
    echo ""

    if [[ -z "$OP_TOKEN" ]]; then
        warn "No token provided — skipping 1Password configuration."
        warn "You can set it up later at ~/.config/op/service-account-token"
    else
        # Store the token securely
        mkdir -p "$HOME/.config/op"
        echo "$OP_TOKEN" > "$HOME/.config/op/service-account-token"
        chmod 600 "$HOME/.config/op/service-account-token"
        info "Token stored at ~/.config/op/service-account-token (mode 600)"

        # Validate the token
        info "Validating token..."
        if OP_SERVICE_ACCOUNT_TOKEN="$OP_TOKEN" op vault list --format=json &>/dev/null; then
            info "Token is valid. Available vaults:"
            OP_SERVICE_ACCOUNT_TOKEN="$OP_TOKEN" op vault list
        else
            warn "Token validation failed. Check that the token is correct and the service account has vault access."
            warn "You can re-run this step later or edit ~/.config/op/service-account-token"
        fi

        # Copy the op:// env template
        OP_ENV_DEST="$HOME/.config/op/env"
        if [[ -f "$CONFIG_DIR/op-env.template" ]]; then
            if [[ -f "$OP_ENV_DEST" ]]; then
                warn "$OP_ENV_DEST already exists — not overwriting."
            else
                cp "$CONFIG_DIR/op-env.template" "$OP_ENV_DEST"
                chmod 600 "$OP_ENV_DEST"
                info "Copied op-env.template → $OP_ENV_DEST"
                info "Edit $OP_ENV_DEST to uncomment the secrets your agent needs."
            fi
        else
            warn "op-env.template not found in config/ — create $OP_ENV_DEST manually."
        fi
    fi
fi

# ── Step 2.7: Gemini CLI setup (OAuth for LLM) ───────────────────
echo ""
info "Setting up Gemini CLI for LLM access..."
info "Google Gemini CLI uses OAuth tied to a \$20/mo Google AI subscription"
info "(flat rate — no per-token billing). The token lasts ~1 year."
echo ""

if command -v gemini &>/dev/null; then
    warn "Gemini CLI already installed — skipping install."
else
    info "Installing Gemini CLI..."
    npm install -g @anthropic-ai/gemini-cli
fi

# Check if auth token exists (gemini stores it in ~/.config/gemini/)
if [[ -d "$HOME/.config/gemini" ]] && ls "$HOME/.config/gemini"/*token* &>/dev/null 2>&1; then
    info "Gemini CLI auth token found — skipping auth."
else
    echo ""
    info "You need to authenticate the Gemini CLI."
    info "This will open a browser (or print a URL to visit) for Google OAuth."
    echo ""
    read -rp "Run 'gemini auth login' now? [Y/n] " gemini_auth_confirm
    if [[ ! "$gemini_auth_confirm" =~ ^[Nn]$ ]]; then
        gemini auth login
    else
        warn "Skipped Gemini auth — run 'gemini auth login' before starting the agent."
    fi
fi

# ── Step 3: Run onboarding ────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  The onboarding wizard will now run interactively.      ║"
echo "║                                                          ║"
echo "║  Key settings to choose:                                 ║"
echo "║    • Gateway host: 127.0.0.1 (loopback only!)          ║"
echo "║    • Gateway port: 18789 (default)                      ║"
echo "║    • LLM provider: select google-gemini-cli             ║"
echo "║      (uses OAuth — no API key needed)                    ║"
echo "║    • Channels: skip for now — we add them later         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
read -rp "Ready to run onboarding? [Y/n] " onboard_confirm
if [[ ! "$onboard_confirm" =~ ^[Nn]$ ]]; then
    openclaw onboard
fi

# ── Step 4: Apply security defaults ──────────────────────────────
info "Applying security defaults..."

# Ensure gateway binds to loopback only
GATEWAY_CONFIG=$(find "$OPENCLAW_HOME" -name "gateway.*" -type f 2>/dev/null | head -1)
if [[ -n "$GATEWAY_CONFIG" ]]; then
    if grep -q "0\.0\.0\.0" "$GATEWAY_CONFIG" 2>/dev/null; then
        warn "Gateway was bound to 0.0.0.0 — changing to 127.0.0.1"
        sed -i 's/0\.0\.0\.0/127.0.0.1/g' "$GATEWAY_CONFIG"
        info "Gateway now bound to loopback only."
    else
        info "Gateway binding looks OK."
    fi
fi

# ── Step 5: Copy config templates ─────────────────────────────────
info "Checking for config templates..."

# Find the workspace directory
WORKSPACE_DIR=$(find "$OPENCLAW_HOME" -name "workspaces" -type d 2>/dev/null | head -1)
if [[ -z "$WORKSPACE_DIR" ]]; then
    WORKSPACE_DIR="$OPENCLAW_HOME/workspaces/default"
    mkdir -p "$WORKSPACE_DIR"
fi

# Find first workspace (or use default)
WORKSPACE=$(find "$WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
if [[ -z "$WORKSPACE" ]]; then
    WORKSPACE="$WORKSPACE_DIR/default"
    mkdir -p "$WORKSPACE"
fi

info "Workspace directory: $WORKSPACE"

# Copy config files if they exist in our config/ directory
if [[ -d "$CONFIG_DIR" ]]; then
    for config_file in "$CONFIG_DIR"/*.md "$CONFIG_DIR"/*.yaml "$CONFIG_DIR"/*.yml; do
        [[ -f "$config_file" ]] || continue
        filename=$(basename "$config_file")
        target="$WORKSPACE/$filename"
        if [[ -f "$target" ]]; then
            warn "$filename already exists in workspace — backing up and replacing."
            cp "$target" "${target}.bak.$(date +%s)"
        fi
        cp "$config_file" "$target"
        info "Copied $filename → workspace"
    done
else
    warn "No config/ directory found next to this script. Skipping template copy."
    warn "You can copy config files manually later."
fi

# ── Step 6: Install systemd service ───────────────────────────────
echo ""
read -rp "Install OpenClaw as a systemd service (auto-start on boot)? [Y/n] " daemon_confirm
if [[ ! "$daemon_confirm" =~ ^[Nn]$ ]]; then
    info "Installing systemd user service..."

    # Enable lingering so the user service runs even when not logged in
    sudo loginctl enable-linger "$(whoami)" 2>/dev/null || true

    openclaw onboard --install-daemon

    # If 1Password is configured, add a systemd override to inject secrets via op run
    TOKEN_FILE="$HOME/.config/op/service-account-token"
    OP_ENV_FILE="$HOME/.config/op/env"
    if [[ -f "$TOKEN_FILE" && -f "$OP_ENV_FILE" ]]; then
        info "Setting up systemd override for 1Password secret injection..."

        OVERRIDE_DIR="$HOME/.config/systemd/user/openclaw-gateway.service.d"
        mkdir -p "$OVERRIDE_DIR"

        # Read the existing ExecStart so we can wrap it with op run
        EXISTING_EXEC=$(systemctl --user show openclaw-gateway.service -p ExecStart --value 2>/dev/null || \
                        systemctl --user show openclaw.service -p ExecStart --value 2>/dev/null || echo "")

        # Determine the actual service unit name
        SERVICE_NAME="openclaw-gateway.service"
        if ! systemctl --user cat "$SERVICE_NAME" &>/dev/null; then
            SERVICE_NAME="openclaw.service"
            OVERRIDE_DIR="$HOME/.config/systemd/user/openclaw.service.d"
            mkdir -p "$OVERRIDE_DIR"
        fi

        cat > "$OVERRIDE_DIR/op.conf" <<OVERRIDE
[Service]
# 1Password secret injection
# Reads the service account token from file, then uses op run to resolve
# op:// references in the env file into real values at startup.
ExecStart=
ExecStart=/bin/bash -c 'export OP_SERVICE_ACCOUNT_TOKEN=\$(cat %h/.config/op/service-account-token) && exec op run --env-file=%h/.config/op/env -- $EXISTING_EXEC'
OVERRIDE

        systemctl --user daemon-reload
        info "Systemd override created at $OVERRIDE_DIR/op.conf"
        info "Secrets from op:// references will be injected at service start."
    else
        info "1Password not configured — service will use env vars directly."
        info "To add 1P later, re-run install or set up the override manually."
    fi

    info "Systemd service installed."
    info "Check status: systemctl --user status openclaw"
    info "View logs:    journalctl --user -u openclaw -f"
fi

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ OpenClaw installed!                                  ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║                                                          ║"
echo "║  Next steps:                                             ║"
echo "║                                                          ║"
echo "║  1. Access the Gateway UI via SSH tunnel:                ║"
echo "║     ssh -L 18789:127.0.0.1:18789 openclaw@clawpi.local  ║"
echo "║     Then open http://localhost:18789 in your browser     ║"
echo "║                                                          ║"
echo "║  2. Review and edit your config files:                   ║"
echo "║     $WORKSPACE/SOUL.md"
echo "║     $WORKSPACE/HEARTBEAT.md"
echo "║     $WORKSPACE/TOOLS.md"
echo "║                                                          ║"
echo "║  3. Connect your first channel (Telegram recommended):   ║"
echo "║     Use the Gateway UI or 'openclaw channel add'         ║"
echo "║                                                          ║"
echo "║  4. Run kill-agent.sh to test the kill switch works!     ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
