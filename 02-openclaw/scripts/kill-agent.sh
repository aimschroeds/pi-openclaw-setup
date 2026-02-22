#!/usr/bin/env bash
#
# kill-agent.sh — Emergency stop for OpenClaw.
#
# Multiple escalation levels. Run from your laptop.
#
# Usage:
#   ./kill-agent.sh              # Stop the OpenClaw service (graceful)
#   ./kill-agent.sh --hard       # Kill all OpenClaw processes
#   ./kill-agent.sh --shutdown   # Shut down the entire Pi
#   ./kill-agent.sh --status     # Check if agent is running
#
# Configuration (environment variables):
#   CLAWPI_HOST      — Pi hostname or IP    (default: clawpi.local)
#   CLAWPI_USER      — SSH user             (default: openclaw)
#   CLAWPI_SSH_PORT  — SSH port             (default: 22)
#

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
PI_HOST="${CLAWPI_HOST:-clawpi.local}"
PI_USER="${CLAWPI_USER:-openclaw}"
SSH_PORT="${CLAWPI_SSH_PORT:-22}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

ssh_cmd() {
    ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
        "$PI_USER@$PI_HOST" "$@"
}

ssh_cmd_sudo() {
    # For commands that need the 'pi' user with sudo
    ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
        "pi@$PI_HOST" "$@"
}

# ── Status check ──────────────────────────────────────────────────
check_status() {
    info "Checking OpenClaw status on $PI_HOST..."
    echo ""

    echo "Service status:"
    ssh_cmd "systemctl --user status openclaw 2>/dev/null || echo '  Service not found or not running.'"
    echo ""

    echo "OpenClaw processes:"
    ssh_cmd "pgrep -a -u \$(whoami) -f openclaw 2>/dev/null || echo '  No OpenClaw processes found.'"
    echo ""

    echo "Node.js processes:"
    ssh_cmd "pgrep -a -u \$(whoami) node 2>/dev/null || echo '  No Node.js processes found.'"
    echo ""

    echo "Port 18789:"
    ssh_cmd "ss -tlnp 2>/dev/null | grep 18789 || echo '  Port 18789 not listening.'"
}

# ── Graceful stop ─────────────────────────────────────────────────
graceful_stop() {
    info "Stopping OpenClaw service gracefully..."
    ssh_cmd "systemctl --user stop openclaw 2>/dev/null && echo 'Service stopped.' || echo 'Service was not running.'"

    # Verify
    sleep 2
    if ssh_cmd "pgrep -u \$(whoami) -f openclaw" &>/dev/null; then
        warn "Some OpenClaw processes still running."
        warn "Use --hard to force-kill all processes."
    else
        info "OpenClaw stopped successfully."
    fi
}

# ── Hard kill ─────────────────────────────────────────────────────
hard_kill() {
    warn "Force-killing ALL OpenClaw and Node.js processes..."
    read -rp "Are you sure? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

    ssh_cmd "systemctl --user stop openclaw 2>/dev/null || true"
    ssh_cmd "pkill -u \$(whoami) -f openclaw 2>/dev/null || true"
    ssh_cmd "pkill -u \$(whoami) node 2>/dev/null || true"

    sleep 2
    if ssh_cmd "pgrep -u \$(whoami) node" &>/dev/null; then
        warn "Processes still alive. Sending SIGKILL..."
        ssh_cmd "pkill -9 -u \$(whoami) -f openclaw 2>/dev/null || true"
        ssh_cmd "pkill -9 -u \$(whoami) node 2>/dev/null || true"
    fi

    info "All OpenClaw processes killed."
}

# ── Full shutdown ─────────────────────────────────────────────────
full_shutdown() {
    error "This will SHUT DOWN the entire Raspberry Pi."
    read -rp "Are you sure? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

    info "Shutting down $PI_HOST..."
    ssh_cmd_sudo "sudo shutdown -h now" || true
    info "Shutdown command sent. The Pi will power off in a few seconds."
    info "You'll need physical access to turn it back on."
}

# ── Main ──────────────────────────────────────────────────────────
case "${1:-}" in
    --status|-s)
        check_status
        ;;
    --hard|-f)
        hard_kill
        ;;
    --shutdown)
        full_shutdown
        ;;
    --help|-h)
        echo "Usage: $0 [--status | --hard | --shutdown]"
        echo ""
        echo "Emergency stop for OpenClaw agent on your Pi."
        echo ""
        echo "  (no args)     Graceful stop — stop the systemd service"
        echo "  --status, -s  Check if the agent is running"
        echo "  --hard, -f    Kill ALL OpenClaw/Node processes (SIGTERM then SIGKILL)"
        echo "  --shutdown    Shut down the entire Raspberry Pi"
        echo ""
        echo "Environment:"
        echo "  CLAWPI_HOST=$PI_HOST"
        echo "  CLAWPI_USER=$PI_USER"
        echo "  CLAWPI_SSH_PORT=$SSH_PORT"
        exit 0
        ;;
    "")
        graceful_stop
        ;;
    *)
        error "Unknown option: $1"
        echo "Run '$0 --help' for usage."
        exit 1
        ;;
esac
