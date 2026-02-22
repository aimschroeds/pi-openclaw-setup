#!/usr/bin/env bash
#
# install-openclaw.sh — Install OpenClaw on a hardened Raspberry Pi.
#
# Run this as the 'openclaw' user (created by harden-pi.sh).
#
# It will:
#   1. Install Node.js 22 via nvm
#   2. Install OpenClaw globally
#   3. Run onboarding (interactive — you enter API keys etc.)
#   4. Apply secure defaults (loopback binding, no auto-install)
#   5. Copy config templates (SOUL.md, HEARTBEAT.md, etc.)
#   6. Install as a systemd user service (auto-starts on boot)
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

# ── Step 3: Run onboarding ────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  The onboarding wizard will now run interactively.      ║"
echo "║                                                          ║"
echo "║  Key settings to choose:                                 ║"
echo "║    • Gateway host: 127.0.0.1 (loopback only!)          ║"
echo "║    • Gateway port: 18789 (default)                      ║"
echo "║    • LLM provider: your choice (have API key ready)     ║"
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
