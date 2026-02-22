#!/usr/bin/env bash
#
# weekly-review.sh — Automated weekly review for your OpenClaw agent.
#
# Run this ON YOUR LAPTOP. It automates the review checklist:
#   1. Sync logs from the Pi
#   2. Check config drift (SOUL.md, MEMORY.md, AGENTS.md, TOOLS.md)
#   3. Audit the 1Password read-write vault
#   4. Check service health on the Pi
#   5. Print manual check reminders
#
# Usage:
#   ./weekly-review.sh               # full review
#   ./weekly-review.sh --help        # show usage
#   ./weekly-review.sh --skip-sync   # skip log sync (if you just ran it)
#
# Configuration (environment variables):
#   CLAWPI_HOST          — Pi hostname or IP       (default: clawpi.local)
#   CLAWPI_USER          — SSH user                (default: openclaw)
#   CLAWPI_LOG_DIR       — Local backup dir        (default: ~/openclaw-logs)
#   CLAWPI_SSH_PORT      — SSH port                (default: 22)
#   CLAWPI_OP_RW_VAULT   — 1P read-write vault     (default: openclaw_write)
#

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
PI_HOST="${CLAWPI_HOST:-clawpi.local}"
PI_USER="${CLAWPI_USER:-openclaw}"
LOCAL_DIR="${CLAWPI_LOG_DIR:-$HOME/openclaw-logs}"
SSH_PORT="${CLAWPI_SSH_PORT:-22}"
OP_RW_VAULT="${CLAWPI_OP_RW_VAULT:-openclaw_write}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_SYNC=false

# Config files to track for drift
CONFIG_FILES=("SOUL.md" "MEMORY.md" "AGENTS.md" "TOOLS.md")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

ssh_cmd() {
    ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
        "$PI_USER@$PI_HOST" "$@"
}

# ── Argument handling ─────────────────────────────────────────────
case "${1:-}" in
    --skip-sync)
        SKIP_SYNC=true
        ;;
    --help|-h)
        echo "Usage: $0 [--skip-sync]"
        echo ""
        echo "Automated weekly review for your OpenClaw agent."
        echo ""
        echo "  (no args)      Full review (sync logs, check drift, audit vault, health check)"
        echo "  --skip-sync    Skip log sync (useful if you just ran backup-logs.sh)"
        echo ""
        echo "Environment:"
        echo "  CLAWPI_HOST=$PI_HOST"
        echo "  CLAWPI_USER=$PI_USER"
        echo "  CLAWPI_LOG_DIR=$LOCAL_DIR"
        echo "  CLAWPI_SSH_PORT=$SSH_PORT"
        echo "  CLAWPI_OP_RW_VAULT=$OP_RW_VAULT"
        exit 0
        ;;
    "")
        ;;
    *)
        error "Unknown option: $1"
        echo "Run '$0 --help' for usage."
        exit 1
        ;;
esac

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              OpenClaw Weekly Review                      ║"
echo "║              $(date '+%Y-%m-%d %H:%M')                             ║"
echo "╚══════════════════════════════════════════════════════════╝"

# ── Step 1: Sync logs ─────────────────────────────────────────────
section "1. Log Sync"

if [[ "$SKIP_SYNC" == true ]]; then
    info "Skipping log sync (--skip-sync)."
else
    if [[ -x "$SCRIPT_DIR/backup-logs.sh" ]]; then
        "$SCRIPT_DIR/backup-logs.sh"
    else
        warn "backup-logs.sh not found at $SCRIPT_DIR/backup-logs.sh"
        warn "Run it manually: ./scripts/backup-logs.sh"
    fi
fi

# ── Step 2: Config drift ─────────────────────────────────────────
section "2. Config Drift Check"

# Find the workspace directory in the local backup
WORKSPACE_DIR=""
if [[ -d "$LOCAL_DIR" ]]; then
    WORKSPACE_DIR=$(find "$LOCAL_DIR" -path "*/workspaces/*" -name "SOUL.md" -type f 2>/dev/null \
        | head -1 | xargs dirname 2>/dev/null || echo "")
fi

if [[ -z "$WORKSPACE_DIR" ]]; then
    warn "No workspace found in $LOCAL_DIR — can't check config drift."
    warn "Make sure backup-logs.sh has run at least once."
