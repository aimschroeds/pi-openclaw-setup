#!/usr/bin/env bash
#
# backup-logs.sh — Sync OpenClaw logs from the Pi to your local machine.
#
# Run this ON YOUR LAPTOP (not on the Pi). It rsyncs the workspace data
# to a local directory so you can review what the agent has been doing.
#
# Usage:
#   ./backup-logs.sh                          # one-time sync
#   ./backup-logs.sh --install-cron           # install hourly cron job
#   ./backup-logs.sh --uninstall-cron         # remove cron job
#
# Configuration (environment variables):
#   CLAWPI_HOST      — Pi hostname or IP    (default: clawpi.local)
#   CLAWPI_USER      — SSH user             (default: openclaw)
#   CLAWPI_LOG_DIR   — Local backup dir     (default: ~/openclaw-logs)
#   CLAWPI_SSH_PORT  — SSH port             (default: 22)
#

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
PI_HOST="${CLAWPI_HOST:-clawpi.local}"
PI_USER="${CLAWPI_USER:-openclaw}"
LOCAL_DIR="${CLAWPI_LOG_DIR:-$HOME/openclaw-logs}"
SSH_PORT="${CLAWPI_SSH_PORT:-22}"

REMOTE_PATH="/home/$PI_USER/.openclaw/"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
CRON_TAG="openclaw-log-backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Cron management ───────────────────────────────────────────────
install_cron() {
    # Remove existing entry if any
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - 2>/dev/null || true

    # Add hourly sync
    (crontab -l 2>/dev/null; echo "0 * * * * $SCRIPT_PATH # $CRON_TAG") | crontab -
    info "Cron job installed — logs will sync every hour."
    info "View with: crontab -l"
    exit 0
}

uninstall_cron() {
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - 2>/dev/null || true
    info "Cron job removed."
    exit 0
}

# ── Argument handling ─────────────────────────────────────────────
case "${1:-}" in
    --install-cron)   install_cron ;;
    --uninstall-cron) uninstall_cron ;;
    --help|-h)
        echo "Usage: $0 [--install-cron | --uninstall-cron]"
        echo ""
        echo "Syncs OpenClaw logs from your Pi to your laptop."
        echo "Run without arguments for a one-time sync."
        exit 0
        ;;
esac

# ── Pre-flight ────────────────────────────────────────────────────
if ! command -v rsync &>/dev/null; then
    error "rsync not found. Install it: brew install rsync (macOS) / apt install rsync (Linux)"
    exit 1
fi

# Create local backup directory
mkdir -p "$LOCAL_DIR"

# ── Sync ──────────────────────────────────────────────────────────
info "Syncing logs from $PI_USER@$PI_HOST..."
info "  Remote: $REMOTE_PATH"
info "  Local:  $LOCAL_DIR/"

rsync -az \
    --progress \
    -e "ssh -p $SSH_PORT -o ConnectTimeout=10" \
    --exclude='node_modules/' \
    --exclude='*.sock' \
    --exclude='*.pid' \
    "$PI_USER@$PI_HOST:$REMOTE_PATH" \
    "$LOCAL_DIR/"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
info "Sync complete at $TIMESTAMP"
info "Logs saved to: $LOCAL_DIR/"

# ── Quick summary ─────────────────────────────────────────────────
echo ""
echo "Recent activity:"
# Show most recently modified files (last 24h)
find "$LOCAL_DIR" -type f -name "*.md" -mmin -1440 -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn \
    | head -10 \
    | while read -r _ filepath; do
        echo "  $(stat -c '%y' "$filepath" 2>/dev/null | cut -d. -f1)  $filepath"
    done || echo "  (no recent Markdown files found)"
