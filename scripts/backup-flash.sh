#!/usr/bin/env bash
#
# backup-flash.sh — Dump the entire flash contents of a Badgware badge to disk.
#
# The device must be in BOOTSEL mode before running this script.
# Hold BOOT, press RESET, release both — the badge appears as a USB drive.
#
# Usage:
#   ./scripts/backup-flash.sh                         # Tufty 2350, UF2, timestamped filename
#   ./scripts/backup-flash.sh -b badger               # Badger 2350
#   ./scripts/backup-flash.sh -b blinky               # Blinky 2350
#   ./scripts/backup-flash.sh my-backup.uf2           # custom filename
#   ./scripts/backup-flash.sh -r my-backup.bin        # raw binary instead of UF2
#

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BACKUP_DIR="backups"
FLASH_START="0x10000000"
FLASH_END="0x11000000"           # 16 MB — applies to all three Badgware boards
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Supported boards and their display names.
# All share the same RP2350 + 16 MB flash layout.
SUPPORTED_BOARDS="tufty blinky badger"

BOARD="tufty"                    # default board
RAW_MODE=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [FILENAME]

Dump a Badgware badge flash to a backup file.

Options:
  -b BOARD    Target board: tufty | blinky | badger  (default: tufty)
  -r          Save as raw binary instead of UF2
  -d DIR      Backup directory                        (default: $BACKUP_DIR)
  -h          Show this help message

Arguments:
  FILENAME    Output filename (default: <board>-backup-<timestamp>.uf2)

The device must be in BOOTSEL mode (hold BOOT, press RESET, release both).

Supported boards (all use RP2350 + 16 MB flash):
  tufty   — Tufty 2350  (2.8" colour TFT display)
  blinky  — Blinky 2350 (LED matrix display)
  badger  — Badger 2350 (2.7" e-paper display)

Examples:
  $(basename "$0")                            # UF2 backup of Tufty with timestamp
  $(basename "$0") -b badger                  # UF2 backup of Badger with timestamp
  $(basename "$0") -b blinky factory.uf2      # named UF2 backup of Blinky
  $(basename "$0") -b tufty -r factory.bin    # raw binary backup of Tufty
  $(basename "$0") -d /tmp -b badger          # save to /tmp
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

# Resolve the output path, applying raw-mode extension fixup when needed.
resolve_output_path() {
    local default_name="${BOARD}-backup-${TIMESTAMP}.uf2"

    FILENAME="${1:-$default_name}"

    # If raw mode was requested but the caller left the default .uf2 name, fix it.
    if $RAW_MODE && [[ "$FILENAME" == "$default_name" ]]; then
        FILENAME="${BOARD}-backup-${TIMESTAMP}.bin"
    fi

    OUTPUT_PATH="${BACKUP_DIR}/${FILENAME}"
}

# Ensure the backup directory exists, then confirm a device is present.
prepare_backup() {
    mkdir -p "$BACKUP_DIR"
    info "Board: $BOARD"
    info "Checking for device in BOOTSEL mode..."
    if ! picotool info &>/dev/null; then
        error "No device found. Put the $BOARD in BOOTSEL mode: hold BOOT, press RESET, release both."
    fi
    info "Device detected. Reading flash info..."
    picotool info 2>&1 | head -5
    echo ""
}

# Perform the flash dump in the requested format.
dump_flash() {
    if $RAW_MODE; then
        info "Dumping flash (raw binary): $FLASH_START - $FLASH_END"
        info "Output: $OUTPUT_PATH"
        picotool save -r "$FLASH_START" "$FLASH_END" "$OUTPUT_PATH"
    else
        info "Dumping flash (UF2 format)"
        info "Output: $OUTPUT_PATH"
        picotool save -a "$OUTPUT_PATH"
    fi
}

# Print a completion summary and a ready-to-use restore command.
report_success() {
    local filesize
    filesize=$(stat -f%z "$OUTPUT_PATH" 2>/dev/null || stat -c%s "$OUTPUT_PATH" 2>/dev/null)
    info "Backup complete: $OUTPUT_PATH ($filesize bytes)"
    echo ""
    info "To restore later, run:"
    info "  ./scripts/restore-flash.sh -b $BOARD $OUTPUT_PATH"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while getopts "b:rd:h" opt; do
    case "$opt" in
        b) BOARD="${OPTARG,,}" ;;   # normalise to lowercase
        r) RAW_MODE=true ;;
        d) BACKUP_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

require_picotool
validate_board "$BOARD"
resolve_output_path "$1"
prepare_backup
dump_flash
report_success