else
    info "Workspace: $WORKSPACE_DIR"

    # Look for timestamped backup snapshots (created by install-openclaw.sh)
    for config_file in "${CONFIG_FILES[@]}"; do
        current="$WORKSPACE_DIR/$config_file"
        if [[ ! -f "$current" ]]; then
            warn "$config_file — not found in workspace"
            continue
        fi

        # Check for .bak files (created by install script on re-runs)
        latest_bak=$(ls -t "$WORKSPACE_DIR/${config_file}.bak."* 2>/dev/null | head -1 || echo "")

        if [[ -n "$latest_bak" ]]; then
            if diff -q "$latest_bak" "$current" &>/dev/null; then
                info "$config_file — no changes since last backup"
            else
                warn "$config_file — CHANGED since $(basename "$latest_bak" | sed 's/.*\.bak\.//' | xargs -I{} date -r {} '+%Y-%m-%d' 2>/dev/null || echo 'last backup')"
                echo "  Changes:"
                diff --color=auto -u "$latest_bak" "$current" | head -20 || true
                echo ""
            fi
        else
            # No backup to compare — show file modification time
            mod_time=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$current" 2>/dev/null || \
                       stat -c '%y' "$current" 2>/dev/null | cut -d. -f1 || echo "unknown")
            info "$config_file — last modified: $mod_time (no prior backup to diff)"
        fi
    done
fi

# ── Step 3: 1Password vault audit ────────────────────────────────
section "3. 1Password Read-Write Vault Audit"

if command -v op &>/dev/null; then
    info "Checking vault: $OP_RW_VAULT"
    if op vault get "$OP_RW_VAULT" &>/dev/null; then
        ITEMS=$(op item list --vault "$OP_RW_VAULT" --format=json 2>/dev/null || echo "[]")
        ITEM_COUNT=$(echo "$ITEMS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")

        if [[ "$ITEM_COUNT" == "0" ]]; then
            info "Vault is empty — the bot hasn't stored anything yet."
        else
            warn "Bot has $ITEM_COUNT item(s) in $OP_RW_VAULT:"
            op item list --vault "$OP_RW_VAULT"
            echo ""
            info "Review these items to confirm they're expected."
        fi
    else
        warn "Vault '$OP_RW_VAULT' not accessible. Check your 1Password login or vault name."
    fi
else
    warn "1Password CLI not installed on this machine — skipping vault audit."
    warn "Install: https://developer.1password.com/docs/cli/get-started/"
fi

# ── Step 4: Service health ────────────────────────────────────────
section "4. Service Health"

info "Connecting to $PI_HOST..."
if ssh -p "$SSH_PORT" -o ConnectTimeout=5 -o BatchMode=yes "$PI_USER@$PI_HOST" true 2>/dev/null; then
    echo "Service status:"
    ssh_cmd "systemctl --user status openclaw 2>/dev/null | head -15 || echo '  Service not found.'"
    echo ""

    echo "Disk usage:"
    ssh_cmd "df -h / | tail -1"
    echo ""

    echo "CPU temperature:"
    ssh_cmd "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf \"  %.1f°C\n\", \$1/1000}' || echo '  (not available)'"
    echo ""

    echo "Memory:"
    ssh_cmd "free -h | head -2"
    echo ""

    echo "Uptime:"
    ssh_cmd "uptime"
else
    error "Cannot reach $PI_HOST — is it powered on?"
fi

# ── Step 5: Manual check reminders ────────────────────────────────
section "5. Manual Checks (Cannot Be Automated)"

echo -e "  ${BOLD}[ ]${NC} Review Privacy.com transaction history"
echo -e "      → https://privacy.com/home"
echo ""
echo -e "  ${BOLD}[ ]${NC} Review Twilio usage and charges"
echo -e "      → https://console.twilio.com/us1/billing/manage-billing/billing-history"
echo ""
echo -e "  ${BOLD}[ ]${NC} Check for OpenClaw updates / security advisories"
echo -e "      → npm outdated -g openclaw"
echo ""
echo -e "  ${BOLD}[ ]${NC} Rotate API keys if anything looks off"
echo -e "      → Update in 1Password, then restart service: systemctl --user restart openclaw"
echo ""
echo -e "  ${BOLD}[ ]${NC} Review SOUL.md and MEMORY.md for unexpected changes (see drift check above)"
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Weekly review complete.                                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
