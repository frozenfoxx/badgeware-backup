#!/usr/bin/env bash
#
# backup-flash.sh — Dump the entire flash contents of a Tufty 2350 to disk.
#
# The device must be in BOOTSEL mode before running this script.
# Hold BOOT, press RESET, release both — the Tufty appears as a USB drive.
#
# Usage:
#   ./scripts/backup-flash.sh                    # save to backups/tufty-backup-<timestamp>.uf2
#   ./scripts/backup-flash.sh my-backup.uf2      # save to backups/my-backup.uf2
#   ./scripts/backup-flash.sh -r my-backup.bin   # save as raw binary instead of UF2
#

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BACKUP_DIR="backups"
FLASH_START="0x10000000"
FLASH_END="0x11000000"           # 16MB (Tufty 2350)
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DEFAULT_NAME="tufty-backup-${TIMESTAMP}.uf2"
RAW_MODE=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [FILENAME]

Dump the Tufty 2350 flash contents to a backup file.

Options:
  -r          Save as raw binary instead of UF2
  -d DIR      Backup directory (default: $BACKUP_DIR)
  -h          Show this help message

Arguments:
  FILENAME    Output filename (default: $DEFAULT_NAME)

The device must be in BOOTSEL mode (hold BOOT, press RESET, release both).

Examples:
  $(basename "$0")                          # UF2 backup with timestamp
  $(basename "$0") factory.uf2              # UF2 backup with custom name
  $(basename "$0") -r factory.bin           # raw binary backup
  $(basename "$0") -d /tmp factory.uf2      # save to /tmp
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

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while getopts "rd:h" opt; do
    case "$opt" in
        r) RAW_MODE=true ;;
        d) BACKUP_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

FILENAME="${1:-$DEFAULT_NAME}"

# If raw mode requested but filename still has .uf2 extension, fix it
if $RAW_MODE && [[ "$FILENAME" == "$DEFAULT_NAME" ]]; then
    FILENAME="tufty-backup-${TIMESTAMP}.bin"
fi

OUTPUT_PATH="${BACKUP_DIR}/${FILENAME}"

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

require_picotool
mkdir -p "$BACKUP_DIR"

info "Checking for device in BOOTSEL mode..."
if ! picotool info &>/dev/null; then
    error "No device found. Put the Tufty in BOOTSEL mode: hold BOOT, press RESET, release both."
fi

info "Device detected. Reading flash info..."
picotool info 2>&1 | head -5

echo ""

if $RAW_MODE; then
    info "Dumping flash (raw binary): $FLASH_START - $FLASH_END"
    info "Output: $OUTPUT_PATH"
    picotool save -r "$FLASH_START" "$FLASH_END" "$OUTPUT_PATH"
else
    info "Dumping flash (UF2 format)"
    info "Output: $OUTPUT_PATH"
    picotool save -a "$OUTPUT_PATH"
fi

FILESIZE=$(stat -f%z "$OUTPUT_PATH" 2>/dev/null || stat -c%s "$OUTPUT_PATH" 2>/dev/null)
info "Backup complete: $OUTPUT_PATH ($FILESIZE bytes)"
echo ""
info "To restore later, run:"
info "  ./scripts/restore-flash.sh $OUTPUT_PATH"
