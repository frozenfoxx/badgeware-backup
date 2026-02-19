#!/usr/bin/env bash
#
# restore-flash.sh — Restore a previously backed-up flash image to a Badgware badge.
#
# The device must be in BOOTSEL mode before running this script.
# Hold BOOT, press RESET, release both — the badge appears as a USB drive.
#
# Usage:
#   ./scripts/restore-flash.sh backups/tufty-backup-20250610-143022.uf2
#   ./scripts/restore-flash.sh -b badger backups/badger-backup-20250610-143022.uf2
#   ./scripts/restore-flash.sh backups/factory.bin
#   ./scripts/restore-flash.sh --list
#

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BACKUP_DIR="backups"
FLASH_START="0x10000000"

# Supported boards. All share the same RP2350 + 16 MB flash layout.
SUPPORTED_BOARDS="tufty blinky badger"

BOARD="tufty"                    # default board
NO_REBOOT=false
BACKUP_FILE=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] BACKUP_FILE

Restore a flash backup to a Badgware badge.

Arguments:
  BACKUP_FILE     Path to .uf2 or .bin backup file

Options:
  -b BOARD        Target board: tufty | blinky | badger  (default: tufty)
  --list          List available backups in the $BACKUP_DIR/ directory
  --no-reboot     Do not reboot after flashing
  -h              Show this help message

The device must be in BOOTSEL mode (hold BOOT, press RESET, release both).

Supported boards (all use RP2350 + 16 MB flash):
  tufty   — Tufty 2350  (2.8" colour TFT display)
  blinky  — Blinky 2350 (LED matrix display)
  badger  — Badger 2350 (2.7" e-paper display)

Supported formats:
  .uf2   Restored with: picotool load -v <file>
  .bin   Restored with: picotool load -v -t bin <file> -o $FLASH_START

Examples:
  $(basename "$0") backups/tufty-backup-20250610-143022.uf2
  $(basename "$0") -b badger backups/badger-backup-20250610-143022.uf2
  $(basename "$0") -b blinky backups/factory.bin
  $(basename "$0") --list
  $(basename "$0") --no-reboot backups/tufty-backup-20250610-143022.uf2
EOF
    exit 0
}

info()  { echo -e "\033[0;32m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

# Abort if picotool is not on PATH.
require_picotool() {
    if ! command -v picotool &>/dev/null; then
        error "picotool not found. Install from https://github.com/raspberrypi/picotool"
    fi
}

# Abort if BOARD is not in SUPPORTED_BOARDS.
validate_board() {
    local board="$1"
    for b in $SUPPORTED_BOARDS; do
        [[ "$b" == "$board" ]] && return 0
    done
    error "Unknown board: '$board'. Supported boards: $SUPPORTED_BOARDS"
}

# Abort if no backup file was supplied, or the path does not exist.
validate_backup_file() {
    if [ -z "$BACKUP_FILE" ]; then
        error "No backup file specified. Usage: $(basename "$0") [-b BOARD] BACKUP_FILE
  Run '$(basename "$0") --list' to see available backups."
    fi
    if [ ! -f "$BACKUP_FILE" ]; then
        error "Backup file not found: $BACKUP_FILE"
    fi
}

# Detect the file format from its extension and set FORMAT / FILESIZE.
resolve_file_format() {
    FILESIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
    local ext="${BACKUP_FILE##*.}"
    case "${ext,,}" in
        uf2) FORMAT="uf2" ;;
        bin) FORMAT="bin" ;;
        *)
            warn "Unrecognized extension '.$ext'. Treating as raw binary."
            FORMAT="bin"
            ;;
    esac
}

# Confirm a device is present in BOOTSEL mode.
check_device() {
    info "Board: $BOARD"
    info "Checking for device in BOOTSEL mode..."
    if ! picotool info &>/dev/null; then
        error "No device found. Put the $BOARD in BOOTSEL mode: hold BOOT, press RESET, release both."
    fi
    info "Device detected."
    echo ""
}

# Flash the backup file onto the device using the appropriate picotool command.
load_flash() {
    info "Restoring backup: $BACKUP_FILE ($FILESIZE bytes, $FORMAT format)"
    echo ""
    if [ "$FORMAT" = "uf2" ]; then
        picotool load -v "$BACKUP_FILE"
    else
        picotool load -v -t bin "$BACKUP_FILE" -o "$FLASH_START"
    fi
    echo ""
}

# Reboot the device unless --no-reboot was passed.
reboot_device() {
    if ! $NO_REBOOT; then
        info "Rebooting device..."
        picotool reboot
        echo ""
    fi
}

# List available .uf2 and .bin files in BACKUP_DIR and exit.
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
    info "Restore with: ./scripts/restore-flash.sh [-b BOARD] $BACKUP_DIR/<filename>"
    exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)       list_backups ;;
        --no-reboot)  NO_REBOOT=true; shift ;;
        -b)           shift; BOARD="${1,,}"; shift ;;  # normalise to lowercase
        -h|--help)    usage ;;
        -*)           error "Unknown option: $1 (see -h for usage)" ;;
        *)            BACKUP_FILE="$1"; shift ;;
    esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

require_picotool
validate_board "$BOARD"
validate_backup_file
resolve_file_format
check_device
load_flash
reboot_device
info "=== Restore complete ==="
info "The $BOARD should now be running the backed-up firmware."
