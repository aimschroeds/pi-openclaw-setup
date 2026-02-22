#!/usr/bin/env bash
#
# harden-pi.sh — Harden a fresh Raspberry Pi OS Lite install for running OpenClaw.
#
# Run this as the default 'pi' user over SSH. It will:
#   1. Update all packages
#   2. Set hostname and timezone
#   3. Create a dedicated 'openclaw' user
#   4. Lock down SSH (key-only, no root login)
#   5. Set up UFW firewall (SSH only)
#   6. Enable automatic security updates
#   7. Install Docker (for sandboxed browser/skills)
#
# Usage:
#   ssh pi@raspberrypi.local 'bash -s' < harden-pi.sh
#   — or —
#   scp harden-pi.sh pi@raspberrypi.local:~ && ssh pi@raspberrypi.local './harden-pi.sh'
#

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
HOSTNAME="${CLAWPI_HOSTNAME:-clawpi}"
TIMEZONE="${CLAWPI_TIMEZONE:-America/New_York}"
OPENCLAW_USER="${CLAWPI_USER:-openclaw}"
SSH_PORT="${CLAWPI_SSH_PORT:-22}"

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
    error "Don't run this as root. Run as the default 'pi' user — it uses sudo where needed."
    exit 1
fi

if ! command -v sudo &>/dev/null; then
    error "sudo not found. This script requires sudo."
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        Raspberry Pi Hardening for OpenClaw              ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Hostname:  $HOSTNAME"
echo "║  Timezone:  $TIMEZONE"
echo "║  New user:  $OPENCLAW_USER"
echo "║  SSH port:  $SSH_PORT"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Override defaults with environment variables:"
echo "  CLAWPI_HOSTNAME, CLAWPI_TIMEZONE, CLAWPI_USER, CLAWPI_SSH_PORT"
echo ""
read -rp "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Step 1: Update everything ──────────────────────────────────────
info "Updating system packages..."
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y

# ── Step 2: Hostname and timezone ──────────────────────────────────
info "Setting hostname to '$HOSTNAME'..."
sudo hostnamectl set-hostname "$HOSTNAME"

# Update /etc/hosts so hostname resolves locally
if ! grep -q "$HOSTNAME" /etc/hosts; then
    sudo sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
fi

info "Setting timezone to '$TIMEZONE'..."
sudo timedatectl set-timezone "$TIMEZONE"

# ── Step 3: Create dedicated openclaw user ─────────────────────────
if id "$OPENCLAW_USER" &>/dev/null; then
    warn "User '$OPENCLAW_USER' already exists — skipping creation."
else
    info "Creating user '$OPENCLAW_USER'..."
    sudo adduser --disabled-password --gecos "OpenClaw Agent" "$OPENCLAW_USER"
fi

# ── Step 4: SSH lockdown ──────────────────────────────────────────
info "Hardening SSH configuration..."

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_HARDENING="/etc/ssh/sshd_config.d/99-openclaw-hardening.conf"

sudo tee "$SSHD_HARDENING" > /dev/null << EOF
# OpenClaw Pi hardening — $(date -I)
Port $SSH_PORT
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowTcpForwarding yes
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Verify the current user has an SSH key before we lock password auth
if [[ ! -f "$HOME/.ssh/authorized_keys" ]] || [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
    warn "⚠️  No SSH key found for user '$(whoami)'!"
    warn "You will be LOCKED OUT if you restart SSH now."
    warn "Run this from your laptop first:  ssh-copy-id $(whoami)@$(hostname).local"
    read -rp "Continue anyway? (only if you know what you're doing) [y/N] " ssh_confirm
    [[ "$ssh_confirm" =~ ^[Yy]$ ]] || { echo "Aborted. Add your SSH key first."; exit 1; }
fi

# Copy the current user's authorized_keys to the openclaw user
info "Copying SSH keys to '$OPENCLAW_USER' user..."
sudo mkdir -p "/home/$OPENCLAW_USER/.ssh"
sudo cp "$HOME/.ssh/authorized_keys" "/home/$OPENCLAW_USER/.ssh/authorized_keys" 2>/dev/null || true
sudo chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER/.ssh"
sudo chmod 700 "/home/$OPENCLAW_USER/.ssh"
sudo chmod 600 "/home/$OPENCLAW_USER/.ssh/authorized_keys" 2>/dev/null || true

info "Restarting SSH daemon..."
sudo systemctl restart sshd

# ── Step 5: Firewall ──────────────────────────────────────────────
info "Installing and configuring UFW firewall..."
sudo apt install -y ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (on configured port)
sudo ufw allow "$SSH_PORT/tcp" comment "SSH"

# Do NOT open port 18789 — access Gateway via SSH tunnel only

sudo ufw --force enable
info "Firewall status:"
sudo ufw status verbose

# ── Step 6: Automatic security updates ────────────────────────────
info "Enabling automatic security updates..."
sudo apt install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# ── Step 7: Install Docker (for sandbox mode) ─────────────────────
info "Installing Docker..."
if command -v docker &>/dev/null; then
    warn "Docker already installed — skipping."
else
    curl -fsSL https://get.docker.com | sudo bash
fi

# Give openclaw user Docker access
sudo usermod -aG docker "$OPENCLAW_USER"
info "Docker installed. User '$OPENCLAW_USER' added to docker group."

# ── Step 8: Basic resource limits for the openclaw user ───────────
info "Setting resource limits for '$OPENCLAW_USER'..."
sudo tee /etc/security/limits.d/openclaw.conf > /dev/null << EOF
# Prevent the openclaw user from consuming all system resources
$OPENCLAW_USER  soft  nofile   4096
$OPENCLAW_USER  hard  nofile   8192
$OPENCLAW_USER  soft  nproc    256
$OPENCLAW_USER  hard  nproc    512
EOF

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ Hardening complete!                                  ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║                                                          ║"
echo "║  Next steps:                                             ║"
echo "║                                                          ║"
echo "║  1. From your laptop, verify SSH to both users:          ║"
echo "║     ssh pi@$HOSTNAME.local"
echo "║     ssh $OPENCLAW_USER@$HOSTNAME.local"
echo "║                                                          ║"
echo "║  2. Run install-openclaw.sh as the '$OPENCLAW_USER' user ║"
echo "║                                                          ║"
echo "║  3. Access Gateway UI via SSH tunnel:                    ║"
echo "║     ssh -L 18789:127.0.0.1:18789 $OPENCLAW_USER@$HOSTNAME.local"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
