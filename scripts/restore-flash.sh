#!/usr/bin/env bash
#
# restore-flash.sh — Restore a previously backed-up flash image to a Tufty 2350.
#
# The device must be in BOOTSEL mode before running this script.
# Hold BOOT, press RESET, release both — the Tufty appears as a USB drive.
#
# Usage:
#   ./scripts/restore-flash.sh backups/tufty-backup-20250610-143022.uf2
#   ./scripts/restore-flash.sh backups/tufty-backup-20250610-143022.bin
#   ./scripts/restore-flash.sh --list
#

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BACKUP_DIR="backups"
FLASH_START="0x10000000"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] BACKUP_FILE

Restore a flash backup to the Tufty 2350.

Arguments:
  BACKUP_FILE     Path to .uf2 or .bin backup file

Options:
  --list          List available backups in the $BACKUP_DIR/ directory
  --no-reboot     Do not reboot after flashing
  -h              Show this help message

The device must be in BOOTSEL mode (hold BOOT, press RESET, release both).

Supports both formats:
  .uf2   Restored with: picotool load -v <file>
  .bin   Restored with: picotool load -v -t bin <file> -o $FLASH_START

Examples:
  $(basename "$0") backups/tufty-backup-20250610-143022.uf2
  $(basename "$0") backups/factory.bin
  $(basename "$0") --list
EOF
    exit 0
}

info()  { echo -e "\033[0;32m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

require_picotool() {
    if ! command -v picotool &>/dev/null; then
        error "picotool not found. Install from https://github.com/raspberrypi/picotool"
    fi
}

check_device() {
    if ! picotool info &>/dev/null; then
        error "No device found. Put the Tufty in BOOTSEL mode: hold BOOT, press RESET, release both."
    fi
}

list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        info "No $BACKUP_DIR/ directory found. No backups have been created yet."
        info "Create one with: ./scripts/backup-flash.sh"
        exit 0
    fi

    local count
    count=$(find "$BACKUP_DIR" -maxdepth 1 \( -name "*.uf2" -o -name "*.bin" \) 2>/dev/null | wc -l | tr -d ' ')

    if [ "$count" -eq 0 ]; then
        info "No backup files found in $BACKUP_DIR/"
        info "Create one with: ./scripts/backup-flash.sh"
        exit 0
    fi

    info "Available backups in $BACKUP_DIR/:"
    echo ""
    ls -lhS "$BACKUP_DIR"/*.uf2 "$BACKUP_DIR"/*.bin 2>/dev/null | while read -r line; do
        echo "  $line"
    done
    echo ""
    info "Restore with: ./scripts/restore-flash.sh $BACKUP_DIR/<filename>"
    exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

NO_REBOOT=false
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)       list_backups ;;
        --no-reboot)  NO_REBOOT=true; shift ;;
        -h|--help)    usage ;;
        -*)           error "Unknown option: $1 (see -h for usage)" ;;
        *)            BACKUP_FILE="$1"; shift ;;
    esac
done

if [ -z "$BACKUP_FILE" ]; then
    error "No backup file specified. Usage: $(basename "$0") BACKUP_FILE
  Run '$(basename "$0") --list' to see available backups."
fi

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

require_picotool

if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
fi

FILESIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
EXTENSION="${BACKUP_FILE##*.}"

case "$EXTENSION" in
    uf2|UF2) FORMAT="uf2" ;;
    bin|BIN) FORMAT="bin" ;;
    *)
        warn "Unrecognized extension '.$EXTENSION'. Treating as raw binary."
        FORMAT="bin"
        ;;
esac

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

info "Checking for device in BOOTSEL mode..."
check_device
info "Device detected."
echo ""

info "Restoring backup: $BACKUP_FILE ($FILESIZE bytes, $FORMAT format)"
echo ""

if [ "$FORMAT" = "uf2" ]; then
    picotool load -v "$BACKUP_FILE"
else
    picotool load -v -t bin "$BACKUP_FILE" -o "$FLASH_START"
fi

echo ""

if ! $NO_REBOOT; then
    info "Rebooting device..."
    picotool reboot
    echo ""
fi

info "=== Restore complete ==="
info "The device should now be running the backed-up firmware."
